import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:http/http.dart' as http;
import '../models/aws_credentials.dart';
import '../models/s3_object.dart';

/// Custom HTTP client that fixes two bugs in the aws_s3_api / shared_aws_api SDK:
///
/// 1. Missing Content-MD5 header for bulk DeleteObjects requests.
/// 2. Double-encoding of percent-encoded path segments in the AWS Signature V4
///    canonical request (e.g., %20 → %2520), which causes SignatureDoesNotMatch
///    for object keys containing spaces or special characters.
///
/// This client holds the AWS credentials so it can strip the SDK's broken
/// signature and re-sign the request correctly.
class FixedSigningHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  String accessKey;
  String secretKey;
  String? sessionToken;
  String region;
  
  FixedSigningHttpClient({
    required this.accessKey,
    required this.secretKey,
    this.sessionToken,
    required this.region,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      bool needsResign = false;
      
      // Fix 1: Add Content-MD5 header for bulk delete requests
      if (request.method == 'POST' && request.url.queryParameters.containsKey('delete')) {
        final md5Hash = md5.convert(request.bodyBytes).bytes;
        final base64Md5 = base64Encode(md5Hash);
        request.headers['Content-MD5'] = base64Md5;
        needsResign = true; // Must re-sign since we added a new header
      }
      
      // Fix 2: Re-sign if path has characters that the SDK mis-handles in signing.
      // The SDK double-encodes percent-encoded chars (%20 → %2520) AND
      // also mis-signs paths containing characters like parentheses () that
      // AWS Sig V4 requires to be percent-encoded in the canonical URI but
      // which Dart's Uri class leaves unencoded in the actual URL.
      if (_pathNeedsResign(request.url.path)) {
        needsResign = true;
      }
      
      if (needsResign) {
        _fixSignature(request);
      }
    }
    return _inner.send(request);
  }

  /// Characters that AWS Sig V4 requires percent-encoded in the canonical URI
  /// but which Dart's Uri class treats as valid (unreserved) and leaves as-is.
  static final _needsResignPattern = RegExp(r'[%\(\)\[\]!\*\+,@]');

  bool _pathNeedsResign(String path) {
    return _needsResignPattern.hasMatch(path);
  }

  /// URI-encode a single path segment the way AWS Signature V4 requires:
  /// encode everything except unreserved chars (A-Z a-z 0-9 - _ . ~).
  String _awsUriEncode(String segment) {
    // Uri.encodeComponent encodes everything except unreserved + a few extra.
    // But it also encodes '~' as %7E, which AWS considers unreserved.
    // And it does NOT encode some chars AWS wants encoded (like '!' '*' '(' ')').
    // So we use Uri.encodeComponent and then fix up the differences.
    return segment.splitMapJoin(
      RegExp(r'[A-Za-z0-9\-_.~]'),
      onMatch: (m) => m.group(0)!,
      onNonMatch: (s) {
        final buffer = StringBuffer();
        for (final byte in utf8.encode(s)) {
          buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
        }
        return buffer.toString();
      },
    );
  }
  
  void _fixSignature(http.Request request) {
    // Re-compute the AWS Signature V4 with the correct canonical URI.
    final date = request.headers['X-Amz-Date'];
    if (date == null) return;
    
    final payloadHash = request.headers['x-amz-content-sha256'] ?? 
        sha256.convert(request.bodyBytes).toString();
    
    // Build canonical headers (sorted, lowercase keys)
    // We need to remove the old Authorization header first
    request.headers.remove('Authorization');
    
    final sortedHeaderKeys = request.headers.keys
        .map((k) => k.toLowerCase())
        .toList()
      ..sort();
    
    final canonicalHeaders = sortedHeaderKeys
        .map((key) {
          final value = request.headers.entries
              .firstWhere((e) => e.key.toLowerCase() == key)
              .value;
          return '$key:${value.trim()}';
        })
        .toList();
    
    final signedHeaders = sortedHeaderKeys.join(';');
    
    // Build canonical query string
    final queryParams = request.url.queryParametersAll;
    final sortedQueryKeys = queryParams.keys.toList()..sort();
    final canonicalQueryParts = <String>[];
    for (final key in sortedQueryKeys) {
      for (final value in queryParams[key]!) {
        canonicalQueryParts.add(
          '${Uri.encodeComponent(key)}=${Uri.encodeComponent(value)}');
      }
    }
    final canonicalQueryString = canonicalQueryParts.join('&');
    
    // Build the canonical URI by properly encoding each path segment
    // per AWS Sig V4 spec. Dart's Uri.path may leave characters like
    // parentheses unencoded, and may also double-encode %XX sequences.
    // We decode the raw path first, then re-encode each segment correctly.
    final rawPath = Uri.decodeFull(request.url.path);
    final segments = rawPath.split('/');
    final canonicalUri = segments.map((seg) => seg.isEmpty ? '' : _awsUriEncode(seg)).join('/');
    
    final canonical = [
      request.method.toUpperCase(),
      canonicalUri,
      canonicalQueryString,
      ...canonicalHeaders,
      '',
      signedHeaders,
      payloadHash,
    ].join('\n');
    
    final canonicalHash = sha256.convert(utf8.encode(canonical)).toString();
    
    final credentialList = [
      date.substring(0, 8),
      region,
      's3',
      'aws4_request',
    ];
    
    const aws4HmacSha256 = 'AWS4-HMAC-SHA256';
    final toSign = [
      aws4HmacSha256,
      date,
      credentialList.join('/'),
      canonicalHash,
    ].join('\n');
    
    final signingKey = credentialList.fold(
      utf8.encode('AWS4$secretKey'),
      (List<int> key, String s) {
        final hmac = Hmac(sha256, key);
        return hmac.convert(utf8.encode(s)).bytes;
      },
    );
    
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(toSign))
        .toString();
    
    final auth = '$aws4HmacSha256 '
        'Credential=$accessKey/${credentialList.join('/')}, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';
    
    request.headers['Authorization'] = auth;
  }
}

