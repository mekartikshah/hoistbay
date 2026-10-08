import 'package:flutter/material.dart';
import '../models/aws_profile.dart';
import '../models/aws_credentials.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/app_input.dart';

class ProfileEditorScreen extends StatefulWidget {
  final AwsProfile? profile;

  const ProfileEditorScreen({super.key, this.profile});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _sessionTokenController = TextEditingController();

  String _selectedRegion = 'us-east-1';
  bool _obscureSecretKey = true;
  bool _obscureSessionToken = true;
  bool _isLoading = false;

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
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _nameController.text = widget.profile!.name;
      _accessKeyController.text = widget.profile!.credentials.accessKeyId;
      _secretKeyController.text = widget.profile!.credentials.secretAccessKey;
      _selectedRegion = widget.profile!.credentials.region;
      _sessionTokenController.text = widget.profile!.credentials.sessionToken ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _sessionTokenController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credentials = AwsCredentials(
        accessKeyId: _accessKeyController.text.trim(),
        secretAccessKey: _secretKeyController.text.trim(),
        region: _selectedRegion,
        sessionToken: _sessionTokenController.text.trim().isEmpty
            ? null
            : _sessionTokenController.text.trim(),
      );

      final profile = widget.profile?.copyWith(
        name: _nameController.text.trim(),
        credentials: credentials,
      ) ?? ProfileService.createProfile(
        name: _nameController.text.trim(),
        credentials: credentials,
      );

      await ProfileService.saveProfile(profile);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile "${profile.name}" saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: Text(widget.profile == null ? 'Add New Profile' : 'Edit Profile'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: AppButton(
              label: 'Save',
              variant: AppButtonVariant.primary,
              isLoading: _isLoading,
              onPressed: _saveProfile,
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left panel with info
          Container(
            width: 280,
            color: AppColors.sidebarBackground,
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Information',
                  style: AppTypography.headline,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Create a profile to save your AWS credentials for easy access. Your credentials are stored securely on your device.',
                  style: AppTypography.body.copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: AppColors.info, size: 20),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'You can create multiple profiles for different AWS accounts',
                          style: AppTypography.caption.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main form
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.profile == null ? 'New AWS Profile' : 'Edit AWS Profile',
                              style: AppTypography.title,
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            AppInput(
                              controller: _nameController,
                              label: 'Profile Name',
                              prefixIcon: Icons.person,
                              hint: 'e.g., Production, Development',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a profile name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
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
                                prefixIcon: const Icon(Icons.public, color: AppColors.textSecondary),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                AppButton(
                                  label: 'Cancel',
                                  variant: AppButtonVariant.text,
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                AppButton(
                                  label: widget.profile == null ? 'Create Profile' : 'Save Changes',
                                  variant: AppButtonVariant.primary,
                                  isLoading: _isLoading,
                                  onPressed: _saveProfile,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
