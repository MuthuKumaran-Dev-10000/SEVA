import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme.dart';

class LoginSignupSheet extends StatefulWidget {
  const LoginSignupSheet({super.key});

  @override
  State<LoginSignupSheet> createState() => _LoginSignupSheetState();
}

class _LoginSignupSheetState extends State<LoginSignupSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  String _selectedRole = 'devotee'; // 'devotee', 'priest', 'temple'
  String? _avatarPath;

  // General controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 400,
      );
      if (image != null) {
        setState(() {
          _avatarPath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  // Role-specific controllers
  final _dobController = TextEditingController();
  final _starController = TextEditingController();
  final _rasiController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationLinkController = TextEditingController();
  String _gender = 'Male';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _dobController.dispose();
    _starController.dispose();
    _rasiController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _locationLinkController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      bool success = false;

      if (_isLogin) {
        success = await auth.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        success = await auth.signup(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          role: _selectedRole,
          dob: _selectedRole != 'temple' ? _dobController.text : null,
          star: _selectedRole == 'devotee' ? _starController.text.trim() : null,
          rasi: _selectedRole == 'devotee' ? _rasiController.text.trim() : null,
          gender: _selectedRole != 'temple' ? _gender : null,
          address: _addressController.text.trim(),
          description: _selectedRole == 'temple' ? _descriptionController.text.trim() : null,
          locationLink: _selectedRole == 'temple' ? _locationLinkController.text.trim() : null,
        );
        
        if (success && _avatarPath != null) {
          await auth.uploadAvatar(_avatarPath!);
        }
      }

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLogin ? 'Logged in successfully!' : 'Account registered successfully!'),
            backgroundColor: SevaTheme.primaryMaroon,
          ),
        );
      }
    }
  }

  Widget _buildRoleSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: SevaTheme.surfaceStone,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildRoleTab('devotee', 'Devotee', Icons.person_outline),
          _buildRoleTab('priest', 'Priest', Icons.self_improvement),
          _buildRoleTab('temple', 'Temple', Icons.temple_hindu_outlined),
        ],
      ),
    );
  }

  Widget _buildRoleTab(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRole = role;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? SevaTheme.primaryMaroon : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : SevaTheme.textMuted, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : SevaTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: SevaTheme.backgroundIvory,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: SevaTheme.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _isLogin ? 'Welcome Back' : 'Create Account',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: SevaTheme.primaryMaroon,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              if (auth.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Text(
                    auth.errorMessage!,
                    style: GoogleFonts.outfit(color: Colors.red[950], fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (!_isLogin) ...[
                _buildRoleSelector(),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: SevaTheme.secondaryGold.withOpacity(0.15),
                        backgroundImage: _avatarPath != null
                            ? (kIsWeb ? NetworkImage(_avatarPath!) : FileImage(File(_avatarPath!)) as ImageProvider)
                            : null,
                        child: _avatarPath == null
                            ? const Icon(Icons.add_a_photo, size: 28, color: SevaTheme.primaryMaroon)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: _avatarPath != null ? Colors.redAccent : SevaTheme.secondaryGold,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(_avatarPath != null ? Icons.delete : Icons.edit, size: 14, color: Colors.white),
                            onPressed: _avatarPath != null
                                ? () => setState(() => _avatarPath = null)
                                : _pickAvatar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Common Fields: Email & Password for both Login and Signup
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: _isLogin ? 'Email or Phone Number *' : 'Email Address *',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _isLogin ? 'Please enter email or phone number' : 'Please enter email';
                  }
                  if (_isLogin) {
                    if (value.contains('@')) {
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                    } else {
                      // Check phone number format (at least 7 digits)
                      final digits = value.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 7) {
                        return 'Please enter a valid phone number';
                      }
                    }
                  } else {
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) => value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
              ),
              
              if (!_isLogin) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: _selectedRole == 'temple' ? 'Temple Name *' : 'Full Name *',
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Mobile *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: _selectedRole == 'temple' ? 'Temple Address *' : 'Physical Address *',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),

                // Devotee and Priest fields (DOB, Gender)
                if (_selectedRole != 'temple') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth *',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _dobController.text = DateFormat('yyyy-MM-dd').format(date);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: ['Male', 'Female', 'Other']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _gender = val;
                        });
                      }
                    },
                  ),
                ],

                // Devotee Only Fields (Star, Rasi)
                if (_selectedRole == 'devotee') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _starController,
                    decoration: const InputDecoration(
                      labelText: 'Star / Nakshatram *',
                      prefixIcon: Icon(Icons.star_outline),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rasiController,
                    decoration: const InputDecoration(
                      labelText: 'Rasi *',
                      prefixIcon: Icon(Icons.brightness_5_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                ],

                // Temple Only Fields (Description, Location Link)
                if (_selectedRole == 'temple') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Temple Description *',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    maxLines: 2,
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationLinkController,
                    decoration: const InputDecoration(
                      labelText: 'Google Maps Link (Optional)',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(_isLogin ? 'Login' : 'Sign Up'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  auth.clearError();
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin ? "Don't have an account? Sign Up" : "Already have an account? Log In",
                  style: GoogleFonts.outfit(
                    color: SevaTheme.secondaryGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