class AwsService {
  S3? _s3;
  AwsCredentials? _credentials;

  bool get isInitialized => _s3 != null && _credentials != null;

  Future<void> initialize(AwsCredentials credentials) async {
    _credentials = credentials;
    
    // Use our custom HTTP client that fixes signing bugs in the SDK
    final httpClient = FixedSigningHttpClient(
      accessKey: credentials.accessKeyId,
      secretKey: credentials.secretAccessKey,
      sessionToken: credentials.sessionToken,
      region: credentials.region,
    );

    _s3 = S3(
      region: credentials.region,
      credentials: AwsClientCredentials(
        accessKey: credentials.accessKeyId,
        secretKey: credentials.secretAccessKey,
        sessionToken: credentials.sessionToken,
      ),
      client: httpClient,
    );
  }

  Future<List<S3Bucket>> listBuckets() async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    
    // Retry logic for network issues
    int maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        final response = await _s3!.listBuckets();
        return response.buckets?.map((bucket) => S3Bucket(
          name: bucket.name!,
          creationDate: bucket.creationDate,
        )).toList() ?? [];
      } catch (e) {
        retryCount++;
        
        if (retryCount < maxRetries && _isRetryableError(e)) {
          print('Retrying bucket list ($retryCount/$maxRetries): $e');
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          continue;
        }
        
        throw Exception('Failed to list buckets after $retryCount attempts: $e');
      }
    }
    
    throw Exception('Failed to list buckets: Maximum retries exceeded');
  }

  Future<String?> getBucketRegion(String bucketName) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    try {
      final response = await _s3!.getBucketLocation(bucket: bucketName);
      final constraint = response.locationConstraint;
      if (constraint == null) return 'us-east-1';
      
      // The enum has a built-in toValue() that returns the correct region string
      return constraint.toValue();
    } catch (e) {
      print('Failed to get bucket location: $e');
      return null;
    }
  }

  Future<List<S3Object>> listObjects(String bucketName, {String? prefix}) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    
    // Retry logic for network issues
    int maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        final response = await _s3!.listObjectsV2(
          bucket: bucketName,
          prefix: prefix,
          delimiter: '/',
          maxKeys: 1000, // Limit objects per request
        );

        final objects = <S3Object>[];

        // Add folders (common prefixes)
        if (response.commonPrefixes != null) {
          for (final commonPrefix in response.commonPrefixes!) {
            objects.add(S3Object(
              key: commonPrefix.prefix!,
              isFolder: true,
            ));
          }
        }

        // Add files
        if (response.contents != null) {
          for (final object in response.contents!) {
            if (object.key != prefix) { // Don't include the prefix itself
              objects.add(S3Object(
                key: object.key!,
                size: object.size,
                lastModified: object.lastModified,
                etag: object.eTag,
                isFolder: object.key!.endsWith('/'),
              ));
            }
          }
        }

        return objects;
      } catch (e) {
        retryCount++;
        
        // Check if this is a network-related error that we can retry
        if (retryCount < maxRetries && _isRetryableError(e)) {
          print('Retrying S3 request ($retryCount/$maxRetries): $e');
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          continue;
        }
        
        throw Exception('Failed to list objects after $retryCount attempts: $e');
      }
    }
    
    throw Exception('Failed to list objects: Maximum retries exceeded');
  }
  
  bool _isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('connection closed') ||
           errorString.contains('socket exception') ||
           errorString.contains('timeout') ||
           errorString.contains('connection refused') ||
           errorString.contains('network is unreachable');
  }

  Future<List<S3Object>> listAllObjectsRecursive(String bucketName, {String? prefix}) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    
    int maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        final objects = <S3Object>[];
        String? continuationToken;
        
        do {
          final response = await _s3!.listObjectsV2(
            bucket: bucketName,
            prefix: prefix,
            continuationToken: continuationToken,
          );

          if (response.contents != null) {
            for (final object in response.contents!) {
              objects.add(S3Object(
                key: object.key!,
                size: object.size,
                lastModified: object.lastModified,
                etag: object.eTag,
                isFolder: object.key!.endsWith('/'),
              ));
            }
          }
          
          continuationToken = response.nextContinuationToken;
        } while (continuationToken != null && continuationToken.isNotEmpty);
        
        return objects;
      } catch (e) {
        retryCount++;
        if (retryCount < maxRetries && _isRetryableError(e)) {
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          continue;
        }
        throw Exception('Failed to recursively list objects after $retryCount attempts: $e');
      }
    }
    
    throw Exception('Failed to recursively list objects: Maximum retries exceeded');
  }

  Future<Uint8List> downloadObject(String bucketName, String key) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    
    try {
      final response = await _s3!.getObject(bucket: bucketName, key: key);
      final body = response.body;
      
      if (body == null) {
        throw Exception('Response body is null');
      }
      
      return body;
    } catch (e) {
      throw Exception('Failed to download object: $e');
    }
  }

  Future<void> uploadObject(
    String bucketName, 
    String key, 
    Uint8List data, {
    String? contentType,
    String? contentEncoding,
    String? cacheControl,
    String? contentDisposition,
    String? contentLanguage,
    Map<String, String>? metadata,
  }) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    
    try {
      await _s3!.putObject(
        bucket: bucketName,
        key: key,
        body: data,
        contentType: contentType,
        contentEncoding: contentEncoding,
        cacheControl: cacheControl,
        contentDisposition: contentDisposition,
        contentLanguage: contentLanguage,
        metadata: metadata,
      );
    } catch (e) {
      throw Exception('Failed to upload object: $e');
    }
  }

  Future<dynamic> headObject(String bucketName, String key) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    try {
      return await _s3!.headObject(bucket: bucketName, key: key);
    } catch (e) {
      throw Exception('Failed to get object metadata: $e');
    }
  }

  Future<dynamic> getObjectTagging(String bucketName, String key) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    try {
      return await _s3!.getObjectTagging(bucket: bucketName, key: key);
    } catch (e) {
      throw Exception('Failed to get object tagging: $e');
    }
  }

  Future<dynamic> listObjectVersions(String bucketName, String key) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    try {
      return await _s3!.listObjectVersions(bucket: bucketName, prefix: key);
    } catch (e) {
      throw Exception('Failed to list object versions: $e');
    }
  }

  Future<void> deleteObject(String bucketName, String key) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    
    try {
      await _s3!.deleteObject(bucket: bucketName, key: key);
    } catch (e) {
      throw Exception('Failed to delete object: $e');
    }
  }

  Future<void> copyObject(String sourceBucket, String sourceKey, String destBucket, String destKey, {String? destRegion}) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    
    try {
      if (destRegion != null && destRegion != _credentials?.region) {
        // Create temporary S3 client for destination region
        final tempHttpClient = FixedSigningHttpClient(
          accessKey: _credentials!.accessKeyId,
          secretKey: _credentials!.secretAccessKey,
          sessionToken: _credentials!.sessionToken,
          region: destRegion,
        );
        final tempS3 = S3(
          region: destRegion,
          credentials: AwsClientCredentials(
            accessKey: _credentials!.accessKeyId,
            secretKey: _credentials!.secretAccessKey,
            sessionToken: _credentials!.sessionToken,
          ),
          client: tempHttpClient,
        );
        try {
          await tempS3.copyObject(
            bucket: destBucket,
            copySource: Uri.encodeComponent('$sourceBucket/$sourceKey'),
            key: destKey,
          );
        } finally {
          tempS3.close();
        }
      } else {
        await _s3!.copyObject(
          bucket: destBucket,
          copySource: Uri.encodeComponent('$sourceBucket/$sourceKey'),
          key: destKey,
        );
      }
    } catch (e) {
      throw Exception('Failed to copy object: $e');
    }
  }

  Future<void> updateObjectMetadata(String bucketName, String key, Map<String, String> metadata, {String? contentType, String? contentEncoding}) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    
    try {
      await _s3!.copyObject(
        bucket: bucketName,
        copySource: Uri.encodeComponent('$bucketName/$key'),
        key: key,
        metadataDirective: MetadataDirective.replace,
        metadata: metadata,
        contentType: contentType,
        contentEncoding: contentEncoding,
      );
    } catch (e) {
      throw Exception('Failed to update metadata: $e');
    }
  }

  Future<void> deleteObjects(String bucketName, List<String> keys) async {
    if (_s3 == null) throw Exception('AWS service not initialized');
    
    try {
      // Use the bulk DeleteObjects API — our FixedSigningHttpClient
      // automatically adds the required Content-MD5 header.
      for (int i = 0; i < keys.length; i += 1000) {
        final chunk = keys.skip(i).take(1000).toList();
        await _s3!.deleteObjects(
          bucket: bucketName,
          delete: Delete(
            objects: chunk.map((k) => ObjectIdentifier(key: k)).toList(),
            quiet: true,
          ),
        );
      }
    } catch (e) {
      throw Exception('Failed to delete objects: $e');
    }
  }

  void dispose() {
    _s3?.close();
    _s3 = null;
    _credentials = null;
  }
}