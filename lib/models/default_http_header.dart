class DefaultHttpHeader {
  final String id;
  final String bucket;
  final String fileMask;
  final String headerName;
  final String headerValue;

  DefaultHttpHeader({
    required this.id,
    required this.bucket,
    required this.fileMask,
    required this.headerName,
    required this.headerValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bucket': bucket,
      'fileMask': fileMask,
      'headerName': headerName,
      'headerValue': headerValue,
    };
  }

  factory DefaultHttpHeader.fromMap(Map<String, dynamic> map) {
    return DefaultHttpHeader(
      id: map['id'] ?? '',
      bucket: map['bucket'] ?? '',
      fileMask: map['fileMask'] ?? '',
      headerName: map['headerName'] ?? '',
      headerValue: map['headerValue'] ?? '',
    );
  }

  DefaultHttpHeader copyWith({
    String? id,
    String? bucket,
    String? fileMask,
    String? headerName,
    String? headerValue,
  }) {
    return DefaultHttpHeader(
      id: id ?? this.id,
      bucket: bucket ?? this.bucket,
      fileMask: fileMask ?? this.fileMask,
      headerName: headerName ?? this.headerName,
      headerValue: headerValue ?? this.headerValue,
    );
  }
}
