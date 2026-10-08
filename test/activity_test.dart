import 'package:aws_cloudfront_api/cloudfront-2020-05-31.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoistbay/models/task_history.dart';
import 'package:hoistbay/providers/app_state.dart';
import 'package:hoistbay/screens/activity_screen.dart';
import 'package:hoistbay/services/cloudfront_service.dart';
import 'package:hoistbay/services/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CloudFront stand-in: invalidations report the queued statuses in order.
class FakeCloudFront extends CloudFrontService {
  final List<String> statuses;
  final bool failCreate;
  int statusChecks = 0;
  List<String>? createdPaths;

  FakeCloudFront(this.statuses, {this.failCreate = false});

  @override
  bool get isInitialized => true;

  @override
  Future<Invalidation> createInvalidation(String distributionId, List<String> paths) async {
    if (failCreate) throw Exception('AccessDenied');
    createdPaths = paths;
    return Invalidation(
      createTime: DateTime.now(),
      id: 'I123',
      status: 'InProgress',
      invalidationBatch: InvalidationBatch(
        callerReference: 'ref',
        paths: Paths(quantity: paths.length, items: paths),
      ),
    );
  }

  @override
  Future<String> getInvalidationStatus(String distributionId, String invalidationId) async {
    final status = statuses[statusChecks.clamp(0, statuses.length - 1)];
    statusChecks++;
    return status;
  }
}

