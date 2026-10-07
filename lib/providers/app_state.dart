import 'dart:async';
import 'dart:io' as import_io;
import 'package:flutter/foundation.dart';
import '../models/aws_credentials.dart';
import '../models/aws_profile.dart';
import '../models/s3_object.dart';
import '../services/aws_service.dart';
import '../services/profile_service.dart';
import '../models/default_http_header.dart';
import '../services/default_headers_service.dart';
import '../models/task_history.dart';
import '../services/task_service.dart';
import '../services/cloudfront_service.dart';
import '../utils/download_paths.dart';

enum AppSection { s3Browser, cloudFront, activity, settings }

/// A one-off message for the UI (shown as a snackbar).
class AppNotice {
  final String message;
  final bool isError;
  const AppNotice(this.message, {this.isError = false});
}

class AppState extends ChangeNotifier {
  AppState({CloudFrontService? cloudFrontService})
      : _cloudFrontService = cloudFrontService ?? CloudFrontService();

  final AwsService _awsService = AwsService();
  final CloudFrontService _cloudFrontService;

  /// How often a running Clear Cache task asks CloudFront for its status.
  Duration invalidationPollInterval = const Duration(seconds: 15);
  /// Stop polling after this long; CloudFront normally finishes in minutes.
  Duration invalidationPollTimeout = const Duration(hours: 2);
  final Set<String> _watchedInvalidations = {};
  bool _disposed = false;

  final StreamController<AppNotice> _notices = StreamController<AppNotice>.broadcast();
  /// One-off messages for the UI to show (e.g. "Cache cleared"), wherever the user is.
  Stream<AppNotice> get notices => _notices.stream;
  int _taskSeq = 0;
  
  AwsCredentials? _credentials;
  AwsProfile? _currentProfile;
  List<S3Bucket> _buckets = [];
  S3Bucket? _selectedBucket;
  List<S3Object> _objects = [];
  String _currentPrefix = '';
  List<String> _breadcrumbs = [];
  Set<String> _selectedObjectKeys = {};
  
  List<DefaultHttpHeader> _defaultHeaders = [];
  List<TaskHistoryItem> _taskHistory = [];
  
  String _searchQuery = '';
  List<S3Object> _filteredObjects = [];
  
  bool _isLoading = false;
  String? _error;

  // Navigation state
  AppSection _selectedSection = AppSection.s3Browser;

  // Operation progress tracking
  bool _operationInProgress = false;
  int _operationCurrent = 0;
  int _operationTotal = 0;
  String _operationMessage = '';
  String? _operationError;
  bool _operationCancelled = false;
  String? _operationTaskId; // activity-panel task mirroring the operation's progress

  // Getters
  AwsCredentials? get credentials => _credentials;
  AwsProfile? get currentProfile => _currentProfile;
  List<S3Bucket> get buckets => _buckets;
  S3Bucket? get selectedBucket => _selectedBucket;
  List<S3Object> get objects => _objects;
  String get currentPrefix => _currentPrefix;
  List<String> get breadcrumbs => _breadcrumbs;
  Set<String> get selectedObjectKeys => _selectedObjectKeys;
  List<DefaultHttpHeader> get defaultHeaders => _defaultHeaders;
  List<TaskHistoryItem> get taskHistory => _taskHistory;
  String get searchQuery => _searchQuery;
  List<S3Object> get filteredObjects => _filteredObjects;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Navigation getters
  AppSection get selectedSection => _selectedSection;

  // Operation progress getters
  bool get operationInProgress => _operationInProgress;
  int get operationCurrent => _operationCurrent;
  int get operationTotal => _operationTotal;
  String get operationMessage => _operationMessage;
  String? get operationError => _operationError;
  bool get isAuthenticated => _credentials != null && _awsService.isInitialized;
  
