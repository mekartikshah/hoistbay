import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/s3_object.dart';
import '../models/task_history.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../components/app_button.dart';
import '../components/app_dialog.dart';
import '../components/app_input.dart';
import '../components/app_progress.dart';

class ObjectDetailsPane extends StatefulWidget {
  final S3Object object;
  final String bucketName;

  const ObjectDetailsPane({
    super.key,
    required this.object,
    required this.bucketName,
  });

  @override
  State<ObjectDetailsPane> createState() => _ObjectDetailsPaneState();
}

class _ObjectDetailsPaneState extends State<ObjectDetailsPane>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _metadata;
  List<dynamic>? _tags;
  List<dynamic>? _versions;

  bool _isLoadingMetadata = false;
  bool _isLoadingTags = false;
  bool _isLoadingVersions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadDataForCurrentTab();
  }

  @override
  void didUpdateWidget(ObjectDetailsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.object.key != widget.object.key) {
      _metadata = null;
      _tags = null;
      _versions = null;
      _loadDataForCurrentTab();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadDataForCurrentTab();
  }

  Future<void> _loadDataForCurrentTab() async {
    if (widget.object.isFolder) return;

    final appState = context.read<AppState>();
    final s3 = appState.awsService;

    switch (_tabController.index) {
      case 0:
      case 1:
        if (_metadata == null && !_isLoadingMetadata) {
          setState(() => _isLoadingMetadata = true);
          try {
            final output = await s3.headObject(widget.bucketName, widget.object.key);
            setState(() => _metadata = _extractHeadObject(output));
          } catch (e) {
            setState(() => _metadata = {'Error': e.toString()});
          } finally {
            if (mounted) setState(() => _isLoadingMetadata = false);
          }
        }
        break;
      case 2:
        if (_tags == null && !_isLoadingTags) {
          setState(() => _isLoadingTags = true);
          try {
            final output = await s3.getObjectTagging(widget.bucketName, widget.object.key);
            setState(() => _tags = _extractTags(output));
          } catch (e) {
            setState(() => _tags = []);
          } finally {
            if (mounted) setState(() => _isLoadingTags = false);
          }
        }
        break;
      case 3:
        if (_versions == null && !_isLoadingVersions) {
          setState(() => _isLoadingVersions = true);
          try {
            final output = await s3.listObjectVersions(widget.bucketName, widget.object.key);
            setState(() => _versions = _extractVersions(output));
          } catch (e) {
            setState(() => _versions = []);
          } finally {
            if (mounted) setState(() => _isLoadingVersions = false);
          }
        }
        break;
      case 4:
        break;
    }
  }

  Map<String, dynamic> _extractHeadObject(dynamic output) {
    try {
      return {
        'ContentType': output.contentType,
        'ContentLength': output.contentLength,
        'ContentEncoding': output.contentEncoding,
        'ETag': output.eTag,
        'LastModified': output.lastModified?.toString(),
        'Metadata': output.metadata,
      };
    } catch (_) {
      return {'Data': output.toString()};
    }
  }

  List<dynamic> _extractTags(dynamic output) {
    try {
      return output.tagSet ?? [];
    } catch (_) {
      return [];
    }
  }

  List<dynamic> _extractVersions(dynamic output) {
    try {
      return output.versions ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: Column(
        children: [
          Container(
            color: AppColors.backgroundSecondary,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              isScrollable: true,
              labelStyle: AppTypography.captionMedium.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: AppTypography.captionMedium,
              tabs: const [
                Tab(text: 'Properties'),
                Tab(text: 'Headers'),
                Tab(text: 'Tags'),
                Tab(text: 'Versions'),
                Tab(text: 'Tasks'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPropertiesTab(),
                _buildHeadersTab(),
                _buildTagsTab(),
                _buildVersionsTab(),
                _buildTasksTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesTab() {
    if (widget.object.isFolder) {
      return const AppEmptyState(
        icon: Icons.folder_outlined,
        title: 'Folder selected',
        subtitle: 'Properties not available for folders',
      );
    }

    if (_isLoadingMetadata) {
      return const Center(child: AppCircularProgress());
    }

    final data = _metadata ?? {};

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildDetailRow('Name', widget.object.name),
        _buildDetailRow('Key', widget.object.key),
        _buildDetailRow('Size', widget.object.displaySize),
        if (data.containsKey('ContentType'))
          _buildDetailRow('Content Type', data['ContentType']?.toString() ?? '-'),
        if (data.containsKey('ContentLength'))
          _buildDetailRow('Content Length', data['ContentLength']?.toString() ?? '-'),
        if (data.containsKey('LastModified'))
          _buildDetailRow('Last Modified', data['LastModified']?.toString() ?? '-'),
        if (data.containsKey('ETag'))
          _buildDetailRow('ETag', data['ETag']?.toString() ?? '-'),
      ],
    );
  }

  Widget _buildHeadersTab() {
    if (widget.object.isFolder) {
      return const AppEmptyState(
        icon: Icons.folder_outlined,
        title: 'Folder selected',
        subtitle: 'Headers not available for folders',
      );
    }

    if (_isLoadingMetadata) {
      return const Center(child: AppCircularProgress());
    }

    final data = _metadata ?? {};
    final headersMap = <String, String>{};

    if (data['ContentType'] != null) headersMap['Content-Type'] = data['ContentType'].toString();
    if (data['ContentEncoding'] != null) headersMap['Content-Encoding'] = data['ContentEncoding'].toString();

    final metadataObj = data['Metadata'];
    if (metadataObj is Map) {
      metadataObj.forEach((key, value) {
        headersMap['x-amz-meta-$key'] = value.toString();
      });
    }

    if (headersMap.isEmpty) {
      return const AppEmptyState(
        icon: Icons.http,
        title: 'No custom headers',
        subtitle: 'This object has no custom headers',
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: headersMap.length,
            itemBuilder: (context, index) {
              final key = headersMap.keys.elementAt(index);
              final value = headersMap[key]!;
              return _buildDetailRow(key, value);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppButton(
            label: 'Edit Metadata',
            icon: Icons.edit,
            variant: AppButtonVariant.secondary,
            onPressed: () => _showEditMetadataDialog(data),
          ),
        ),
      ],
    );
  }

  void _showEditMetadataDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _EditMetadataDialog(
        initialMetadata: data,
        onSave: (metadata, contentType, contentEncoding) async {
          final appState = context.read<AppState>();
          await appState.updateObjectMetadata(
            widget.object.key,
            metadata,
            contentType: contentType,
            contentEncoding: contentEncoding,
          );
          setState(() => _metadata = null);
          _loadDataForCurrentTab();
        },
      ),
    );
  }

  Widget _buildTagsTab() {
    if (widget.object.isFolder) {
      return const AppEmptyState(
        icon: Icons.folder_outlined,
        title: 'Folder selected',
        subtitle: 'Tags not available for folders',
      );
    }

    if (_isLoadingTags) {
      return const Center(child: AppCircularProgress());
    }

    final tags = _tags ?? [];
    if (tags.isEmpty) {
      return const AppEmptyState(
        icon: Icons.label_outline,
        title: 'No tags',
        subtitle: 'This object has no tags',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final tag = tags[index];
        try {
          return _buildDetailRow(tag.key.toString(), tag.value.toString());
        } catch (_) {
          return _buildDetailRow('Tag $index', tag.toString());
        }
      },
    );
  }

  Widget _buildVersionsTab() {
    if (widget.object.isFolder) {
      return const AppEmptyState(
        icon: Icons.folder_outlined,
        title: 'Folder selected',
        subtitle: 'Versions not available for folders',
      );
    }

    if (_isLoadingVersions) {
      return const Center(child: AppCircularProgress());
    }

    final versions = _versions ?? [];
    if (versions.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history,
        title: 'No versions',
        subtitle: 'Versioning may not be enabled for this bucket',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: versions.length,
      itemBuilder: (context, index) {
        final version = versions[index];
        try {
          final isLatest = version.isLatest == true ? ' (Latest)' : '';
          return ListTile(
            dense: true,
            title: Text('${version.versionId}$isLatest', style: AppTypography.body),
            subtitle: Text(
              'Modified: ${version.lastModified} - Size: ${version.size}',
              style: AppTypography.caption,
            ),
          );
        } catch (_) {
          return ListTile(
            dense: true,
            title: Text(version.toString(), style: AppTypography.body),
          );
        }
      },
    );
  }

  Widget _buildTasksTab() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final tasks = appState.taskHistory
            .where((t) => t.objectKey.contains(widget.object.key))
            .toList();

        if (tasks.isEmpty) {
          return const AppEmptyState(
            icon: Icons.task_alt,
            title: 'No tasks',
            subtitle: 'No previous tasks found for this object',
          );
        }

        tasks.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              ),
              child: Row(
                children: [
                  _getStatusIcon(task.status),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${task.operationType} - ${task.objectKey}',
                          style: AppTypography.body,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTime(task.timestamp),
                          style: AppTypography.caption,
                        ),
                        if (task.details != null && task.details!.isNotEmpty)
                          Text(
                            task.details!,
                            style: AppTypography.small.copyWith(color: AppColors.error),
                          ),
                      ],
                    ),
                  ),
                  AppStatusBadge(
                    label: task.status.name.toUpperCase(),
                    color: _getStatusColor(task.status),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTypography.captionMedium.copyWith(color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: AppTypography.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return const Icon(Icons.schedule, color: AppColors.textTertiary, size: 20);
      case TaskStatus.inProgress:
        return const Icon(Icons.autorenew, color: AppColors.primary, size: 20);
      case TaskStatus.completed:
        return const Icon(Icons.check_circle, color: AppColors.success, size: 20);
      case TaskStatus.failed:
        return const Icon(Icons.error, color: AppColors.error, size: 20);
      case TaskStatus.cancelled:
        return const Icon(Icons.cancel, color: AppColors.warning, size: 20);
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return AppColors.textTertiary;
      case TaskStatus.inProgress:
        return AppColors.primary;
      case TaskStatus.completed:
        return AppColors.success;
      case TaskStatus.failed:
        return AppColors.error;
      case TaskStatus.cancelled:
        return AppColors.warning;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")} ${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}:${dt.second.toString().padLeft(2, "0")}';
  }
}