Future<void> waitFor(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TaskHistoryItem', () {
    test('loads entries saved before the new fields existed', () {
      final task = TaskHistoryItem.fromMap({
        'id': '1',
        'operationType': 'Upload',
        'objectKey': 'a.txt',
        'status': 2,
        'timestamp': '2026-10-01T10:00:00.000',
        'details': null,
      });
      expect(task.status, TaskStatus.completed);
      expect(task.finishedAt, isNull);
      expect(task.meta, isEmpty);
    });

    test('round-trips through toMap/fromMap', () {
      final task = TaskHistoryItem(
        id: '1',
        operationType: AppState.clearCacheTaskType,
        objectKey: 'E1 (d.cloudfront.net)',
        status: TaskStatus.cancelled,
        timestamp: DateTime(2026, 10, 7, 9),
        finishedAt: DateTime(2026, 10, 7, 9, 5),
        progressCurrent: 3,
        progressTotal: 10,
        meta: {'invalidationId': 'I1'},
      );
      final copy = TaskHistoryItem.fromMap(task.toMap());
      expect(copy.status, TaskStatus.cancelled);
      expect(copy.finishedAt, DateTime(2026, 10, 7, 9, 5));
      expect(copy.progressTotal, 10);
      expect(copy.meta, {'invalidationId': 'I1'});
    });

    test('an unknown status index loads as failed instead of crashing', () {
      final task = TaskHistoryItem.fromMap({'id': '1', 'status': 99, 'timestamp': '2026-10-01T10:00:00.000'});
      expect(task.status, TaskStatus.failed);
    });
  });

  group('AppState tasks', () {
    test('task ids are unique even when created back to back', () {
      final appState = AppState();
      final ids = {for (var i = 0; i < 1000; i++) appState.newTaskId()};
      expect(ids, hasLength(1000));
    });

    test('progress updates live; finishing records finishedAt and persists', () async {
      final appState = AppState();
      final id = await appState.beginTask(type: 'Upload', target: '3 file(s) -> b/', total: 3);
      expect(appState.runningTasks, hasLength(1));

      appState.updateTaskProgress(id, 2);
      expect(appState.taskHistory.single.progressCurrent, 2);

      await appState.updateTaskStatus(id, TaskStatus.completed, details: 'Uploaded 3 file(s)');
      expect(appState.runningTasks, isEmpty);
      expect(appState.taskHistory.single.finishedAt, isNotNull);

      final stored = (await TaskService.loadTasks()).single;
      expect(stored.status, TaskStatus.completed);
      expect(stored.finishedAt, isNotNull);
      expect(stored.details, 'Uploaded 3 file(s)');
    });

    test('clearing finished tasks keeps running ones', () async {
      final appState = AppState();
      final running = await appState.beginTask(type: 'Upload', target: 'x');
      final done = await appState.beginTask(type: 'Download', target: 'y');
      await appState.updateTaskStatus(done, TaskStatus.completed);

      await appState.clearFinishedTasks();

      expect(appState.taskHistory.map((t) => t.id), [running]);
      expect((await TaskService.loadTasks()).map((t) => t.id), [running]);
    });

    test('on startup, interrupted uploads are marked failed but cache clears keep running', () async {
      await TaskService.saveTasks([
        TaskHistoryItem(id: 'u', operationType: 'Upload', objectKey: 'x', status: TaskStatus.inProgress, timestamp: DateTime.now()),
        TaskHistoryItem(id: 'c', operationType: AppState.clearCacheTaskType, objectKey: 'E1', status: TaskStatus.inProgress, timestamp: DateTime.now()),
      ]);
      final appState = AppState();
      await appState.initialize(); // no saved profile: loads history only

      final byId = {for (final t in appState.taskHistory) t.id: t};
      expect(byId['u']!.status, TaskStatus.failed);
      expect(byId['u']!.details, contains('Interrupted'));
      expect(byId['c']!.status, TaskStatus.inProgress);
    });
  });

  group('Clear Cache tracking', () {
    test('polls CloudFront until done, then shows "Cache cleared at" and notifies', () async {
      final fake = FakeCloudFront(['InProgress', 'InProgress', 'Completed']);
      final appState = AppState(cloudFrontService: fake)
        ..invalidationPollInterval = const Duration(milliseconds: 1);
      final notices = <AppNotice>[];
      final sub = appState.notices.listen(notices.add);

      final id = await appState.clearCloudFrontCache(
        distributionId: 'E1',
        domainName: 'd.cloudfront.net',
        paths: ['/*'],
      );
      final started = appState.taskHistory.single;
      expect(started.status, TaskStatus.inProgress);
      expect(started.meta['invalidationId'], 'I123');

      await waitFor(() => !appState.taskHistory.single.isRunning);

      final task = appState.taskHistory.singleWhere((t) => t.id == id);
      expect(task.status, TaskStatus.completed);
      expect(task.details, startsWith('Cache cleared at '));
      expect(task.finishedAt, isNotNull);
      expect(fake.statusChecks, 3);
      await waitFor(() => notices.isNotEmpty);
      expect(notices.single.message, contains('Cache cleared on E1'));
      await sub.cancel();
    });

    test('a rejected request throws and records nothing', () async {
      final appState = AppState(cloudFrontService: FakeCloudFront(const [], failCreate: true));
      await expectLater(
        appState.clearCloudFrontCache(distributionId: 'E1', domainName: 'd', paths: ['/*']),
        throwsException,
      );
      expect(appState.taskHistory, isEmpty);
    });

    test('gives up politely after the timeout, leaving the task running', () async {
      final appState = AppState(cloudFrontService: FakeCloudFront(['InProgress']))
        ..invalidationPollInterval = const Duration(milliseconds: 1)
        ..invalidationPollTimeout = Duration.zero;

      await appState.clearCloudFrontCache(distributionId: 'E1', domainName: 'd', paths: ['/*']);
      await waitFor(() => appState.taskHistory.single.details?.contains('AWS console') ?? false);

      expect(appState.taskHistory.single.status, TaskStatus.inProgress);
      expect(appState.taskHistory.single.details, contains('check the AWS console'));
    });
  });

  group('ActivityTile', () {
    Future<void> pumpTile(WidgetTester tester, TaskHistoryItem task) => tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ActivityTile(task: task))),
        );

    testWidgets('a finished cache clear reads "Cache cleared" with its time', (tester) async {
      await pumpTile(
        tester,
        TaskHistoryItem(
          id: '1',
          operationType: AppState.clearCacheTaskType,
          objectKey: 'E1 (d.cloudfront.net)',
          status: TaskStatus.completed,
          timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
          finishedAt: DateTime.now(),
          details: 'Cache cleared at 14:05:40 for /*',
        ),
      );
      expect(find.text('Cache cleared'), findsOneWidget);
      expect(find.text('Cache cleared at 14:05:40 for /*'), findsOneWidget);
      expect(find.textContaining('(3m 0s)'), findsOneWidget);
    });

    testWidgets('a running upload shows exact progress', (tester) async {
      await pumpTile(
        tester,
        TaskHistoryItem(
          id: '1',
          operationType: 'Upload',
          objectKey: '10 file(s) -> b/',
          status: TaskStatus.inProgress,
          timestamp: DateTime.now(),
          progressCurrent: 3,
          progressTotal: 10,
        ),
      );
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('3 / 10'), findsOneWidget);
      expect(find.textContaining('Started '), findsOneWidget);
    });
  });
}
