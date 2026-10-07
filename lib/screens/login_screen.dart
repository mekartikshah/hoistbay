import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/aws_credentials.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/app_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _sessionTokenController = TextEditingController();

  String _selectedRegion = 'us-east-1';
  bool _obscureSecretKey = true;
  bool _obscureSessionToken = true;

  final List<String> _awsRegions = [
    'us-east-1',
    'us-east-2',
    'us-west-1',
    'us-west-2',
    'eu-west-1',
    'eu-west-2',
    'eu-west-3',
    'eu-central-1',
    'ap-southeast-1',
    'ap-southeast-2',
    'ap-northeast-1',
    'ap-northeast-2',
    'ap-south-1',
    'sa-east-1',
    'ca-central-1',
  ];

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _sessionTokenController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final credentials = AwsCredentials(
        accessKeyId: _accessKeyController.text.trim(),
        secretAccessKey: _secretKeyController.text.trim(),
        region: _selectedRegion,
        sessionToken: _sessionTokenController.text.trim().isEmpty
            ? null
            : _sessionTokenController.text.trim(),
      );

      try {
        await context.read<AppState>().login(credentials);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.cloud_outlined,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Connect to AWS',
                        style: AppTypography.title,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Enter your AWS credentials to get started',
                        style: AppTypography.caption,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AppInput(
                        controller: _accessKeyController,
                        label: 'Access Key ID',
                        prefixIcon: Icons.key,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your access key ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppInput(
                        controller: _secretKeyController,
                        label: 'Secret Access Key',
                        prefixIcon: Icons.security,
                        obscureText: _obscureSecretKey,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureSecretKey ? Icons.visibility : Icons.visibility_off,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureSecretKey = !_obscureSecretKey;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your secret access key';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        value: _selectedRegion,
                        decoration: InputDecoration(
                          labelText: 'Region',
                          filled: true,
                          fillColor: AppColors.surfaceSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                            borderSide: const BorderSide(color: AppColors.borderLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                            borderSide: const BorderSide(color: AppColors.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                        ),
                        items: _awsRegions.map((String region) {
                          return DropdownMenuItem<String>(
                            value: region,
                            child: Text(region, style: AppTypography.body),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedRegion = newValue!;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select your AWS region';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppInput(
                        controller: _sessionTokenController,
                        label: 'Session Token (Optional)',
                        prefixIcon: Icons.token,
                        obscureText: _obscureSessionToken,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureSessionToken ? Icons.visibility : Icons.visibility_off,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureSessionToken = !_obscureSessionToken;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Consumer<AppState>(
                        builder: (context, appState, child) {
                          return SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              label: 'Connect to AWS',
                              variant: AppButtonVariant.primary,
                              isLoading: appState.isLoading,
                              onPressed: _login,
                              size: const Size(double.infinity, 44),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Consumer<AppState>(
                        builder: (context, appState, child) {
                          if (appState.error != null) {
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.errorLight,
                                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error, color: AppColors.error, size: 20),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      appState.error!,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
