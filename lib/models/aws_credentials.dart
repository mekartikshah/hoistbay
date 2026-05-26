class AwsCredentials {
  final String accessKeyId;
  final String secretAccessKey;
  final String region;
  final String? sessionToken;

  AwsCredentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.region,
    this.sessionToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'accessKeyId': accessKeyId,
      'secretAccessKey': secretAccessKey,
      'region': region,
      'sessionToken': sessionToken,
    };
  }

  factory AwsCredentials.fromMap(Map<String, dynamic> map) {
    return AwsCredentials(
      accessKeyId: map['accessKeyId'] ?? '',
      secretAccessKey: map['secretAccessKey'] ?? '',
      region: map['region'] ?? 'us-east-1',
      sessionToken: map['sessionToken'],
    );
  }
}