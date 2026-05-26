import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aws_cloudfront_api/cloudfront-2020-05-31.dart';
import '../providers/app_state.dart';

class CloudFrontManagerScreen extends StatelessWidget {
  const CloudFrontManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CloudFront Manager')),
      body: const CloudFrontManagerView(),
    );
  }
}

class CloudFrontManagerView extends StatefulWidget {
  const CloudFrontManagerView({super.key});

  @override
  State<CloudFrontManagerView> createState() => _CloudFrontManagerViewState();
}

class _CloudFrontManagerViewState extends State<CloudFrontManagerView> {
  List<DistributionSummary> _distributions = [];
  DistributionSummary? _selectedDistribution;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDistributions();
  }

  Future<void> _loadDistributions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cloudFrontService = context.read<AppState>().cloudFrontService;
      final dists = await cloudFrontService.listDistributions();
      if (!mounted) return;
      setState(() {
        _distributions = dists;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _distributions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _distributions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Failed to load distributions: $_error', 
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDistributions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Toolbar for the view
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Text(
                'Distributions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadDistributions,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Top section: Data Table
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Domain Name')),
                    DataColumn(label: Text('Comment')),
                    DataColumn(label: Text('Origin')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('State')),
                    DataColumn(label: Text('Last Modified')),
                  ],
                  rows: _distributions.map((dist) {
                    final isSelected = _selectedDistribution?.id == dist.id;
                    final origin = (dist.origins.items.isNotEmpty) 
                        ? dist.origins.items.first.domainName 
                        : '-';
                    return DataRow(
                      selected: isSelected,
                      onSelectChanged: (selected) {
                        if (selected == true) {
                          setState(() {
                            _selectedDistribution = dist;
                          });
                        }
                      },
                      cells: [
                        DataCell(Text(dist.id)),
                        DataCell(Text(dist.domainName)),
                        DataCell(Text(dist.comment)),
                        DataCell(Text(origin)),
                        DataCell(Text(dist.status)),
                        DataCell(Text(dist.enabled ? 'Enabled' : 'Disabled')),
                        DataCell(Text(dist.lastModifiedTime.toString())),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        
        // Bottom section: Details Pane
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.grey.shade50,
            child: _buildDetailsPane(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsPane() {
    if (_selectedDistribution == null) {
      return const Center(
        child: Text('Select a distribution to view its properties.', style: TextStyle(color: Colors.grey)),
      );
    }

    final dist = _selectedDistribution!;
    final origin = (dist.origins.items.isNotEmpty) ? dist.origins.items.first.domainName : '-';
    final aliases = (dist.aliases?.items != null && dist.aliases!.items!.isNotEmpty) 
        ? dist.aliases!.items!.join(', ') 
        : '-';
    final defaultRootObject = '-'; // Not available in DistributionSummary
    final loggingText = 'Disabled'; 
    final allowedConnections = dist.defaultCacheBehavior.viewerProtocolPolicy.toValue();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribution Properties:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildPropertyRow('Distribution ID:', dist.id),
                        _buildPropertyRow('Distribution Status:', dist.enabled ? 'Enabled' : 'Disabled'),
                        _buildDomainNameRow(dist.domainName),
                        _buildPropertyRow('State:', dist.status),
                        _buildPropertyRow('Last Modified:', dist.lastModifiedTime.toString()),
                        _buildPropertyRow('Origin:', origin),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _buildPropertyRow('Allowed Connections:', allowedConnections),
                        _buildPropertyRow('CNAMEs:', aliases),
                        _buildPropertyRow('Default Root Object:', defaultRootObject),
                        _buildPropertyRow('Logging:', loggingText),
                        _buildPropertyRow('Comment:', dist.comment),
                        _buildPropertyRow('InProgress Invalidation Batches:', 'N/A'),
                        _buildPropertyRow('Min TTL:', '${dist.defaultCacheBehavior.minTTL ?? 0} second(s)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainNameRow(String domainName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 140,
            child: Text(
              'Domain Name:',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(domainName),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: domainName));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied $domainName to clipboard')),
                    );
                  },
                  child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
