import 'aws_credentials.dart';

class AwsProfile {
  final String id;
  final String name;
  final AwsCredentials credentials;
  final DateTime createdAt;
  final DateTime lastUsed;

  AwsProfile({
    required this.id,
    required this.name,
    required this.credentials,
    required this.createdAt,
    required this.lastUsed,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'credentials': credentials.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed.toIso8601String(),
    };
  }

  factory AwsProfile.fromMap(Map<String, dynamic> map) {
    return AwsProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      credentials: AwsCredentials.fromMap(map['credentials'] ?? {}),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastUsed: DateTime.parse(map['lastUsed'] ?? DateTime.now().toIso8601String()),
    );
  }

  AwsProfile copyWith({
    String? id,
    String? name,
    AwsCredentials? credentials,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return AwsProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      credentials: credentials ?? this.credentials,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
}