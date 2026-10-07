import 'dart:convert';
import 'package:aws_cloudfront_api/cloudfront-2020-05-31.dart';
import 'package:http/http.dart' as http;
import '../models/aws_credentials.dart';

/// A custom HTTP client that fixes a case-sensitivity bug in the CloudFront SDK.
/// The SDK expects lowercase 'http2' but some AWS responses might contain 'HTTP2',
/// causing an 'is not known in enum HttpVersion' error.
class CloudFrontFixClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    
    // Intercept and fix the casing issue in XML responses
    if (response.headers['content-type']?.contains('xml') == true) {
      final bytes = await response.stream.toBytes();
      final body = utf8.decode(bytes);
      
      // Normalize HTTP version strings to lowercase to match SDK enums
      final fixedBody = body.replaceAll('<HttpVersion>HTTP2</HttpVersion>', '<HttpVersion>http2</HttpVersion>')
                           .replaceAll('<HttpVersion>HTTP1.1</HttpVersion>', '<HttpVersion>http1.1</HttpVersion>')
                           .replaceAll('<HttpVersion>HTTP2and3</HttpVersion>', '<HttpVersion>http2and3</HttpVersion>');
      
      return http.StreamedResponse(
        Stream.value(utf8.encode(fixedBody)),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }
    return response;
  }
}

class CloudFrontService {
  CloudFront? _cloudFront;

  bool get isInitialized => _cloudFront != null;

  void initialize(AwsCredentials credentials) {
    _cloudFront = CloudFront(
      region: 'us-east-1', // CloudFront API endpoint is global (us-east-1)
      credentials: AwsClientCredentials(
        accessKey: credentials.accessKeyId,
        secretKey: credentials.secretAccessKey,
        sessionToken: credentials.sessionToken,
      ),
      client: CloudFrontFixClient(), // Use our fixing client
    );
  }

  Future<List<DistributionSummary>> listDistributions() async {
    if (_cloudFront == null) throw Exception('CloudFront service not initialized');
    
    int maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        final response = await _cloudFront!.listDistributions2020_05_31();
        return response.distributionList?.items ?? [];
      } catch (e) {
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          continue;
        }
        throw Exception('Failed to list CloudFront distributions: $e');
      }
    }
    return [];
  }

  /// Clears the given [paths] from the distribution's edge caches.
  Future<Invalidation> createInvalidation(String distributionId, List<String> paths) async {
    if (_cloudFront == null) throw Exception('CloudFront service not initialized');

    try {
      final result = await _cloudFront!.createInvalidation2020_05_31(
        distributionId: distributionId,
        invalidationBatch: InvalidationBatch(
          // Must be unique per request; CloudFront uses it to dedupe retries.
          callerReference: 's3scout-${DateTime.now().microsecondsSinceEpoch}',
          paths: Paths(quantity: paths.length, items: paths),
        ),
      );
      final invalidation = result.invalidation;
      if (invalidation == null) throw Exception('Empty response from CloudFront');
      return invalidation;
    } catch (e) {
      throw Exception('Failed to create invalidation: $e');
    }
  }

  /// Current status of one invalidation: 'InProgress' or 'Completed'.
  Future<String> getInvalidationStatus(String distributionId, String invalidationId) async {
    if (_cloudFront == null) throw Exception('CloudFront service not initialized');

    try {
      final result = await _cloudFront!.getInvalidation2020_05_31(
        distributionId: distributionId,
        id: invalidationId,
      );
      final invalidation = result.invalidation;
      if (invalidation == null) throw Exception('Empty response from CloudFront');
      return invalidation.status;
    } catch (e) {
      throw Exception('Failed to get invalidation status: $e');
    }
  }

  /// Most recent invalidations for the distribution, newest first.
  Future<List<InvalidationSummary>> listInvalidations(String distributionId, {int maxItems = 10}) async {
    if (_cloudFront == null) throw Exception('CloudFront service not initialized');

    try {
      final result = await _cloudFront!.listInvalidations2020_05_31(
        distributionId: distributionId,
        maxItems: '$maxItems',
      );
      final items = [...?result.invalidationList?.items];
      items.sort((a, b) => b.createTime.compareTo(a.createTime));
      return items;
    } catch (e) {
      throw Exception('Failed to list invalidations: $e');
    }
  }

  void dispose() {
    _cloudFront = null;
  }
}
