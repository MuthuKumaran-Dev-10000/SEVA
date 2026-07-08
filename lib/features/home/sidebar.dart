import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final _profileFormKey = GlobalKey<FormState>();
  final _familyFormKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _dobController;
  late TextEditingController _starController;
  late TextEditingController _rasiController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationLinkController;
  late String _gender;

  // Family Member form controllers
  final _famNameController = TextEditingController();
  final _famDobController = TextEditingController();
  final _famStarController = TextEditingController();
  final _famRasiController = TextEditingController();
  final _famEmailController = TextEditingController();
  final _famMobileController = TextEditingController();
  String _famGender = 'Male';

  bool _isEditingProfile = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    
    _nameController = TextEditingController(text: user?['full_name'] ?? '');
    _mobileController = TextEditingController(text: user?['mobile'] ?? '');
    _addressController = TextEditingController(text: user?['address'] ?? '');
    _dobController = TextEditingController(text: user?['dob'] ?? '');
    _starController = TextEditingController(text: user?['star'] ?? '');
    _rasiController = TextEditingController(text: user?['rasi'] ?? '');
    _descriptionController = TextEditingController(text: user?['description'] ?? '');
    _locationLinkController = TextEditingController(text: user?['location_link'] ?? '');
    _gender = user?['gender'] ?? 'Male';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _starController.dispose();
    _rasiController.dispose();
    _descriptionController.dispose();
    _locationLinkController.dispose();
    
    _famNameController.dispose();
    _famDobController.dispose();
    _famStarController.dispose();
    _famRasiController.dispose();
    _famEmailController.dispose();
    _famMobileController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 400,
      );
      if (image != null) {
        final success = await auth.uploadAvatar(image.path);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showAddFamilyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add Family Member',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _familyFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _famNameController,
                        decoration: const InputDecoration(labelText: 'Name *'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _famDobController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth *',
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setDialogState(() {
                              _famDobController.text = DateFormat('yyyy-MM-dd').format(date);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _famGender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: ['Male', 'Female', 'Other']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              _famGender = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _famStarController,
                        decoration: const InputDecoration(labelText: 'Star / Nakshatram *'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _famRasiController,
                        decoration: const InputDecoration(labelText: 'Rasi *'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _famEmailController,
                        decoration: const InputDecoration(labelText: 'Email Address (Optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _famMobileController,
                        decoration: const InputDecoration(labelText: 'Mobile Number (Optional)'),
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _clearFamilyControllers();
                    Navigator.pop(context);
                  },
                  child: Text('Cancel', style: GoogleFonts.outfit(color: SevaTheme.textMuted)),
                ),
                TextButton(
                  onPressed: () async {
                    if (_familyFormKey.currentState?.validate() ?? false) {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final success = await auth.addFamilyMember(
                        name: _famNameController.text.trim(),
                        dob: _famDobController.text,
                        star: _famStarController.text.trim(),
                        gender: _famGender,
                        rasi: _famRasiController.text.trim(),
                        email: _famEmailController.text.trim(),
                        mobile: _famMobileController.text.trim(),
                      );
                      if (success) {
                        setDialogState(() {
                          _clearFamilyControllers();
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Family member added! You can add another.')),
                          );
                        }
                      }
                    }
                  },
                  child: Text('Add & Add Another', style: GoogleFonts.outfit(color: SevaTheme.secondaryGold, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_familyFormKey.currentState?.validate() ?? false) {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final success = await auth.addFamilyMember(
                        name: _famNameController.text.trim(),
                        dob: _famDobController.text,
                        star: _famStarController.text.trim(),
                        gender: _famGender,
                        rasi: _famRasiController.text.trim(),
                        email: _famEmailController.text.trim(),
                        mobile: _famMobileController.text.trim(),
                      );
                      if (success && context.mounted) {
                        _clearFamilyControllers();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Family member added successfully.')),
                        );
                      }
                    }
                  },
                  child: const Text('Add & Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearFamilyControllers() {
    _famNameController.clear();
    _famDobController.clear();
    _famStarController.clear();
    _famRasiController.clear();
    _famEmailController.clear();
    _famMobileController.clear();
    _famGender = 'Male';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final client = Provider.of<ApiClient>(context);
    final user = auth.currentUser;

    if (user == null) {
      return const Drawer(child: Center(child: Text("Please login to configure profile")));
    }

    final role = user['role'];

    return Drawer(
      backgroundColor: SevaTheme.backgroundIvory,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: SevaTheme.primaryMaroon),
            currentAccountPicture: Stack(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: SevaTheme.secondaryGold,
                  backgroundImage: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                      ? (user['avatar_url'].toString().startsWith('http')
                          ? NetworkImage(user['avatar_url'])
                          : NetworkImage('${client.baseUrl}${user['avatar_url']}'))
                      : null,
                  child: user['avatar_url'] == null || user['avatar_url'].toString().isEmpty
                      ? Text(
                          user['full_name'][0].toUpperCase(),
                          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: SevaTheme.secondaryGold,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      onPressed: _pickAvatar,
                    ),
                  ),
                ),
              ],
            ),
            accountName: Text(
              user['full_name'],
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            accountEmail: Text(
              user['email'],
              style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8)),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile Settings',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: SevaTheme.primaryMaroon),
                    ),
                    IconButton(
                      icon: Icon(
                        _isEditingProfile ? Icons.save : Icons.edit,
                        color: SevaTheme.secondaryGold,
                      ),
                      onPressed: () async {
                        if (_isEditingProfile) {
                          if (_profileFormKey.currentState?.validate() ?? false) {
                            final success = await auth.updateProfile(
                              fullName: _nameController.text.trim(),
                              mobile: _mobileController.text.trim(),
                              address: _addressController.text.trim(),
                              dob: role != 'temple' ? _dobController.text : null,
                              star: role == 'devotee' ? _starController.text.trim() : null,
                              rasi: role == 'devotee' ? _rasiController.text.trim() : null,
                              gender: role != 'temple' ? _gender : null,
                              description: role == 'temple' ? _descriptionController.text.trim() : null,
                              locationLink: role == 'temple' ? _locationLinkController.text.trim() : null,
                            );
                            if (success) {
                              setState(() => _isEditingProfile = false);
                            }
                          }
                        } else {
                          setState(() => _isEditingProfile = true);
                        }
                      },
                    ),
                  ],
                ),
                Form(
                  key: _profileFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        enabled: _isEditingProfile,
                        decoration: InputDecoration(
                          labelText: role == 'temple' ? 'Temple Name' : 'Full Name',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Cannot be empty' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mobileController,
                        enabled: _isEditingProfile,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Cannot be empty' : null,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        enabled: _isEditingProfile,
                        decoration: InputDecoration(
                          labelText: role == 'temple' ? 'Temple Address' : 'Physical Address',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Cannot be empty' : null,
                      ),
                      
                      // Devotee / Priest edit fields (Dob, Gender)
                      if (role != 'temple') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _dobController,
                          enabled: _isEditingProfile,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                          ),
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
                            prefixIcon: Icon(Icons.wc, size: 20),
                          ),
                          items: _isEditingProfile 
                              ? ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList()
                              : [DropdownMenuItem(value: _gender, child: Text(_gender))],
                          onChanged: _isEditingProfile ? (val) {
                            if (val != null) {
                              setState(() {
                                _gender = val;
                              });
                            }
                          } : null,
                        ),
                      ],

                      // Devotee Star & Rasi
                      if (role == 'devotee') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _starController,
                          enabled: _isEditingProfile,
                          decoration: const InputDecoration(
                            labelText: 'Star / Nakshatram',
                            prefixIcon: Icon(Icons.star_outline, size: 20),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Cannot be empty' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _rasiController,
                          enabled: _isEditingProfile,
                          decoration: const InputDecoration(
                            labelText: 'Rasi',
                            prefixIcon: Icon(Icons.brightness_5_outlined, size: 20),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Cannot be empty' : null,
                        ),
                      ],

                      // Temple description & location link
                      if (role == 'temple') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: _isEditingProfile,
                          decoration: const InputDecoration(
                            labelText: 'Temple Description',
                            prefixIcon: Icon(Icons.description_outlined, size: 20),
                          ),
                          maxLines: 2,
                          validator: (value) => value == null || value.trim().isEmpty ? 'Cannot be empty' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _locationLinkController,
                          enabled: _isEditingProfile,
                          decoration: const InputDecoration(
                            labelText: 'Google Maps Link',
                            prefixIcon: Icon(Icons.map_outlined, size: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Devotee family members roster
                if (role == 'devotee') ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Family Members',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: SevaTheme.primaryMaroon),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: SevaTheme.secondaryGold),
                        onPressed: _showAddFamilyDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  auth.familyMembers.isEmpty
                      ? Center(
                          child: Text(
                            'No family members added.',
                            style: GoogleFonts.outfit(color: SevaTheme.textMuted, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: auth.familyMembers.length,
                          itemBuilder: (context, index) {
                            final member = auth.familyMembers[index];
                            final isPrimary = index == 0;
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                dense: true,
                                title: Row(
                                  children: [
                                    Text(
                                      member['name'],
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    if (isPrimary)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: SevaTheme.primaryMaroon.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Primary',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: SevaTheme.primaryMaroon,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  'Star: ${member['star']} | Rasi: ${member['rasi']} | Dob: ${member['dob']}',
                                  style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.textMuted),
                                ),
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: SevaTheme.primaryMaroon.withOpacity(0.1),
                                  child: Text(
                                    member['gender'] == 'Male' ? 'M' : 'F',
                                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
