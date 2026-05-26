import 'package:flutter/material.dart';
import '../models/aws_profile.dart';
import '../models/aws_credentials.dart';
import '../services/profile_service.dart';

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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.red,
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.profile == null ? 'Add New Profile' : 'Edit Profile'),
        backgroundColor: Colors.grey.shade50,
        foregroundColor: Colors.grey.shade800,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left panel with info
          Container(
            width: 280,
            color: Colors.grey.shade50,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create a profile to save your AWS credentials for easy access. Your credentials are stored securely on your device.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can create multiple profiles for different AWS accounts',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
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
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.profile == null ? 'New AWS Profile' : 'Edit AWS Profile',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Profile Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person),
                                  hintText: 'e.g., Production, Development',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a profile name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _accessKeyController,
                                decoration: const InputDecoration(
                                  labelText: 'Access Key ID',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.key),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your access key ID';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _secretKeyController,
                                decoration: InputDecoration(
                                  labelText: 'Secret Access Key',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.security),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureSecretKey ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureSecretKey = !_obscureSecretKey;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscureSecretKey,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your secret access key';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _selectedRegion,
                                decoration: const InputDecoration(
                                  labelText: 'Region',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.public),
                                ),
                                items: _awsRegions.map((String region) {
                                  return DropdownMenuItem<String>(
                                    value: region,
                                    child: Text(region),
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
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _sessionTokenController,
                                decoration: InputDecoration(
                                  labelText: 'Session Token (Optional)',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.token),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureSessionToken ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureSessionToken = !_obscureSessionToken;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscureSessionToken,
                                maxLines: _obscureSessionToken ? 1 : 3,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                    child: _isLoading
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(widget.profile == null ? 'Create Profile' : 'Save Changes'),
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
          ),
        ],
      ),
    );
  }
}