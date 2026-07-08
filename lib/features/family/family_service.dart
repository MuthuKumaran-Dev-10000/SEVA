import 'package:firebase_database/firebase_database.dart';

class FamilyService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Future<List<Map<String, dynamic>>> getFamily(int userId) async {
    try {
      final snapshot = await _dbRef.child('Seva-v1/family_members').get();
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final List<Map<String, dynamic>> members = [];
      final data = snapshot.value;

      if (data is Map) {
        data.forEach((key, val) {
          if (val is Map) {
            final member = Map<String, dynamic>.from(val);
            if (member['user_id'] == userId) {
              members.add(member);
            }
          }
        });
      } else if (data is List) {
        for (var i = 0; i < data.length; i++) {
          final val = data[i];
          if (val is Map) {
            final member = Map<String, dynamic>.from(val);
            if (member['user_id'] == userId) {
              members.add(member);
            }
          }
        }
      }

      return members;
    } catch (e) {
      throw Exception('Failed to get family members: $e');
    }
  }

  Future<Map<String, dynamic>> addFamilyMember(int userId, Map<String, dynamic> memberData) async {
    try {
      final mId = DateTime.now().millisecondsSinceEpoch;
      final newMember = {
        'id': mId,
        'user_id': userId,
        'name': memberData['name'],
        'dob': memberData['dob'],
        'star': memberData['star'],
        'gender': memberData['gender'],
        'rasi': memberData['rasi'],
        'email': memberData['email'] ?? '',
        'mobile_no': memberData['mobile_no'] ?? '',
      };

      await _dbRef.child('Seva-v1/family_members/$mId').set(newMember);
      return newMember;
    } catch (e) {
      throw Exception('Failed to add family member: $e');
    }
  }

  Future<void> updateFamilyMemberDetails(int userId, String oldName, Map<String, dynamic> updateData) async {
    try {
      final snapshot = await _dbRef.child('Seva-v1/family_members').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final data = snapshot.value;
      if (data is Map) {
        for (final entry in data.entries) {
          final key = entry.key;
          final val = entry.value;
          if (val is Map && val['user_id'] == userId && val['name'] == oldName) {
            await _dbRef.child('Seva-v1/family_members/$key').update(Map<String, dynamic>.from(updateData));
            break;
          }
        }
      } else if (data is List) {
        for (var i = 0; i < data.length; i++) {
          final val = data[i];
          if (val is Map && val['user_id'] == userId && val['name'] == oldName) {
            await _dbRef.child('Seva-v1/family_members/$i').update(Map<String, dynamic>.from(updateData));
            break;
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to update family member: $e');
    }
  }
}
