import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../providers/app_state.dart';
import '../widgets/sidebar.dart';
import '../widgets/object_list.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/unified_action_bar.dart';
import '../widgets/upload_button.dart';
import '../screens/cloudfront_manager_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/activity_screen.dart';
import '../theme/app_colors.dart';
import '../components/app_progress.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  bool _isDragging = false;
  StreamSubscription<AppNotice>? _noticeSub;

  @override
  void initState() {
    super.initState();
    // Background events (e.g. a cache clear finishing) are shown wherever the user is.
    final appState = context.read<AppState>();
    _noticeSub = appState.notices.listen((notice) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(notice.message),
        backgroundColor: notice.isError ? AppColors.error : AppColors.success,
        action: SnackBarAction(
          label: 'Activity',
          textColor: AppColors.textInverse,
          onPressed: () => appState.selectSection(AppSection.activity),
        ),
      ));
    });
  }

  @override
  void dispose() {
    _noticeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.isLoading && appState.buckets.isEmpty) {
            return const AppLoadingOverlay(message: 'Loading AWS S3 buckets...');
          }

          return Row(
            children: [
              const Sidebar(),
              const VerticalDivider(width: 1),
              Expanded(
                child: _buildContent(context, appState),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppState appState) {
    switch (appState.selectedSection) {
      case AppSection.s3Browser:
        return _buildS3Browser(context, appState);
      case AppSection.cloudFront:
        return const CloudFrontManagerView();
      case AppSection.activity:
        return const ActivityScreen();
      case AppSection.settings:
        return const SettingsScreen();
    }
  }

  Widget _buildS3Browser(BuildContext context, AppState appState) {
    return Column(
      children: [
        if (appState.selectedBucket != null) ...[
          const BreadcrumbBar(),
          const UnifiedActionBar(),
        ],
        Expanded(
          child: appState.selectedBucket == null
              ? AppEmptyState(
                  icon: Icons.folder_outlined,
                  title: 'Select a bucket',
                  subtitle: 'Choose a bucket from the sidebar to view its contents',
                )
              : DropTarget(
                  onDragEntered: (detail) {
                    setState(() => _isDragging = true);
                  },
                  onDragExited: (detail) {
                    setState(() => _isDragging = false);
                  },
                  onDragDone: (detail) async {
                    setState(() => _isDragging = false);
                    if (appState.selectedBucket == null) return;
                    final paths = detail.files.map((f) => f.path).toList();
                    if (paths.isNotEmpty) {
                      await UploadButton.uploadPaths(context, paths);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      border: _isDragging
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                      color: _isDragging ? AppColors.selectionBlueLight : null,
                    ),
                    child: const ObjectList(),
                  ),
                ),
        ),
      ],
    );
  }
}
