import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/default_http_header.dart';
import '../providers/app_state.dart';

class DefaultHeadersDialog extends StatefulWidget {
  const DefaultHeadersDialog({super.key});

  @override
  State<DefaultHeadersDialog> createState() => _DefaultHeadersDialogState();
}

class _DefaultHeadersDialogState extends State<DefaultHeadersDialog> {
  List<DefaultHttpHeader> _headers = [];
  Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _headers = List.from(context.read<AppState>().defaultHeaders);
  }

  void _saveChanges() {
    context.read<AppState>().saveDefaultHeaders(_headers);
    Navigator.of(context).pop();
  }

  void _showEditDialog([DefaultHttpHeader? header]) {
    final isEditing = header != null;
    String? selectedBucket = header?.bucket;
    if (selectedBucket != null && selectedBucket.isEmpty) selectedBucket = null;
    
    final buckets = context.read<AppState>().buckets.map((b) => b.name).toList();
    if (buckets.isEmpty) {
      // Fallback if no buckets
      buckets.add(header?.bucket ?? '');
    }
    if (selectedBucket == null && buckets.isNotEmpty) {
      selectedBucket = buckets.first;
    }

    final fileMaskController = TextEditingController(text: header?.fileMask ?? '');
    final headerNameController = TextEditingController(text: header?.headerName ?? '');
    final headerValueController = TextEditingController(text: header?.headerValue ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Header' : 'Add Header'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: buckets.contains(selectedBucket) ? selectedBucket : (buckets.isNotEmpty ? buckets.first : null),
                decoration: const InputDecoration(labelText: 'Bucket'),
                items: buckets.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (val) {
                  selectedBucket = val;
                },
              ),
              TextField(
                controller: fileMaskController,
                decoration: const InputDecoration(labelText: 'File mask (e.g., *.js)'),
              ),
              TextField(
                controller: headerNameController,
                decoration: const InputDecoration(labelText: 'Header (e.g., Content-Type)'),
              ),
              TextField(
                controller: headerValueController,
                decoration: const InputDecoration(labelText: 'Value (e.g., application/javascript)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newHeader = DefaultHttpHeader(
                id: isEditing ? header.id : DateTime.now().millisecondsSinceEpoch.toString(),
                bucket: selectedBucket ?? '',
                fileMask: fileMaskController.text.trim(),
                headerName: headerNameController.text.trim(),
                headerValue: headerValueController.text.trim(),
              );

              setState(() {
                if (isEditing) {
                  final index = _headers.indexWhere((h) => h.id == header.id);
                  if (index != -1) _headers[index] = newHeader;
                } else {
                  _headers.add(newHeader);
                }
              });
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteSelected() {
    setState(() {
      _headers.removeWhere((h) => _selectedIds.contains(h.id));
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.http, size: 32, color: Colors.blue),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Default Http Headers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Apply HTTP headers automatically during uploading.', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: true,
                      columns: const [
                        DataColumn(label: Text('Bucket')),
                        DataColumn(label: Text('File mask')),
                        DataColumn(label: Text('Header')),
                        DataColumn(label: Text('Value')),
                      ],
                      rows: _headers.map((header) {
                        final isSelected = _selectedIds.contains(header.id);
                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedIds.add(header.id);
                              } else {
                                _selectedIds.remove(header.id);
                              }
                            });
                          },
                          cells: [
                            DataCell(Text(header.bucket)),
                            DataCell(Text(header.fileMask)),
                            DataCell(Text(header.headerName)),
                            DataCell(Text(header.headerValue)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add, color: Colors.green),
                  label: const Text('Add'),
                  onPressed: () => _showEditDialog(),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit, color: Colors.grey),
                  label: const Text('Edit'),
                  onPressed: _selectedIds.length == 1
                      ? () {
                          final id = _selectedIds.first;
                          final header = _headers.firstWhere((h) => h.id == id);
                          _showEditDialog(header);
                        }
                      : null,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete'),
                  onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, color: Colors.green),
                  label: const Text('Save changes'),
                  onPressed: _saveChanges,
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
