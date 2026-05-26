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

  void dispose() {
    _cloudFront = null;
  }
}
