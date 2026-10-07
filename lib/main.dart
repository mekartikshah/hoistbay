import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/profile_selection_screen.dart';
import 'screens/browser_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const AwsS3BrowserApp());
}

class AwsS3BrowserApp extends StatelessWidget {
  const AwsS3BrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(
        title: 'S3 Scout – Free S3 Browser',
        theme: AppTheme.lightTheme,
        home: const AppWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize the app state on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Show appropriate screen based on authentication status
        return appState.isAuthenticated 
            ? const BrowserScreen()
            : const ProfileSelectionScreen();
      },
    );
  }
}