  AwsService get awsService => _awsService;
  CloudFrontService get cloudFrontService => _cloudFrontService;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) {
      debugPrint('[region=${_credentials?.region ?? 'no-credentials'}]: $error');
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _loadSettings();
      final currentProfile = await ProfileService.getCurrentProfile();
      if (currentProfile != null) {
        _currentProfile = currentProfile;
        await login(currentProfile.credentials);
      }
    } catch (e) {
      _setError('Failed to initialize: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadSettings() async {
    _defaultHeaders = await DefaultHeadersService.loadHeaders();
    _taskHistory = await TaskService.loadTasks();
    // Anything other than a cache clear can't still be running after a restart.
    for (final task in _taskHistory.where((t) => t.isRunning && t.operationType != clearCacheTaskType).toList()) {
      await updateTaskStatus(task.id, TaskStatus.failed, details: 'Interrupted: the app was closed while this was running');
    }
    notifyListeners();
  }

  Future<void> saveDefaultHeaders(List<DefaultHttpHeader> headers) async {
    _defaultHeaders = headers;
    await DefaultHeadersService.saveHeaders(headers);
    notifyListeners();
  }
  
  List<TaskHistoryItem> get runningTasks => _taskHistory.where((t) => t.isRunning).toList();

  /// Unique even for tasks started within the same millisecond.
  String newTaskId() => '${DateTime.now().microsecondsSinceEpoch}-${_taskSeq++}';

  Future<void> logTask(TaskHistoryItem item) async {
    _taskHistory.add(item);
    await TaskService.saveTask(item);
    notifyListeners();
  }

  /// Starts a task in the activity panel and returns its id.
  Future<String> beginTask({
    required String type,
    required String target,
    int? total,
    String? details,
    Map<String, String> meta = const {},
  }) async {
    final id = newTaskId();
    await logTask(TaskHistoryItem(
      id: id,
      operationType: type,
      objectKey: target,
      status: TaskStatus.inProgress,
      timestamp: DateTime.now(),
      details: details,
      progressCurrent: total != null ? 0 : null,
      progressTotal: total,
      meta: meta,
    ));
    return id;
  }

  /// Live progress for a running task. Kept in memory only; the final state is
  /// persisted by [updateTaskStatus].
  void updateTaskProgress(String taskId, int current, {int? total, String? details}) {
    final index = _taskHistory.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _taskHistory[index] = _taskHistory[index].copyWith(
      progressCurrent: current,
      progressTotal: total,
      details: details,
    );
    notifyListeners();
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status, {String? details, Map<String, String>? meta}) async {
    final index = _taskHistory.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final finished = status != TaskStatus.pending && status != TaskStatus.inProgress;
      _taskHistory[index] = _taskHistory[index].copyWith(
        status: status,
        details: details,
        finishedAt: finished ? DateTime.now() : null,
        meta: meta,
      );
      await TaskService.saveTask(_taskHistory[index]);
      notifyListeners();
    }
  }

  /// Removes finished tasks from the activity panel; running ones stay.
  Future<void> clearFinishedTasks() async {
    _taskHistory.removeWhere((t) => !t.isRunning);
    await TaskService.saveTasks(_taskHistory);
    notifyListeners();
  }

  void notify(String message, {bool isError = false}) {
    if (!_disposed) _notices.add(AppNotice(message, isError: isError));
  }

  // CloudFront cache clearing

  static const String clearCacheTaskType = 'Clear Cache';

  /// Starts a CloudFront invalidation and tracks it in the activity panel until
  /// CloudFront reports it complete. Throws if CloudFront rejects the request.
  Future<String> clearCloudFrontCache({
    required String distributionId,
    required String domainName,
    required List<String> paths,
  }) async {
    final invalidation = await _cloudFrontService.createInvalidation(distributionId, paths);
    final taskId = await beginTask(
      type: clearCacheTaskType,
      target: '$distributionId ($domainName)',
      details: paths.join(', '),
      meta: {
        'distributionId': distributionId,
        'invalidationId': invalidation.id,
        'paths': paths.join('\n'),
      },
    );
    if (invalidation.status == 'Completed') {
      await _completeCacheTask(taskId);
    } else {
      _watchInvalidation(taskId);
    }
    return taskId;
  }

  /// Resumes polling for cache clears that were still running when the app
  /// was last closed. Called after login, once CloudFront is usable.
  void resumeCacheTasks() {
    for (final task in _taskHistory.where((t) => t.isRunning && t.operationType == clearCacheTaskType)) {
      _watchInvalidation(task.id);
    }
  }

  Future<void> _watchInvalidation(String taskId) async {
    if (!_watchedInvalidations.add(taskId)) return; // already polling
    final deadline = DateTime.now().add(invalidationPollTimeout);
    try {
      while (!_disposed && _cloudFrontService.isInitialized) {
        final task = _taskHistory.where((t) => t.id == taskId).firstOrNull;
        final distId = task?.meta['distributionId'];
        final invId = task?.meta['invalidationId'];
        if (task == null || !task.isRunning || distId == null || invId == null) return;

        try {
          final status = await _cloudFrontService.getInvalidationStatus(distId, invId);
          if (status == 'Completed') {
            await _completeCacheTask(taskId);
            return;
          }
          updateTaskProgress(taskId, 0, details: 'CloudFront status: $status');
        } catch (e) {
          debugPrint('[invalidation] status check failed for $invId: $e');
        }

        if (DateTime.now().isAfter(deadline)) {
          updateTaskProgress(taskId, 0, details: 'Still in progress after ${invalidationPollTimeout.inMinutes} min; check the AWS console');
          return;
        }
        await Future.delayed(invalidationPollInterval);
      }
    } finally {
      _watchedInvalidations.remove(taskId);
    }
  }

  Future<void> _completeCacheTask(String taskId) async {
    final task = _taskHistory.firstWhere((t) => t.id == taskId);
    final clearedAt = DateTime.now();
    final paths = task.meta['paths']?.split('\n') ?? const <String>[];
    await updateTaskStatus(taskId, TaskStatus.completed, details: 'Cache cleared at ${_hms(clearedAt)} for ${paths.join(', ')}');
    notify('Cache cleared on ${task.meta['distributionId']} at ${_hms(clearedAt)}');
  }

  static String _hms(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  void setCurrentProfile(AwsProfile profile) {
    _currentProfile = profile;
    notifyListeners();
  }

  void selectSection(AppSection section) {
    if (section != _selectedSection) {
      // The search box is rebuilt empty, so don't keep filtering behind it.
      _searchQuery = '';
      _filteredObjects = [];
    }
    _selectedSection = section;
    notifyListeners();
  }

  Future<void> login(AwsCredentials credentials) async {
    _setLoading(true);
    _setError(null);

    try {
      await _awsService.initialize(credentials);
      _cloudFrontService.initialize(credentials);
      _credentials = credentials;
      resumeCacheTasks();
      await loadBuckets();
    } catch (e) {
      _setError('Login failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await ProfileService.setCurrentProfile(null);
    _awsService.dispose();
    _cloudFrontService.dispose();
    _credentials = null;
    _currentProfile = null;
    _buckets = [];
    _selectedBucket = null;
    _objects = [];
    _currentPrefix = '';
    _breadcrumbs = [];
    _selectedObjectKeys.clear();
    _setError(null);
    notifyListeners();
  }

  Future<void> loadBuckets() async {
    _setLoading(true);
    _setError(null);

    try {
      _buckets = await _awsService.listBuckets();
    } catch (e) {
      _setError('Failed to load buckets: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectBucket(S3Bucket bucket) async {
    _selectedBucket = bucket;
    _currentPrefix = '';
    _breadcrumbs = [bucket.name];
    
    // Automatically detect and update to the correct bucket region to prevent SignatureDoesNotMatch errors
    if (_credentials != null) {
      try {
        final region = await _awsService.getBucketRegion(bucket.name);
        debugPrint('[REGION_DETECT] Bucket: ${bucket.name}, Detected: $region, Current: ${_credentials!.region}');
        if (region != null && region != _credentials!.region) {
          final updatedCredentials = AwsCredentials(
            accessKeyId: _credentials!.accessKeyId,
            secretAccessKey: _credentials!.secretAccessKey,
            sessionToken: _credentials!.sessionToken,
            region: region,
          );
          _credentials = updatedCredentials;
          await _awsService.initialize(updatedCredentials);
          debugPrint('[REGION_DETECT] Switched to region: $region');
        }
      } catch (e) {
        debugPrint('[REGION_DETECT] ERROR: $e');
      }
    }
    
    await loadObjects();
  }

  Future<void> loadObjects({String? prefix}) async {
    if (_selectedBucket == null) return;
    
    _setLoading(true);
    _setError(null);
    
    try {
      _selectedObjectKeys.clear();
      _searchQuery = '';
      _filteredObjects = [];
      if (prefix != null) {
        _currentPrefix = prefix;
        _updateBreadcrumbs(prefix);
      }
      
      _objects = await _awsService.listObjects(
        _selectedBucket!.name,
        prefix: _currentPrefix.isEmpty ? null : _currentPrefix,
      );
    } catch (e) {
      _setError('Failed to load objects: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _updateBreadcrumbs(String prefix) {
    _breadcrumbs = [_selectedBucket!.name];
    if (prefix.isNotEmpty) {
      final parts = prefix.split('/').where((part) => part.isNotEmpty);
      for (int i = 0; i < parts.length; i++) {
        _breadcrumbs.add(parts.elementAt(i));
      }
    }
  }

  Future<void> navigateToFolder(String folderKey) async {
    await loadObjects(prefix: folderKey);
  }

  Future<void> navigateUp() async {
    if (_breadcrumbs.length <= 1) return;
    
    _breadcrumbs.removeLast();
    if (_breadcrumbs.length == 1) {
      _currentPrefix = '';
    } else {
      _currentPrefix = _breadcrumbs.skip(1).join('/') + '/';
    }
    
    await loadObjects();
  }

  Future<void> navigateToBreadcrumb(int index) async {
    if (index >= _breadcrumbs.length) return;
    
    _breadcrumbs = _breadcrumbs.take(index + 1).toList();
    if (_breadcrumbs.length == 1) {
      _currentPrefix = '';
    } else {
      _currentPrefix = _breadcrumbs.skip(1).join('/') + '/';
    }
    
    await loadObjects();
  }

  Future<void> downloadObject(S3Object object, String savePath) async {
    if (_selectedBucket == null) return;
    
    _setLoading(true);
    _setError(null);
    
    final taskId = newTaskId();
    await logTask(TaskHistoryItem(
      id: taskId,
      operationType: 'Download',
      objectKey: object.key,
      status: TaskStatus.inProgress,
      timestamp: DateTime.now(),
    ));
    
    try {
      final data = await _awsService.downloadObject(_selectedBucket!.name, object.key);
      
      // Save to the provided path
      final file = import_io.File(savePath);
      await file.writeAsBytes(data);
      
      await updateTaskStatus(taskId, TaskStatus.completed, details: 'Saved to $savePath');
    } catch (e) {
      await updateTaskStatus(taskId, TaskStatus.failed, details: e.toString());
      _setError('Failed to download ${object.name}: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Uploads one object under the current prefix. Pass [recordTask] false when
  /// the caller tracks a grouped task itself (e.g. a folder upload).
  Future<void> uploadObject(String key, List<int> data, {String? contentType, bool refresh = true, bool recordTask = true}) async {
    if (_selectedBucket == null) return;
    
    _setLoading(true);
    _setError(null);
    
    final fullKey = _currentPrefix + key;
    final taskId = newTaskId();
    if (recordTask) {
      await logTask(TaskHistoryItem(
        id: taskId,
        operationType: 'Upload',
        objectKey: fullKey,
        status: TaskStatus.inProgress,
        timestamp: DateTime.now(),
      ));
    }
    
    try {
      // Process default headers
      final matchedHeaders = _getMatchedHeaders(_selectedBucket!.name, key);
      
      String? finalContentType = matchedHeaders.remove('content-type') ?? contentType;
      String? contentEncoding = matchedHeaders.remove('content-encoding');
      String? cacheControl = matchedHeaders.remove('cache-control');
      String? contentDisposition = matchedHeaders.remove('content-disposition');
      String? contentLanguage = matchedHeaders.remove('content-language');
      
      await _awsService.uploadObject(
        _selectedBucket!.name,
        fullKey,
        Uint8List.fromList(data),
        contentType: finalContentType,
        contentEncoding: contentEncoding,
        cacheControl: cacheControl,
        contentDisposition: contentDisposition,
        contentLanguage: contentLanguage,
        metadata: matchedHeaders.isNotEmpty ? matchedHeaders : null,
      );
      
      await updateTaskStatus(taskId, TaskStatus.completed);
      
      if (refresh) {
        await loadObjects(); // Refresh the list
      }
    } catch (e) {
      await updateTaskStatus(taskId, TaskStatus.failed, details: e.toString());
      _setError('Failed to upload $key: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Map<String, String> _getMatchedHeaders(String bucketName, String key) {
    Map<String, String> headers = {};
    for (final rule in _defaultHeaders) {
      if (rule.bucket == bucketName) {
        try {
          // Escape all regex special characters first, then convert glob * to regex .*
          final escaped = RegExp.escape(rule.fileMask);
          final regexString = escaped.replaceAll('\\*', '.*');
          final regex = RegExp('^$regexString\$', caseSensitive: false);
          if (regex.hasMatch(key)) {
            headers[rule.headerName.toLowerCase()] = rule.headerValue;
          }
        } catch (e) {
          debugPrint('Regex error for mask ${rule.fileMask}: $e');
        }
      }
    }
    return headers;
  }

  Future<void> updateObjectMetadata(String key, Map<String, String> metadata, {String? contentType, String? contentEncoding}) async {
    if (_selectedBucket == null) return;
    
    _setLoading(true);
    _setError(null);
    
    final fullKey = key;
    final taskId = newTaskId();
    await logTask(TaskHistoryItem(
      id: taskId,
      operationType: 'Update Metadata',
      objectKey: fullKey,
      status: TaskStatus.inProgress,
      timestamp: DateTime.now(),
    ));
    
    try {
      await _awsService.updateObjectMetadata(
        _selectedBucket!.name,
        fullKey,
        metadata,
        contentType: contentType,
        contentEncoding: contentEncoding,
      );
      
      await updateTaskStatus(taskId, TaskStatus.completed);
    } catch (e) {
      await updateTaskStatus(taskId, TaskStatus.failed, details: e.toString());
      _setError('Failed to update metadata for $key: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Selection methods
  void toggleSelection(String key) {
    if (_selectedObjectKeys.contains(key)) {
      _selectedObjectKeys.remove(key);
    } else {
      _selectedObjectKeys.add(key);
    }
    notifyListeners();
  }

  void selectAll() {
    final targetObjects = _searchQuery.isNotEmpty ? _filteredObjects : _objects;
    _selectedObjectKeys.clear();
    for (final obj in targetObjects) {
      _selectedObjectKeys.add(obj.key);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedObjectKeys.clear();
    notifyListeners();
  }

  // Search methods
  void searchObjects(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredObjects = [];
    } else {
      final lowerQuery = query.toLowerCase();
      _filteredObjects = _objects.where((obj) {
        return obj.name.toLowerCase().contains(lowerQuery);
      }).toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredObjects = [];
    notifyListeners();
  }

  // Operation progress methods
  void startOperation({required int total, required String message, String? taskId}) {
    _operationTaskId = taskId;
    if (taskId != null) updateTaskProgress(taskId, 0, total: total);
    _operationInProgress = true;
    _operationCurrent = 0;
    _operationTotal = total;
    _operationMessage = message;
    _operationError = null;
    _operationCancelled = false;
    notifyListeners();
  }

  void updateOperationProgress(int current, {String? message}) {
    if (_operationTaskId case final taskId?) updateTaskProgress(taskId, current);
    _operationCurrent = current;
    if (message != null) _operationMessage = message;
    notifyListeners();
  }

  void setOperationError(String error) {
    _operationError = error;
    _operationInProgress = false;
    notifyListeners();
  }

  void cancelOperation() {
    _operationCancelled = true;
    notifyListeners();
  }

  void clearOperation() {
    _operationTaskId = null;
    _operationInProgress = false;
    _operationCurrent = 0;
    _operationTotal = 0;
    _operationMessage = '';
    _operationError = null;
    _operationCancelled = false;
    notifyListeners();
  }

  // Bulk / Advanced operations
  Future<void> deleteSelected() async {
    if (_selectedBucket == null || _selectedObjectKeys.isEmpty) return;
    
    _setLoading(true);
    _setError(null);
    
    final keysToDelete = _selectedObjectKeys.toList();
    final taskId = newTaskId();
    await logTask(TaskHistoryItem(
      id: taskId,
      operationType: 'Delete',
      objectKey: keysToDelete.join(', '),
      status: TaskStatus.inProgress,
      timestamp: DateTime.now(),
    ));
    
    try {
      // Enumerate all objects to delete
      // A Set keeps keys unique: a folder's listing usually includes its own
      // "folder/" marker, which would otherwise be sent twice.
      final keySet = <String>{};
      for (final key in keysToDelete) {
        if (key.endsWith('/')) {
          final folderObjects = await _awsService.listAllObjectsRecursive(_selectedBucket!.name, prefix: key);
          for (final fObj in folderObjects) {
            keySet.add(fObj.key);
          }
        }
        keySet.add(key);
      }
      final allKeys = keySet.toList();
      
      // Delete in chunks of 1000 with progress
      final chunks = <List<String>>[];
      for (int i = 0; i < allKeys.length; i += 1000) {
        chunks.add(allKeys.skip(i).take(1000).toList());
      }
      
      startOperation(total: chunks.isEmpty ? 1 : chunks.length, message: 'Deleting ${allKeys.length} objects...', taskId: taskId);
      
      for (int i = 0; i < chunks.length; i++) {
        if (_operationCancelled) break;
        updateOperationProgress(i + 1, message: 'Deleting batch ${i + 1} of ${chunks.length}...');
        await _awsService.deleteObjects(_selectedBucket!.name, chunks[i]);
      }
      
      if (!_operationCancelled) {
        _selectedObjectKeys.clear();
        await updateTaskStatus(taskId, TaskStatus.completed);
        await loadObjects();
      } else {
        await updateTaskStatus(taskId, TaskStatus.cancelled, details: 'Cancelled by user');
      }
      
      clearOperation();
    } catch (e) {
      setOperationError('Failed to delete selected objects: $e');
      await updateTaskStatus(taskId, TaskStatus.failed, details: e.toString());
      _setError('Failed to delete selected objects: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> renameItem(String oldKey, String newName) async {
    if (_selectedBucket == null) return;
    
    _setLoading(true);
    _setError(null);
    
    final taskId = newTaskId();
    await logTask(TaskHistoryItem(
      id: taskId,
      operationType: 'Rename',
      objectKey: '$oldKey -> $newName',
      status: TaskStatus.inProgress,
      timestamp: DateTime.now(),
    ));
    
    try {
      final isFolder = oldKey.endsWith('/');
      final parts = oldKey.split('/');
      if (isFolder) parts.removeLast();
      
      final parentPrefix = _currentPrefix;
      final newKey = parentPrefix + newName + (isFolder ? '/' : '');

      // Build list of copy+delete operations
      final items = <_CopyDeleteItem>[];
      if (isFolder) {
        final folderObjects = await _awsService.listAllObjectsRecursive(_selectedBucket!.name, prefix: oldKey);
        for (final obj in folderObjects) {
          final suffix = obj.key.substring(oldKey.length);
          items.add(_CopyDeleteItem(
            sourceKey: obj.key,
            destKey: newKey + suffix,
          ));
        }
        items.add(_CopyDeleteItem(sourceKey: oldKey, destKey: newKey));
      } else {
        items.add(_CopyDeleteItem(sourceKey: oldKey, destKey: newKey));
      }
      
      startOperation(total: items.length * 2, message: 'Renaming...', taskId: taskId);
      
      int progress = 0;
      for (final item in items) {
        if (_operationCancelled) break;
        progress++;
        updateOperationProgress(progress, message: 'Copying ${item.sourceKey}...');
        await _awsService.copyObject(_selectedBucket!.name, item.sourceKey, _selectedBucket!.name, item.destKey);
        progress++;
        updateOperationProgress(progress, message: 'Deleting ${item.sourceKey}...');
        await _awsService.deleteObject(_selectedBucket!.name, item.sourceKey);
      }
      
      if (!_operationCancelled) {
        _selectedObjectKeys.remove(oldKey);
        await updateTaskStatus(taskId, TaskStatus.completed);
        await loadObjects();
      } else {
        await updateTaskStatus(taskId, TaskStatus.cancelled, details: 'Cancelled by user');
      }
      
      clearOperation();
    } catch (e) {
      setOperationError('Failed to rename $oldKey: $e');
      await updateTaskStatus(taskId, TaskStatus.failed, details: e.toString());
      _setError('Failed to rename $oldKey: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> moveSelected(String destinationPrefix) async {
    if (_selectedBucket == null || _selectedObjectKeys.isEmpty) return;
    
    _setLoading(true);
    _setError(null);
    
    final keysToMove = _selectedObjectKeys.toList();
    final taskId = newTaskId();
    await logTask(TaskHistoryItem(
      id: taskId,
      operationType: 'Move',
      objectKey: '${keysToMove.length} object(s) -> $destinationPrefix',
      status: TaskStatus.inProgress,
      timestamp: DateTime.now(),
    ));
    
    try {
      // Enumerate all copy+delete operations
      final items = <_CopyDeleteItem>[];
      for (final key in keysToMove) {
        final isFolder = key.endsWith('/');
        final name = key.split('/').where((p) => p.isNotEmpty).last;
        final newKey = destinationPrefix + name + (isFolder ? '/' : '');

        if (isFolder) {
          final folderObjects = await _awsService.listAllObjectsRecursive(_selectedBucket!.name, prefix: key);
          for (final obj in folderObjects) {
            final suffix = obj.key.substring(key.length);
            items.add(_CopyDeleteItem(sourceKey: obj.key, destKey: newKey + suffix));
          }
          items.add(_CopyDeleteItem(sourceKey: key, destKey: newKey));
        } else {
          items.add(_CopyDeleteItem(sourceKey: key, destKey: newKey));
        }
      }
      
      startOperation(total: items.length * 2, message: 'Moving ${keysToMove.length} object(s)...', taskId: taskId);
      
      int progress = 0;
      for (final item in items) {
        if (_operationCancelled) break;
        progress++;
        updateOperationProgress(progress, message: 'Copying ${item.sourceKey}...');
        await _awsService.copyObject(_selectedBucket!.name, item.sourceKey, _selectedBucket!.name, item.destKey);
        progress++;
        updateOperationProgress(progress, message: 'Deleting ${item.sourceKey}...');
        await _awsService.deleteObject(_selectedBucket!.name, item.sourceKey);
      }
      
      if (!_operationCancelled) {
        _selectedObjectKeys.clear();
        await updateTaskStatus(taskId, TaskStatus.completed);
        await loadObjects();
      } else {
        await updateTaskStatus(taskId, TaskStatus.cancelled, details: 'Cancelled by user');
      }
      
      clearOperation();
    } catch (e) {
      setOperationError('Failed to move objects: $e');
      await updateTaskStatus(taskId, TaskStatus.failed, details: e.toString());
      _setError('Failed to move objects: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> copySelected(String destBucket, String destPrefix) async {
    if (_selectedBucket == null || _selectedObjectKeys.isEmpty) return;
    
    _setLoading(true);
    _setError(null);
    
    final keysToCopy = _selectedObjectKeys.toList();
    final taskId = newTaskId();
    await logTask(TaskHistoryItem(
      id: taskId,
      operationType: 'Copy',
      objectKey: '${keysToCopy.length} object(s) -> $destBucket/$destPrefix',
      status: TaskStatus.inProgress,
      timestamp: DateTime.now(),
    ));
    
    try {
      // Detect destination region for cross-bucket copies
      String? destRegion;
      if (destBucket != _selectedBucket!.name) {
        destRegion = await _awsService.getBucketRegion(destBucket);
      }
      
      // Enumerate all objects to copy
      final items = <_CopyItem>[];
      for (final key in keysToCopy) {
        final isFolder = key.endsWith('/');
        final name = key.split('/').where((p) => p.isNotEmpty).last;
        final newKey = destPrefix + name + (isFolder ? '/' : '');

        if (isFolder) {
          final folderObjects = await _awsService.listAllObjectsRecursive(_selectedBucket!.name, prefix: key);
          for (final obj in folderObjects) {
            final suffix = obj.key.substring(key.length);
            items.add(_CopyItem(sourceKey: obj.key, destKey: newKey + suffix));
          }
          items.add(_CopyItem(sourceKey: key, destKey: newKey));
        } else {
          items.add(_CopyItem(sourceKey: key, destKey: newKey));
        }
      }
      
      startOperation(total: items.length, message: 'Copying ${keysToCopy.length} object(s)...', taskId: taskId);
      
      for (int i = 0; i < items.length; i++) {
        if (_operationCancelled) break;
        final item = items[i];
        updateOperationProgress(i + 1, message: 'Copying ${item.sourceKey}...');
        await _awsService.copyObject(
          _selectedBucket!.name,
          item.sourceKey,
          destBucket,
          item.destKey,
          destRegion: destRegion,
        );
      }
      
      if (!_operationCancelled) {
        _selectedObjectKeys.clear();
        await updateTaskStatus(taskId, TaskStatus.completed);
        await loadObjects();
      } else {
        await updateTaskStatus(taskId, TaskStatus.cancelled, details: 'Cancelled by user');
      }
      
      clearOperation();
    } catch (e) {
      setOperationError('Failed to copy objects: $e');
      await updateTaskStatus(taskId, TaskStatus.failed, details: e.toString());
      _setError('Failed to copy objects: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Downloads every selected file and everything under each selected folder
  /// into [destDir], keeping the folder structure. Returns the number of files
  /// written. Per-file failures don't stop the run; they're reported through
  /// [operationError] at the end.
  Future<int> downloadSelectedTo(String destDir) async {
    if (_selectedBucket == null || _selectedObjectKeys.isEmpty) return 0;

    _setLoading(true);
    _setError(null);

    final bucketName = _selectedBucket!.name;
    final basePrefix = _currentPrefix;
    final selectedKeys = _selectedObjectKeys.toList();
    final taskId = newTaskId();
    await logTask(TaskHistoryItem(
      id: taskId,
      operationType: 'Download',
      objectKey: '${selectedKeys.length} item(s) -> $destDir',
      status: TaskStatus.inProgress,
      timestamp: DateTime.now(),
    ));

    try {
      // Enumerate all files to download
      final keys = <String>[];
      for (final key in selectedKeys) {
        if (key.endsWith('/')) {
          final folderObjects = await _awsService.listAllObjectsRecursive(bucketName, prefix: key);
          keys.addAll(folderObjects.map((o) => o.key));
        } else {
          keys.add(key);
        }
      }
      final items = <({String key, String localPath})>[
        for (final key in keys)
          if (localPathForKey(destDir, basePrefix, key) case final path?)
            (key: key, localPath: path),
      ];

      startOperation(total: items.length, message: 'Downloading ${items.length} file(s)...', taskId: taskId);

      int downloaded = 0;
      final failed = <String>[];
      for (int i = 0; i < items.length; i++) {
        if (_operationCancelled) break;
        final item = items[i];
        updateOperationProgress(i + 1, message: 'Downloading ${item.key}...');
        try {
          final data = await _awsService.downloadObject(bucketName, item.key);
          final file = import_io.File(item.localPath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data);
          downloaded++;
        } catch (e) {
          debugPrint('[download] FAILED ${item.key}: $e');
          failed.add(item.key);
        }
      }

      if (_operationCancelled) {
        await updateTaskStatus(taskId, TaskStatus.cancelled, details: 'Cancelled by user after $downloaded file(s)');
        clearOperation();
      } else if (failed.isNotEmpty) {
        final preview = failed.take(5).join(', ');
        final more = failed.length > 5 ? ' (+${failed.length - 5} more)' : '';
        final message = 'Downloaded $downloaded file(s), ${failed.length} failed: $preview$more';
        await updateTaskStatus(taskId, TaskStatus.failed, details: message);
        setOperationError(message);
      } else {
        await updateTaskStatus(taskId, TaskStatus.completed, details: 'Saved $downloaded file(s) to $destDir');
        clearOperation();
      }
      return downloaded;
    } catch (e) {
      setOperationError('Failed to download: $e');
      await updateTaskStatus(taskId, TaskStatus.failed, details: e.toString());
      _setError('Failed to download: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _notices.close();
    _awsService.dispose();
    _cloudFrontService.dispose();
    super.dispose();
  }
}

class _CopyItem {
  final String sourceKey;
  final String destKey;
  const _CopyItem({required this.sourceKey, required this.destKey});
}

class _CopyDeleteItem {
  final String sourceKey;
  final String destKey;
  const _CopyDeleteItem({required this.sourceKey, required this.destKey});
}