import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../providers/app_state.dart';
import '../widgets/bucket_list.dart';
import '../widgets/object_list.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/unified_action_bar.dart';
import '../widgets/default_headers_dialog.dart';
import '../widgets/upload_button.dart';
import 'cloudfront_manager_screen.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadBuckets();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.isLoading && appState.buckets.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading AWS S3 buckets...'),
                ],
              ),
            );
          }

          return Row(
            children: [
              // Left panel - Sidebar (Buckets & Profile)
              Container(
                width: 300,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50, // Distinct sidebar color
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSidebarHeader(context, appState),
                    const Expanded(child: BucketList()),
                  ],
                ),
              ),
              // Right panel - Tabbed interface
              Expanded(
                child: Column(
                  children: [
                    // Tab Bar for switching between S3 and CloudFront
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.blue.shade700,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorColor: Colors.blue.shade700,
                        tabs: const [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storage_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('S3 Scout'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.language_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('CloudFront Manager'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(), // Disable swiping to avoid conflicts
                        children: [
                          // Tab 1: S3 Browser
                          Column(
                            children: [
                              if (appState.selectedBucket != null) ...[
                                const BreadcrumbBar(),
                                const UnifiedActionBar(),
                              ],
                              Expanded(
                                child: appState.selectedBucket == null
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.folder_outlined,
                                              size: 64,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'Select a bucket to view its contents',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
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
                                          final paths = detail.files
                                              .map((f) => f.path)
                                              .toList();
                                          if (paths.isNotEmpty) {
                                            await UploadButton.uploadPaths(context, paths);
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: _isDragging
                                                ? Border.all(color: Colors.blue, width: 2)
                                                : null,
                                            color: _isDragging ? Colors.blue.shade50 : null,
                                          ),
                                          child: const ObjectList(),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          // Tab 2: CloudFront Manager
                          const CloudFrontManagerView(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context, AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          if (appState.currentProfile != null)
            PopupMenuButton<String>(
              tooltip: 'Menu',
              icon: Icon(Icons.menu, color: Colors.grey.shade700, size: 24),
              onSelected: (value) {
                switch (value) {
                  case 'switch_profile':
                    context.read<AppState>().logout();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    break;
                  case 'manage_profiles':
                    context.read<AppState>().logout();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    break;
                  case 'cloudfront_manager':
                    _tabController.animateTo(1); // Switch to CloudFront tab
                    break;
                  case 'default_headers':
                    showDialog(
                      context: context,
                      builder: (context) => const DefaultHeadersDialog(),
                    );
                    break;
                  case 'about':
                    _showAboutDialog(context);
                    break;
                  case 'logout':
                    context.read<AppState>().logout();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    appState.currentProfile!.name,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'switch_profile',
                  child: Text('Switch Profile'),
                ),
                const PopupMenuItem<String>(
                  value: 'manage_profiles',
                  child: Text('Manage Profiles'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'cloudfront_manager',
                  child: Text('CloudFront Manager'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'default_headers',
                  child: Text('Default HTTP Headers'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'about',
                  child: Text('About'),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Logout'),
                ),
              ],
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.cloud_outlined,
            color: Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'S3 Scout',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_outlined, color: Colors.blue.shade700, size: 32),
            const SizedBox(width: 12),
            const Text('S3 Scout – Free S3 Browser'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Version 1.0.0',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Text(
                'A beautiful, modern desktop application for browsing and managing your S3 buckets.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              const Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildFeature('🔐 Secure multi-profile management'),
              _buildFeature('📁 Browse buckets and objects'),
              _buildFeature('⬆️ Upload and download files'),
              _buildFeature('🌐 Support for all AWS regions'),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Enjoying S3 Scout?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final url = Uri.parse('https://www.buymeacoffee.com/yourusername');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Text('☕', style: TextStyle(fontSize: 18)),
                      label: const Text('Buy Me a Coffee'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final url = Uri.parse('https://github.com/yourusername/aws_s3_browser');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('View on GitHub'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final url = Uri.parse('https://github.com/yourusername/aws_s3_browser/issues');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.bug_report, size: 18),
                      label: const Text('Report an Issue'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
      ),
    );
  }
}