import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              if (appState.breadcrumbs.length > 1)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    appState.navigateUp();
                  },
                  tooltip: 'Go back',
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < appState.breadcrumbs.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        InkWell(
                          onTap: i < appState.breadcrumbs.length - 1
                              ? () => appState.navigateToBreadcrumb(i)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: i == appState.breadcrumbs.length - 1
                                  ? Colors.orange.shade100
                                  : null,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  i == 0 ? Icons.folder : Icons.folder_open,
                                  size: 16,
                                  color: i == appState.breadcrumbs.length - 1
                                      ? Colors.orange.shade700
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  appState.breadcrumbs[i],
                                  style: TextStyle(
                                    color: i == appState.breadcrumbs.length - 1
                                        ? Colors.orange.shade700
                                        : Colors.blue.shade700,
                                    fontWeight: i == appState.breadcrumbs.length - 1
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}