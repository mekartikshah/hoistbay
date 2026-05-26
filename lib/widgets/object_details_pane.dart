import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/s3_object.dart';
import '../models/task_history.dart';

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

class _ObjectDetailsPaneState extends State<ObjectDetailsPane> with SingleTickerProviderStateMixin {
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
      // Clear cache and reload
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
    if (widget.object.isFolder) return; // minimal fetching for folders

    final appState = context.read<AppState>();
    final s3 = appState.awsService;
    
    switch (_tabController.index) {
      case 0: // Properties
      case 1: // Headers
        if (_metadata == null && !_isLoadingMetadata) {
          setState(() => _isLoadingMetadata = true);
          try {
            final output = await s3.headObject(widget.bucketName, widget.object.key);
            setState(() => _metadata = _extractHeadObject(output));
          } catch (e) {
            print('Failed to fetch metadata: $e');
            setState(() => _metadata = {'Error': e.toString()});
          } finally {
            if (mounted) setState(() => _isLoadingMetadata = false);
          }
        }
        break;
      case 2: // Tags
        if (_tags == null && !_isLoadingTags) {
          setState(() => _isLoadingTags = true);
          try {
            final output = await s3.getObjectTagging(widget.bucketName, widget.object.key);
            setState(() => _tags = _extractTags(output));
          } catch (e) {
            print('Failed to fetch tags: $e');
            setState(() => _tags = []);
          } finally {
            if (mounted) setState(() => _isLoadingTags = false);
          }
        }
        break;
      case 3: // Versions
        if (_versions == null && !_isLoadingVersions) {
          setState(() => _isLoadingVersions = true);
          try {
            final output = await s3.listObjectVersions(widget.bucketName, widget.object.key);
            setState(() => _versions = _extractVersions(output));
          } catch (e) {
            print('Failed to fetch versions: $e');
            setState(() => _versions = []);
          } finally {
            if (mounted) setState(() => _isLoadingVersions = false);
          }
        }
        break;
      case 4: // Tasks
        // Driven by appState.taskHistory
        break;
    }
  }

  Map<String, dynamic> _extractHeadObject(dynamic output) {
    try {
      // Reflection/Dynamic access based on typical AWS SDK patterns
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
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: Colors.grey.shade700,
              indicatorColor: Colors.blue.shade700,
              isScrollable: true,
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
      return const Center(child: Text('Folder selected. Properties not available.'));
    }
    
    if (_isLoadingMetadata) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _metadata ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDetailRow('Name', widget.object.name),
        _buildDetailRow('Key', widget.object.key),
        _buildDetailRow('Size', widget.object.displaySize),
        if (data.containsKey('ContentType')) _buildDetailRow('Content Type', data['ContentType']?.toString() ?? '-'),
        if (data.containsKey('ContentLength')) _buildDetailRow('Content Length', data['ContentLength']?.toString() ?? '-'),
        if (data.containsKey('LastModified')) _buildDetailRow('Last Modified', data['LastModified']?.toString() ?? '-'),
        if (data.containsKey('ETag')) _buildDetailRow('ETag', data['ETag']?.toString() ?? '-'),
      ],
    );
  }

  Widget _buildHeadersTab() {
    if (widget.object.isFolder) {
      return const Center(child: Text('Folder selected. Headers not available.'));
    }

    if (_isLoadingMetadata) {
      return const Center(child: CircularProgressIndicator());
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
      return const Center(child: Text('No custom headers found.'));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: headersMap.length,
            itemBuilder: (context, index) {
              final key = headersMap.keys.elementAt(index);
              final value = headersMap[key]!;
              return _buildDetailRow(key, value);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Edit Metadata'),
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
          // Refresh the metadata in this pane
          setState(() {
            _metadata = null;
          });
          _loadDataForCurrentTab();
        },
      ),
    );
  }

  Widget _buildTagsTab() {
    if (widget.object.isFolder) {
      return const Center(child: Text('Folder selected. Tags not available.'));
    }

    if (_isLoadingTags) {
      return const Center(child: CircularProgressIndicator());
    }

    final tags = _tags ?? [];
    if (tags.isEmpty) {
      return const Center(child: Text('No tags found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final tag = tags[index];
        // Dynamic access assuming AWS SDK 'Tag' shape
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
      return const Center(child: Text('Folder selected. Versions not available.'));
    }

    if (_isLoadingVersions) {
      return const Center(child: CircularProgressIndicator());
    }

    final versions = _versions ?? [];
    if (versions.isEmpty) {
      return const Center(child: Text('No versions found or versioning is not enabled.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: versions.length,
      itemBuilder: (context, index) {
        final version = versions[index];
        try {
          final isLatest = version.isLatest == true ? ' (Latest)' : '';
          return ListTile(
            title: Text('${version.versionId}$isLatest'),
            subtitle: Text('Modified: ${version.lastModified} - Size: ${version.size}'),
          );
        } catch (_) {
          return ListTile(title: Text(version.toString()));
        }
      },
    );
  }

  Widget _buildTasksTab() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Filter tasks related to this object key
        final tasks = appState.taskHistory.where((t) => t.objectKey.contains(widget.object.key)).toList();
        
        if (tasks.isEmpty) {
          return const Center(child: Text('No previous tasks found for this object.'));
        }
        
        // Sort by timestamp descending
        tasks.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: _getStatusIcon(task.status),
                title: Text('${task.operationType} - ${task.objectKey}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatDateTime(task.timestamp)),
                    if (task.details != null && task.details!.isNotEmpty)
                      Text(task.details!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
                trailing: Text(
                  task.status.name.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(task.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Icon _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return const Icon(Icons.schedule, color: Colors.grey);
      case TaskStatus.inProgress:
        return const Icon(Icons.autorenew, color: Colors.blue);
      case TaskStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case TaskStatus.failed:
        return const Icon(Icons.error, color: Colors.red);
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.failed:
        return Colors.red;
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
    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Edit Metadata', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Editing metadata creates a new version of the object with updated headers.', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Standard Headers', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contentTypeCtrl,
                      decoration: const InputDecoration(labelText: 'Content-Type', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contentEncodingCtrl,
                      decoration: const InputDecoration(labelText: 'Content-Encoding', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Custom Metadata (x-amz-meta-*)', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _addCustomMetadata,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Key'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._customMetadata.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final mapEntry = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: mapEntry.key,
                                decoration: const InputDecoration(labelText: 'Key', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: mapEntry.value,
                                decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder()),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => _removeCustomMetadata(idx),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save & Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

