import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/app_provider.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/models/family_profile_model.dart';
import '../../widgets/offline_banner.dart';

class AddFamilyMemberScreen extends StatefulWidget {
  const AddFamilyMemberScreen({super.key});

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _rasiController = TextEditingController();
  final _nakshatraController = TextEditingController();
  final _lagnamController = TextEditingController();
  final _gothramController = TextEditingController();
  
  Uint8List? _profilePicBytes;
  String? _profilePicUrl;
  
  String _selectedRelationship = 'Spouse';
  String _selectedGender = 'Male';
  bool _isSaving = false;

  final List<String> _relationships = [
    'Spouse',
    'Father',
    'Mother',
    'Son',
    'Daughter',
    'Brother',
    'Sister',
    'Grandfather',
    'Grandmother',
    'Uncle',
    'Aunt',
    'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _rasiController.dispose();
    _nakshatraController.dispose();
    _lagnamController.dispose();
    _gothramController.dispose();
    super.dispose();
  }

  int _calculateAge(String dobStr) {
    try {
      final parts = dobStr.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final birthDate = DateTime(year, month, day);
        final today = DateTime.now();
        int age = today.year - birthDate.year;
        if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
          age--;
        }
        return age;
      }
    } catch (e) {
      debugPrint('Error parsing DOB for age calculation: $e');
    }
    return 0;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: DivineTheme.maroon,
              onPrimary: Colors.white,
              onSurface: DivineTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      setState(() {
        _dobController.text = '$day-$month-$year';
      });
    }
  }

  void _saveFamilyMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final app = Provider.of<AppProvider>(context, listen: false);

    final String userId = auth.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final String dob = _dobController.text.trim();
    final int calculatedAge = _calculateAge(dob);

    final newMember = FamilyProfileModel(
      id: 'fam_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      dob: dob,
      age: calculatedAge,
      gender: _selectedGender,
      rasi: _rasiController.text.trim().isEmpty ? 'Mesha' : _rasiController.text.trim(),
      nakshatra: _nakshatraController.text.trim().isEmpty ? 'Aswini' : _nakshatraController.text.trim(),
      lagnam: _lagnamController.text.trim().isEmpty ? 'Mesha' : _lagnamController.text.trim(),
      gothram: _gothramController.text.trim().isEmpty ? 'Shiva' : _gothramController.text.trim(),
      relationship: _selectedRelationship,
      profilePhoto: _profilePicUrl ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150',
    );

    try {
      await app.addFamilyMember(userId, newMember);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Family member added successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add family member: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Family Member'),
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
                        'Add to Family Roster',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 22),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Include your family members to book pujas on their behalf.',
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
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Relationship Dropdown
                      const Text(
                        'Relationship:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.maroon, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedRelationship,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(),
                        ),
                        items: _relationships.map((r) {
                          return DropdownMenuItem<String>(
                            value: r,
                            child: Text(r, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedRelationship = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Gender ChoiceChips
                      const Text(
                        'Gender:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.maroon, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Male'),
                            selected: _selectedGender == 'Male',
                            selectedColor: Colors.blue.withOpacity(0.2),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedGender = 'Male');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Female'),
                            selected: _selectedGender == 'Female',
                            selectedColor: Colors.pink.withOpacity(0.2),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedGender = 'Female');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Transgender'),
                            selected: _selectedGender == 'Transgender',
                            selectedColor: Colors.black.withOpacity(0.15),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedGender = 'Transgender');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // DOB Picker
                      TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _selectDate,
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth (DD-MM-YYYY)',
                          prefixIcon: Icon(Icons.calendar_today, color: DivineTheme.maroon),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Select Date of Birth' : null,
                      ),
                      const SizedBox(height: 16),

                      // Astrological Fields
                      const Text(
                        'Astrological Details (Optional):',
                        style: TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.maroon, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rasiController,
                              decoration: const InputDecoration(labelText: 'Rasi'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _nakshatraController,
                              decoration: const InputDecoration(labelText: 'Star (Nakshatra)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _lagnamController,
                              decoration: const InputDecoration(labelText: 'Lagnam'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _gothramController,
                              decoration: const InputDecoration(labelText: 'Gothram'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      _isSaving
                          ? const Center(child: CircularProgressIndicator(color: DivineTheme.maroon))
                          : ElevatedButton(
                              onPressed: _saveFamilyMember,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 4,
                                shadowColor: DivineTheme.saffron.withOpacity(0.4),
                              ),
                              child: const Text('ADD FAMILY MEMBER', style: TextStyle(fontWeight: FontWeight.bold)),
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
        "name": "Member (M)",
        "url": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150"
      },
      {
        "name": "Member (F)",
        "url": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=150"
      },
      {
        "name": "Elder (M)",
        "url": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150"
      },
      {
        "name": "Elder (F)",
        "url": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=150"
      },
      {
        "name": "Child",
        "url": "https://images.unsplash.com/photo-1503919545889-aef636e10ad4?q=80&w=150"
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
