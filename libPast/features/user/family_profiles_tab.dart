import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/models/family_profile_model.dart';
import '../../core/services/app_provider.dart';
import '../../core/services/auth_provider.dart';
import 'add_family_member_screen.dart';

class FamilyProfilesTab extends StatefulWidget {
  const FamilyProfilesTab({super.key});

  @override
  State<FamilyProfilesTab> createState() => _FamilyProfilesTabState();
}

class _FamilyProfilesTabState extends State<FamilyProfilesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final app = Provider.of<AppProvider>(context, listen: false);
      if (auth.currentUser != null) {
        app.listenUserSessions(auth.currentUser!.uid, auth.currentUser!.role);
      }
    });
  }

  int _calculateAge(String dobStr) {
    try {
      if (dobStr.contains('-')) {
        final parts = dobStr.split('-');
        if (parts.length == 3) {
          int day, month, year;
          if (parts[0].length == 4) {
            // YYYY-MM-DD
            year = int.parse(parts[0]);
            month = int.parse(parts[1]);
            day = int.parse(parts[2]);
          } else {
            // DD-MM-YYYY
            day = int.parse(parts[0]);
            month = int.parse(parts[1]);
            year = int.parse(parts[2]);
          }
          final birthDate = DateTime(year, month, day);
          final today = DateTime.now();
          int age = today.year - birthDate.year;
          if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
            age--;
          }
          return age;
        }
      }
    } catch (e) {
      debugPrint('Error parsing DOB for dynamic age: $e');
    }
    return 0;
  }

  Widget _buildGenderIcon(String gender) {
    IconData iconData;
    Color color;
    if (gender.toLowerCase() == 'male') {
      iconData = Icons.male;
      color = Colors.blue;
    } else if (gender.toLowerCase() == 'female') {
      iconData = Icons.female;
      color = Colors.pink;
    } else {
      iconData = Icons.transgender;
      color = Colors.black;
    }
    return Icon(iconData, color: color, size: 18);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final app = Provider.of<AppProvider>(context);

    if (auth.currentUser == null) return const SizedBox.shrink();
    final userId = auth.currentUser!.uid;

    return Scaffold(
      body: app.familyMembers.isEmpty
          ? const Center(
              child: Text(
                'No family profiles added yet.\nAdd family profiles for personalized puja sankalpams.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DivineTheme.textLight, height: 1.5),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: app.familyMembers.length,
              itemBuilder: (context, index) {
                final m = app.familyMembers[index];
                return Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(m.profilePhoto),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DivineTheme.maroon)),
                                  const SizedBox(width: 6),
                                  _buildGenderIcon(m.gender),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Relationship: ${m.relationship} • Age: ${_calculateAge(m.dob)}', style: const TextStyle(fontSize: 13, color: DivineTheme.textLight)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: DivineTheme.saffron),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Rasi: ${m.rasi} | Nakshatra: ${m.nakshatra}',
                                      style: const TextStyle(fontSize: 12, color: DivineTheme.textDark),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.bookmark_border, size: 14, color: DivineTheme.maroon),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Gothram: ${m.gothram} | Lagnam: ${m.lagnam}',
                                      style: const TextStyle(fontSize: 12, color: DivineTheme.textLight),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DivineTheme.maroon,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddFamilyMemberScreen()),
          );
        },
      ),
    );
  }
}
