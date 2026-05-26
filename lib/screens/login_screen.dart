import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/aws_credentials.dart';
import '../providers/app_state.dart';

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
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('S3 Scout – Free S3 Browser'),
        centerTitle: true,
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Icon(
                      Icons.cloud,
                      size: 64,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AWS Credentials',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
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
                    ),
                    const SizedBox(height: 24),
                    Consumer<AppState>(
                      builder: (context, appState, child) {
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: appState.isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: appState.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Connect to AWS',
                                  style: TextStyle(fontSize: 16),
                                ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Consumer<AppState>(
                      builder: (context, appState, child) {
                        if (appState.error != null) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade300),
                              borderRadius: BorderRadius.circular(4),
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
                                      fontSize: 14,
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