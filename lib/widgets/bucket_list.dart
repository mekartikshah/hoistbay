import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class BucketList extends StatelessWidget {
  const BucketList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (appState.isLoading)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                minHeight: 2,
              ),
            if (!appState.isLoading)
              const SizedBox(height: 2), // Maintain height when not loading
            Expanded(
              child: appState.buckets.isEmpty && !appState.isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_off,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No buckets found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: appState.buckets.length,
                      itemBuilder: (context, index) {
                        final bucket = appState.buckets[index];
                        final isSelected = appState.selectedBucket?.name == bucket.name;
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange.shade100 : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.orange.shade900,
                            leading: Icon(
                              Icons.folder,
                              color: isSelected ? Colors.orange.shade700 : Colors.grey.shade600,
                              size: 20,
                            ),
                            title: Text(
                              bucket.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                                color: isSelected ? Colors.orange.shade900 : Colors.grey.shade800,
                              ),
                            ),
                            onTap: () {
                              appState.selectBucket(bucket);
                            },
                          ),
                        );
                      },
                    ),
            ),
            if (appState.error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border(
                    top: BorderSide(color: Colors.red.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appState.error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}