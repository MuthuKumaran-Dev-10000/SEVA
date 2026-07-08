import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/models/user_model.dart';
import '../temple/temple_dashboard.dart';
import '../priest/priest_dashboard.dart';
import '../user/user_home.dart';
import '../../widgets/offline_banner.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _answerController = TextEditingController();
  
  Uint8List? _profilePicBytes;
  String? _profilePicUrl;
  
  UserRole _selectedRole = UserRole.user; // Devotee by default

  final List<String> _securityQuestions = [
    'What is your pet name?',
    'What is your birth city?',
    'What is your mother\'s maiden name?',
    'What was your first car?',
  ];
  late String _selectedQuestion;

  @override
  void initState() {
    super.initState();
    _selectedQuestion = _securityQuestions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      role: _selectedRole,
      securityQuestion: _selectedQuestion,
      securityAnswer: _answerController.text.trim(),
      profilePic: _profilePicUrl ?? '',
    );

    if (success && mounted) {
      if (_selectedRole == UserRole.temple) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TempleDashboard()),
          (route) => false,
        );
      } else if (_selectedRole == UserRole.priest) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PriestDashboard()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const UserHome()),
          (route) => false,
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Registration failed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: DivineTheme.maroon,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Start Your Spiritual Journey',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create an account to book and manage divine services.',
                        style: TextStyle(color: DivineTheme.textLight, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _buildAvatarPicker(),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person, color: DivineTheme.maroon),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone, color: DivineTheme.maroon),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.length < 10 ? 'Enter a valid phone number' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email, color: DivineTheme.maroon),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Enter a valid email';
                          if (!value.endsWith('@gmail.com')) return 'Use a Gmail address';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock, color: DivineTheme.maroon),
                        ),
                        obscureText: true,
                        validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Security Question Dropdown
                      const Text(
                        'Security Question (For Password Reset):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DivineTheme.maroon,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedQuestion,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(),
                        ),
                        items: _securityQuestions.map((q) {
                          return DropdownMenuItem<String>(
                            value: q,
                            child: Text(q, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedQuestion = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _answerController,
                        decoration: const InputDecoration(
                          labelText: 'Security Answer',
                          prefixIcon: Icon(Icons.security, color: DivineTheme.maroon),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Enter your answer' : null,
                      ),
                      const SizedBox(height: 24),

                      // Role selection
                      const Text(
                        'Register As:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DivineTheme.maroon,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Devotee (User)'),
                            selected: _selectedRole == UserRole.user,
                            selectedColor: DivineTheme.saffron.withOpacity(0.2),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedRole = UserRole.user);
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Temple Admin'),
                            selected: _selectedRole == UserRole.temple,
                            selectedColor: DivineTheme.maroon.withOpacity(0.15),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedRole = UserRole.temple);
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Priest'),
                            selected: _selectedRole == UserRole.priest,
                            selectedColor: DivineTheme.gold.withOpacity(0.2),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedRole = UserRole.priest);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return auth.isLoading
                              ? const Center(child: CircularProgressIndicator(color: DivineTheme.maroon))
                              : ElevatedButton(
                                  onPressed: _signup,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 4,
                                    shadowColor: DivineTheme.saffron.withOpacity(0.4),
                                  ),
                                  child: const Text('CREATE ACCOUNT'),
                                );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DivineTheme.creamDark,
              border: Border.all(color: DivineTheme.gold, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: _profilePicBytes != null
                  ? Image.memory(_profilePicBytes!, fit: BoxFit.cover)
                  : (_profilePicUrl != null && _profilePicUrl!.isNotEmpty)
                      ? Image.network(
                          _profilePicUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 60,
                            color: DivineTheme.maroon,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 60,
                          color: DivineTheme.maroon,
                        ),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: InkWell(
              onTap: _showAvatarPickerSheet,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: DivineTheme.saffron,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvatarPickerSheet() {
    final List<Map<String, String>> presets = [
      {
        "name": "Devotee (M)",
        "url": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150"
      },
      {
        "name": "Devotee (F)",
        "url": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=150"
      },
      {
        "name": "Priest",
        "url": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=150"
      },
      {
        "name": "Temple",
        "url": "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=200"
      },
      {
        "name": "Ganesha",
        "url": "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=200"
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: DivineTheme.maroon,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: DivineTheme.saffron,
                    child: Icon(Icons.photo_library, color: Colors.white),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickCustomImage();
                  },
                ),
                const Divider(),
                const Text(
                  'Or Choose Preset Avatar:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: DivineTheme.textLight,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: presets.length,
                    itemBuilder: (context, index) {
                      final item = presets[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _profilePicBytes = null;
                              _profilePicUrl = item["url"];
                            });
                            Navigator.of(context).pop();
                          },
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundImage: NetworkImage(item["url"]!),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item["name"]!,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_profilePicUrl != null || _profilePicBytes != null) ...[
                  const Divider(),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    title: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      setState(() {
                        _profilePicBytes = null;
                        _profilePicUrl = null;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCustomImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading image...'), duration: Duration(seconds: 2)),
          );
        }
        
        final bytes = await image.readAsBytes();
        
        setState(() {
          _profilePicBytes = bytes;
        });

        final url = await CloudinaryService.uploadImageBytes(bytes, image.name);
        
        setState(() {
          _profilePicUrl = url;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
