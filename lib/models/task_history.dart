enum TaskStatus {
  pending,
  inProgress,
  completed,
  failed,
}

class TaskHistoryItem {
  final String id;
  final String operationType; // e.g., 'Upload', 'Delete', 'Rename', 'Move'
  final String objectKey;
  final TaskStatus status;
  final DateTime timestamp;
  final String? details; // For error messages or additional info

  TaskHistoryItem({
    required this.id,
    required this.operationType,
    required this.objectKey,
    required this.status,
    required this.timestamp,
    this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operationType': operationType,
      'objectKey': objectKey,
      'status': status.index,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
    };
  }

  factory TaskHistoryItem.fromMap(Map<String, dynamic> map) {
    return TaskHistoryItem(
      id: map['id'] ?? '',
      operationType: map['operationType'] ?? '',
      objectKey: map['objectKey'] ?? '',
      status: TaskStatus.values[map['status'] ?? 0],
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      details: map['details'],
    );
  }

  TaskHistoryItem copyWith({
    String? id,
    String? operationType,
    String? objectKey,
    TaskStatus? status,
    DateTime? timestamp,
    String? details,
  }) {
    return TaskHistoryItem(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      objectKey: objectKey ?? this.objectKey,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      details: details ?? this.details,
    );
  }
}