class _EditMetadataDialog extends StatefulWidget {
  final Map<String, dynamic> initialMetadata;
  final void Function(Map<String, String> metadata, String? contentType, String? contentEncoding) onSave;

  const _EditMetadataDialog({
    required this.initialMetadata,
    required this.onSave,
  });

  @override
  State<_EditMetadataDialog> createState() => _EditMetadataDialogState();
}

class _EditMetadataDialogState extends State<_EditMetadataDialog> {
  late TextEditingController _contentTypeCtrl;
  late TextEditingController _contentEncodingCtrl;

  final List<MapEntry<TextEditingController, TextEditingController>> _customMetadata = [];

  @override
  void initState() {
    super.initState();
    _contentTypeCtrl = TextEditingController(text: widget.initialMetadata['ContentType']?.toString() ?? '');
    _contentEncodingCtrl = TextEditingController(text: widget.initialMetadata['ContentEncoding']?.toString() ?? '');

    final meta = widget.initialMetadata['Metadata'];
    if (meta is Map) {
      meta.forEach((key, value) {
        _customMetadata.add(MapEntry(
          TextEditingController(text: key.toString()),
          TextEditingController(text: value.toString()),
        ));
      });
    }
  }

  @override
  void dispose() {
    _contentTypeCtrl.dispose();
    _contentEncodingCtrl.dispose();
    for (final entry in _customMetadata) {
      entry.key.dispose();
      entry.value.dispose();
    }
    super.dispose();
  }

