import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_history.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../components/app_button.dart';
import '../components/app_progress.dart';

enum ActivityFilter { all, running, uploads, downloads, cache, failed }

extension on ActivityFilter {
  String get label => switch (this) {
        ActivityFilter.all => 'All',
        ActivityFilter.running => 'Running',
        ActivityFilter.uploads => 'Uploads',
        ActivityFilter.downloads => 'Downloads',
        ActivityFilter.cache => 'Cache',
        ActivityFilter.failed => 'Failed',
      };

  bool matches(TaskHistoryItem task) => switch (this) {
        ActivityFilter.all => true,
        ActivityFilter.running => task.isRunning,
        ActivityFilter.uploads => task.operationType == 'Upload',
        ActivityFilter.downloads => task.operationType == 'Download',
        ActivityFilter.cache => task.operationType == AppState.clearCacheTaskType,
        ActivityFilter.failed => task.status == TaskStatus.failed,
      };
}

/// The status panel: every upload, download, cache clear and bulk operation,
/// with live progress for running ones and history for finished ones.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  ActivityFilter _filter = ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final tasks = appState.taskHistory.where(_filter.matches).toList()
          ..sort((a, b) {
            // Running first, then newest first.
            if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
            return b.timestamp.compareTo(a.timestamp);
          });
        final hasFinished = appState.taskHistory.any((t) => !t.isRunning);

        return Container(
          color: AppColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Activity', style: AppTypography.headline),
                        const SizedBox(width: AppSpacing.md),
                        if (appState.runningTasks.isNotEmpty)
                          AppStatusBadge(
                            label: '${appState.runningTasks.length} running',
                            color: AppColors.primary,
                          ),
                        const Spacer(),
                        AppButton(
                          label: 'Clear finished',
                          icon: Icons.delete_sweep_outlined,
                          variant: AppButtonVariant.text,
                          onPressed: hasFinished ? () => appState.clearFinishedTasks() : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final f in ActivityFilter.values)
                          ChoiceChip(
                            label: Text(f.label),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? AppEmptyState(
                        icon: Icons.history,
                        title: _filter == ActivityFilter.all ? 'No activity yet' : 'Nothing here',
                        subtitle: 'Uploads, downloads, cache clears and other operations show up here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) => ActivityTile(task: tasks[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ActivityTile extends StatelessWidget {
  final TaskHistoryItem task;

  const ActivityTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = statusOf(task);
    final total = task.progressTotal;
    final current = task.progressCurrent ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconFor(task.operationType), size: 18, color: statusColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(task.operationType, style: AppTypography.bodyMedium),
                    const SizedBox(width: AppSpacing.sm),
                    AppStatusBadge(label: statusLabel, color: statusColor),
                    const Spacer(),
                    Text(timingOf(task), style: AppTypography.small),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  task.objectKey,
                  style: AppTypography.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.isRunning) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppProgressIndicator(
                    value: total != null && total > 0 ? current / total : null,
                  ),
                  if (total != null && total > 0) ...[
                    const SizedBox(height: 2),
                    Text('$current / $total', style: AppTypography.small),
                  ],
                ],
                if (task.details != null && task.details!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    task.details!,
                    style: AppTypography.small.copyWith(
                      color: task.status == TaskStatus.failed ? AppColors.error : AppColors.textSecondary,
                    ),
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData iconFor(String type) => switch (type) {
        'Upload' => Icons.upload,
        'Download' => Icons.download,
        AppState.clearCacheTaskType => Icons.cleaning_services_outlined,
        'Delete' => Icons.delete_outline,
        'Copy' => Icons.content_copy,
        'Move' => Icons.drive_file_move_outline,
        'Rename' => Icons.edit_outlined,
        _ => Icons.task_alt,
      };

  /// The badge for a task. A finished cache clear reads "Cache cleared".
  static (String, Color) statusOf(TaskHistoryItem task) => switch (task.status) {
        TaskStatus.pending => ('Pending', AppColors.textSecondary),
        TaskStatus.inProgress => (
            task.operationType == AppState.clearCacheTaskType ? 'Clearing' : 'In progress',
            AppColors.primary,
          ),
        TaskStatus.completed => (
            task.operationType == AppState.clearCacheTaskType ? 'Cache cleared' : 'Done',
            AppColors.success,
          ),
        TaskStatus.failed => ('Failed', AppColors.error),
        TaskStatus.cancelled => ('Cancelled', AppColors.warning),
      };

  /// "Started 14:02:11" while running; "14:02:11 → 14:05:40 (3m 29s)" once finished.
  static String timingOf(TaskHistoryItem task) {
    final start = _clock(task.timestamp);
    final end = task.finishedAt;
    if (end == null) return 'Started $start';
    return '$start → ${_clock(end)} (${formatDuration(end.difference(task.timestamp))})';
  }

  static String formatDuration(Duration d) {
    if (d.inSeconds < 1) return '<1s';
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  static String _clock(DateTime t) {
    final now = DateTime.now();
    final hms = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? hms : '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} $hms';
  }
}
