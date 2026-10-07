// New values go at the end: statuses are persisted by index.
enum TaskStatus {
  pending,
  inProgress,
  completed,
  failed,
  cancelled,
}

class TaskHistoryItem {
  final String id;
  final String operationType; // e.g., 'Upload', 'Delete', 'Rename', 'Move', 'Clear Cache'
  final String objectKey; // What the task acted on (keys, bucket/prefix, distribution)
  final TaskStatus status;
  final DateTime timestamp; // When the task started
  final String? details; // For error messages or additional info
  final DateTime? finishedAt;
  final int? progressCurrent;
  final int? progressTotal;
  final Map<String, String> meta; // e.g. distributionId / invalidationId for Clear Cache

  TaskHistoryItem({
    required this.id,
    required this.operationType,
    required this.objectKey,
    required this.status,
    required this.timestamp,
    this.details,
    this.finishedAt,
    this.progressCurrent,
    this.progressTotal,
    this.meta = const {},
  });

  bool get isRunning => status == TaskStatus.pending || status == TaskStatus.inProgress;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operationType': operationType,
      'objectKey': objectKey,
      'status': status.index,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
      'finishedAt': finishedAt?.toIso8601String(),
      'progressCurrent': progressCurrent,
      'progressTotal': progressTotal,
      'meta': meta,
    };
  }

  factory TaskHistoryItem.fromMap(Map<String, dynamic> map) {
    final statusIndex = map['status'] as int? ?? 0;
    return TaskHistoryItem(
      id: map['id'] ?? '',
      operationType: map['operationType'] ?? '',
      objectKey: map['objectKey'] ?? '',
      status: statusIndex < TaskStatus.values.length ? TaskStatus.values[statusIndex] : TaskStatus.failed,
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      details: map['details'],
      finishedAt: map['finishedAt'] != null ? DateTime.tryParse(map['finishedAt']) : null,
      progressCurrent: map['progressCurrent'] as int?,
      progressTotal: map['progressTotal'] as int?,
      meta: (map['meta'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
    );
  }

  TaskHistoryItem copyWith({
    String? id,
    String? operationType,
    String? objectKey,
    TaskStatus? status,
    DateTime? timestamp,
    String? details,
    DateTime? finishedAt,
    int? progressCurrent,
    int? progressTotal,
    Map<String, String>? meta,
  }) {
    return TaskHistoryItem(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      objectKey: objectKey ?? this.objectKey,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      details: details ?? this.details,
      finishedAt: finishedAt ?? this.finishedAt,
      progressCurrent: progressCurrent ?? this.progressCurrent,
      progressTotal: progressTotal ?? this.progressTotal,
      meta: meta ?? this.meta,
    );
  }
}