  void _addCustomMetadata() {
    setState(() {
      _customMetadata.add(MapEntry(TextEditingController(), TextEditingController()));
    });
  }

  void _removeCustomMetadata(int index) {
    setState(() {
      final entry = _customMetadata.removeAt(index);
      entry.key.dispose();
      entry.value.dispose();
    });
  }

  void _save() {
    final contentType = _contentTypeCtrl.text.trim().isNotEmpty ? _contentTypeCtrl.text.trim() : null;
    final contentEncoding = _contentEncodingCtrl.text.trim().isNotEmpty ? _contentEncodingCtrl.text.trim() : null;

    final metadata = <String, String>{};
    for (final entry in _customMetadata) {
      final key = entry.key.text.trim();
      final val = entry.value.text.trim();
      if (key.isNotEmpty) {
        metadata[key] = val;
      }
    }

    widget.onSave(metadata, contentType, contentEncoding);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Edit Metadata',
      subtitle: 'Editing metadata creates a new version with updated headers.',
      maxWidth: 600,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Standard Headers', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.md),
            AppInput(
              controller: _contentTypeCtrl,
              label: 'Content-Type',
            ),
            const SizedBox(height: AppSpacing.md),
            AppInput(
              controller: _contentEncodingCtrl,
              label: 'Content-Encoding',
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Custom Metadata', style: AppTypography.headline),
                AppButton(
                  label: 'Add Key',
                  icon: Icons.add,
                  variant: AppButtonVariant.text,
                  onPressed: _addCustomMetadata,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ..._customMetadata.asMap().entries.map((entry) {
              final idx = entry.key;
              final mapEntry = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: AppInput(
                        controller: mapEntry.key,
                        label: 'Key',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: AppInput(
                        controller: mapEntry.value,
                        label: 'Value',
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.remove_circle_outline,
                      color: AppColors.error,
                      onPressed: () => _removeCustomMetadata(idx),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Save & Update',
          variant: AppButtonVariant.primary,
          onPressed: _save,
        ),
      ],
    );
  }
}
