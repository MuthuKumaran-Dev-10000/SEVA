import 'package:firebase_database/firebase_database.dart';

class TempleService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Future<List<Map<String, dynamic>>> getTemples() async {
    try {
      final snapshot = await _dbRef.child('Seva-v1/temples').get();
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final List<Map<String, dynamic>> temples = [];
      final data = snapshot.value;

      void addTemple(dynamic val) {
        if (val is Map) {
          temples.add(Map<String, dynamic>.from(val));
        }
      }

      if (data is Map) {
        data.values.forEach(addTemple);
      } else if (data is List) {
        data.forEach(addTemple);
      }

      temples.sort((a, b) => (a['id'] ?? 0).compareTo(b['id'] ?? 0));
      return temples;
    } catch (e) {
      throw Exception('Failed to get temples: $e');
    }
  }

  Future<Map<String, dynamic>> getTempleDetails(int templeId) async {
    try {
      final tSnap = await _dbRef.child('Seva-v1/temples/$templeId').get();
      if (!tSnap.exists || tSnap.value == null) {
        throw Exception('Temple not found');
      }

      final temple = Map<String, dynamic>.from(tSnap.value as Map);
      
      // Fetch services for this temple
      final sSnap = await _dbRef.child('Seva-v1/services').get();
      final List<Map<String, dynamic>> services = [];
      if (sSnap.exists && sSnap.value != null) {
        final data = sSnap.value;
        void addService(dynamic val) {
          if (val is Map) {
            final s = Map<String, dynamic>.from(val);
            if (s['temple_id'] == templeId) {
              services.add({
                'id': s['id'],
                'temple_id': s['temple_id'],
                'name': s['name'],
                'price': s['price'] is num ? (s['price'] as num).toDouble() : 0.0,
                'description': s['description'],
                'duration': s['duration'],
              });
            }
          }
        }
        if (data is Map) {
          data.values.forEach(addService);
        } else if (data is List) {
          data.forEach(addService);
        }
      }

      temple['services'] = services;
      return temple;
    } catch (e) {
      throw Exception('Failed to get temple details: $e');
    }
  }

  Future<Map<String, dynamic>?> getTempleByUserId(int userId) async {
    try {
      final snapshot = await _dbRef.child('Seva-v1/temples').get();
      if (!snapshot.exists || snapshot.value == null) return null;

      final data = snapshot.value;
      Map<String, dynamic>? foundTemple;

      void checkTemple(dynamic val) {
        if (val is Map) {
          final t = Map<String, dynamic>.from(val);
          if (t['user_id'] == userId) {
            foundTemple = t;
          }
        }
      }

      if (data is Map) {
        data.values.forEach(checkTemple);
      } else if (data is List) {
        data.forEach(checkTemple);
      }

      return foundTemple;
    } catch (e) {
      throw Exception('Failed to get temple by user: $e');
    }
  }

  Future<Map<String, dynamic>> createTemple(Map<String, dynamic> templeData) async {
    try {
      final tId = DateTime.now().millisecondsSinceEpoch;
      final newTemple = {
        'id': tId,
        'user_id': templeData['user_id'],
        'name': templeData['name'],
        'location': templeData['location'] ?? 'Address',
        'image_url': templeData['image_url'] ?? 'https://images.unsplash.com/photo-1548013146-72479768bada?w=500',
        'description': templeData['description'] ?? 'Temple description',
        'location_link': templeData['location_link'] ?? '',
      };

      await _dbRef.child('Seva-v1/temples/$tId').set(newTemple);
      return newTemple;
    } catch (e) {
      throw Exception('Failed to create temple: $e');
    }
  }

  Future<Map<String, dynamic>> updateTemple(int templeId, Map<String, dynamic> updateData) async {
    try {
      await _dbRef.child('Seva-v1/temples/$templeId').update(updateData);
      final snapshot = await _dbRef.child('Seva-v1/temples/$templeId').get();
      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      throw Exception('Failed to update temple: $e');
    }
  }

  Future<Map<String, dynamic>> searchPriest(String email) async {
    try {
      // Find priest user
      final uSnapshot = await _dbRef.child('Seva-v1/users').get();
      if (!uSnapshot.exists || uSnapshot.value == null) {
        throw Exception('Priest not found with this email.');
      }

      Map<String, dynamic>? priestUser;
      final usersData = uSnapshot.value;

      void checkUser(dynamic val) {
        if (val is Map) {
          final u = Map<String, dynamic>.from(val);
          if (u['email'] == email.trim() && u['role'] == 'priest') {
            priestUser = u;
          }
        }
      }

      if (usersData is Map) {
        usersData.values.forEach(checkUser);
      } else if (usersData is List) {
        usersData.forEach(checkUser);
      }

      if (priestUser == null) {
        throw Exception('Priest not found with this email.');
      }

      // Fetch invitations to get associated temple names
      final iSnapshot = await _dbRef.child('Seva-v1/invitations').get();
      final List<String> associatedTemples = [];
      if (iSnapshot.exists && iSnapshot.value != null) {
        final invitesData = iSnapshot.value;
        void checkInvite(dynamic val) {
          if (val is Map) {
            final invite = Map<String, dynamic>.from(val);
            if (invite['priest_id'] == priestUser!['id'] && invite['status'] == 'accepted') {
              associatedTemples.add(invite['temple_name'] ?? 'Temple');
            }
          }
        }
        if (invitesData is Map) {
          invitesData.values.forEach(checkInvite);
        } else if (invitesData is List) {
          invitesData.forEach(checkInvite);
        }
      }

      return {
        'id': priestUser!['id'],
        'full_name': priestUser!['full_name'],
        'email': priestUser!['email'],
        'mobile': priestUser!['mobile'],
        'gender': priestUser!['gender'] ?? '',
        'dob': priestUser!['dob'] ?? '',
        'address': priestUser!['address'] ?? '',
        'associated_temples': associatedTemples
      };
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> sendPriestInvitation(int userId, String priestEmail) async {
    try {
      final temple = await getTempleByUserId(userId);
      if (temple == null) {
        throw Exception('Temple admin profile not found.');
      }
      final tId = temple['id'];

      // Find priest user
      final uSnapshot = await _dbRef.child('Seva-v1/users').get();
      Map<String, dynamic>? priestUser;
      if (uSnapshot.exists && uSnapshot.value != null) {
        void checkUser(dynamic val) {
          if (val is Map) {
            final u = Map<String, dynamic>.from(val);
            if (u['email'] == priestEmail.trim() && u['role'] == 'priest') {
              priestUser = u;
            }
          }
        }
        if (uSnapshot.value is Map) {
          (uSnapshot.value as Map).values.forEach(checkUser);
        } else if (uSnapshot.value is List) {
          (uSnapshot.value as List).forEach(checkUser);
        }
      }

      if (priestUser == null) {
        throw Exception('Priest not found with this email.');
      }
      final priestId = priestUser!['id'];

      // Check if invitation already exists
      final iSnapshot = await _dbRef.child('Seva-v1/invitations').get();
      Map<String, dynamic>? existingInvite;
      dynamic existingKey;

      if (iSnapshot.exists && iSnapshot.value != null) {
        if (iSnapshot.value is Map) {
          final map = iSnapshot.value as Map;
          for (final entry in map.entries) {
            final val = entry.value;
            if (val is Map && val['temple_id'] == tId && val['priest_id'] == priestId) {
              existingInvite = Map<String, dynamic>.from(val);
              existingKey = entry.key;
              break;
            }
          }
        } else if (iSnapshot.value is List) {
          final list = iSnapshot.value as List;
          for (var i = 0; i < list.length; i++) {
            final val = list[i];
            if (val is Map && val['temple_id'] == tId && val['priest_id'] == priestId) {
              existingInvite = Map<String, dynamic>.from(val);
              existingKey = i;
              break;
            }
          }
        }
      }

      if (existingInvite != null) {
        if (existingInvite['status'] == 'accepted') {
          throw Exception('Priest is already working for your temple!');
        }
        await _dbRef.child('Seva-v1/invitations/$existingKey/status').set('pending');
        return;
      }

      final iId = DateTime.now().millisecondsSinceEpoch;
      final newInvite = {
        'id': iId,
        'temple_id': tId,
        'temple_name': temple['name'],
        'priest_id': priestId,
        'priest_name': priestUser!['full_name'],
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String()
      };

      await _dbRef.child('Seva-v1/invitations/$iId').set(newInvite);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<Map<String, dynamic>>> getTempleSentInvites(int userId) async {
    try {
      final temple = await getTempleByUserId(userId);
      if (temple == null) return [];
      final tId = temple['id'];

      final snapshot = await _dbRef.child('Seva-v1/invitations').get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final List<Map<String, dynamic>> invites = [];
      void checkInvite(dynamic val) {
        if (val is Map) {
          final i = Map<String, dynamic>.from(val);
          if (i['temple_id'] == tId) {
            invites.add(i);
          }
        }
      }

      if (snapshot.value is Map) {
        (snapshot.value as Map).values.forEach(checkInvite);
      } else if (snapshot.value is List) {
        (snapshot.value as List).forEach(checkInvite);
      }

      return invites;
    } catch (e) {
      throw Exception('Failed to get temple invitations: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPriestReceivedInvites(int priestId) async {
    try {
      final snapshot = await _dbRef.child('Seva-v1/invitations').get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final List<Map<String, dynamic>> invites = [];
      void checkInvite(dynamic val) {
        if (val is Map) {
          final i = Map<String, dynamic>.from(val);
          if (i['priest_id'] == priestId) {
            invites.add(i);
          }
        }
      }

      if (snapshot.value is Map) {
        (snapshot.value as Map).values.forEach(checkInvite);
      } else if (snapshot.value is List) {
        (snapshot.value as List).forEach(checkInvite);
      }

      return invites;
    } catch (e) {
      throw Exception('Failed to get priest invitations: $e');
    }
  }

  Future<void> respondToInvitation(int inviteId, String status) async {
    try {
      if (status != 'accepted' && status != 'declined') {
        throw Exception('Invalid status response.');
      }
      await _dbRef.child('Seva-v1/invitations/$inviteId/status').set(status);
    } catch (e) {
      throw Exception('Failed to respond to invitation: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTempleAssociatedPriests(int userId) async {
    try {
      final temple = await getTempleByUserId(userId);
      if (temple == null) return [];
      final tId = temple['id'];

      final snapshot = await _dbRef.child('Seva-v1/invitations').get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final List<int> priestIds = [];
      void checkInvite(dynamic val) {
        if (val is Map) {
          final i = Map<String, dynamic>.from(val);
          if (i['temple_id'] == tId && i['status'] == 'accepted') {
            final pId = i['priest_id'];
            if (pId is int) priestIds.add(pId);
          }
        }
      }

      if (snapshot.value is Map) {
        (snapshot.value as Map).values.forEach(checkInvite);
      } else if (snapshot.value is List) {
        (snapshot.value as List).forEach(checkInvite);
      }

      final List<Map<String, dynamic>> priests = [];
      for (final pId in priestIds) {
        final pSnap = await _dbRef.child('Seva-v1/users/$pId').get();
        if (pSnap.exists && pSnap.value != null) {
          final pMap = Map<String, dynamic>.from(pSnap.value as Map);
          priests.add({
            'id': pMap['id'],
            'full_name': pMap['full_name'],
            'email': pMap['email'],
            'mobile': pMap['mobile'],
            'gender': pMap['gender'] ?? '',
            'dob': pMap['dob'] ?? '',
            'address': pMap['address'] ?? ''
          });
        }
      }

      return priests;
    } catch (e) {
      throw Exception('Failed to get temple priests: $e');
    }
  }

  Future<Map<String, dynamic>> getTempleStats(int userId) async {
    try {
      final temple = await getTempleByUserId(userId);
      if (temple == null) {
        throw Exception('Temple not found for this user admin account.');
      }
      final tId = temple['id'];

      // Fetch bookings
      final bSnapshot = await _dbRef.child('Seva-v1/bookings').get();
      final List<Map<String, dynamic>> bookings = [];
      if (bSnapshot.exists && bSnapshot.value != null) {
        void addBooking(dynamic val) {
          if (val is Map) {
            bookings.add(Map<String, dynamic>.from(val));
          }
        }
        if (bSnapshot.value is Map) {
          (bSnapshot.value as Map).values.forEach(addBooking);
        } else if (bSnapshot.value is List) {
          (bSnapshot.value as List).forEach(addBooking);
        }
      }

      // Fetch services
      final sSnapshot = await _dbRef.child('Seva-v1/services').get();
      final Map<int, Map<String, dynamic>> servicesMap = {};
      if (sSnapshot.exists && sSnapshot.value != null) {
        void addService(dynamic val) {
          if (val is Map) {
            final s = Map<String, dynamic>.from(val);
            final id = s['id'];
            if (id is int) servicesMap[id] = s;
          }
        }
        if (sSnapshot.value is Map) {
          (sSnapshot.value as Map).values.forEach(addService);
        } else if (sSnapshot.value is List) {
          (sSnapshot.value as List).forEach(addService);
        }
      }

      final templeBookings = bookings.where((b) => b['temple_id'] == tId).toList();
      final totalBookings = templeBookings.length;
      double totalRevenue = 0.0;
      final Map<String, Map<String, dynamic>> breakdownMap = {};

      for (final b in templeBookings) {
        if (b['payment_status'] == 'paid') {
          final sId = b['service_id'];
          final service = servicesMap[sId];
          if (service != null) {
            final price = service['price'] is num ? (service['price'] as num).toDouble() : 0.0;
            totalRevenue += price;

            final sName = service['name'] ?? 'Service';
            if (!breakdownMap.containsKey(sName)) {
              breakdownMap[sName] = {'service_name': sName, 'count': 0, 'revenue': 0.0};
            }
            breakdownMap[sName]!['count'] = (breakdownMap[sName]!['count'] as int) + 1;
            breakdownMap[sName]!['revenue'] = (breakdownMap[sName]!['revenue'] as double) + price;
          }
        }
      }

      return {
        'temple_id': tId,
        'total_bookings': totalBookings,
        'total_revenue': totalRevenue,
        'breakdown': breakdownMap.values.toList()
      };
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
