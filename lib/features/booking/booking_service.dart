import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../temple/temple_service.dart';
import '../service/service_service.dart';

class BookingService {
  final TempleService templeService;
  final ServiceService serviceService;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  static const List<String> slots = [
    "06:00", "07:30", "09:00", "10:30", "12:00", "16:00", "17:30", "19:00"
  ];

  BookingService(this.templeService, this.serviceService);

  Future<List<Map<String, dynamic>>> getSlotsStatus(int serviceId, String date) async {
    try {
      final snapshot = await _dbRef.child('Seva-v1/bookings').get();
      final Map<String, int> bookedCounts = {};

      void checkBooking(dynamic val) {
        if (val is Map) {
          final b = Map<String, dynamic>.from(val);
          if (b['service_id'] == serviceId && b['booking_date'] == date && b['status'] != 'declined') {
            final slot = b['slot_time']?.toString();
            if (slot != null) {
              bookedCounts[slot] = (bookedCounts[slot] ?? 0) + 1;
            }
          }
        }
      }

      if (snapshot.exists && snapshot.value != null) {
        if (snapshot.value is Map) {
          (snapshot.value as Map).values.forEach(checkBooking);
        } else if (snapshot.value is List) {
          (snapshot.value as List).forEach(checkBooking);
        }
      }

      final List<Map<String, dynamic>> slotStatuses = [];
      for (final slot in slots) {
        final count = bookedCounts[slot] ?? 0;
        slotStatuses.add({
          'time': slot,
          'status': count >= 1 ? 'full' : 'available',
          'booked_count': count
        });
      }

      return slotStatuses;
    } catch (e) {
      throw Exception('Failed to get slots: $e');
    }
  }

  Future<Map<String, dynamic>> bookSeva(Map<String, dynamic> bookingData, int userId) async {
    try {
      final serviceId = bookingData['service_id'];
      final bookingDate = bookingData['booking_date'];
      final slotTime = bookingData['slot_time'];
      final templeId = bookingData['temple_id'];
      final attendeeName = bookingData['attendee_name'];

      final newBookingId = DateTime.now().millisecondsSinceEpoch;
      
      // Use Firebase RTDB Transaction on Seva-v1/bookings to ensure double booking check and insert are atomic
      final result = await _dbRef.child('Seva-v1/bookings').runTransaction((Object? currentBookings) {
        if (currentBookings != null) {
          // Check for conflicts
          bool alreadyBooked = false;

          void checkConflict(dynamic bVal) {
            if (bVal is Map) {
              final b = Map<String, dynamic>.from(bVal);
              if (b['service_id'] == serviceId &&
                  b['booking_date'] == bookingDate &&
                  b['slot_time'] == slotTime &&
                  b['status'] != 'declined') {
                alreadyBooked = true;
              }
            }
          }

          if (currentBookings is Map) {
            currentBookings.values.forEach(checkConflict);
          } else if (currentBookings is List) {
            currentBookings.forEach(checkConflict);
          }

          if (alreadyBooked) {
            return Transaction.abort();
          }
        }

        // Add the new booking
        final bookingNode = {
          'id': newBookingId,
          'temple_id': templeId,
          'service_id': serviceId,
          'user_id': userId,
          'priest_id': '',
          'attendee_name': attendeeName,
          'booking_date': bookingDate,
          'slot_time': slotTime,
          'payment_status': 'pending',
          'status': 'pending',
          'created_at': DateTime.now().toUtc().toIso8601String()
        };

        if (currentBookings is Map) {
          final Map<dynamic, dynamic> updatedMap = Map.from(currentBookings);
          updatedMap[newBookingId.toString()] = bookingNode;
          return Transaction.success(updatedMap);
        } else {
          // If null or list (though null is normal at first)
          final Map<String, dynamic> updatedMap = {};
          if (currentBookings is List) {
            for (var i = 0; i < currentBookings.length; i++) {
              if (currentBookings[i] != null) {
                updatedMap[i.toString()] = currentBookings[i];
              }
            }
          }
          updatedMap[newBookingId.toString()] = bookingNode;
          return Transaction.success(updatedMap);
        }
      });

      if (!result.committed) {
        throw Exception('This timing slot has already been booked. Please select another timing.');
      }

      return {
        'booking_id': newBookingId,
        'status': 'pending',
        'message': 'Slot locked.'
      };
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> checkoutAndPay(int bookingId) async {
    try {
      await _dbRef.child('Seva-v1/bookings/$bookingId/payment_status').set('paid');
    } catch (e) {
      throw Exception('Payment checkout failed: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchContactInfo(int entityId, String entityType) async {
    try {
      if (entityType == 'devotee' || entityType == 'priest') {
        final snapshot = await _dbRef.child('Seva-v1/users/$entityId').get();
        if (snapshot.exists && snapshot.value != null) {
          final user = Map<String, dynamic>.from(snapshot.value as Map);
          return {
            'name': user['full_name'] ?? '',
            'mobile': user['mobile'] ?? '',
            'email': user['email'] ?? '',
            'address': user['address'] ?? ''
          };
        }
      } else if (entityType == 'temple') {
        final snapshot = await _dbRef.child('Seva-v1/temples/$entityId').get();
        if (snapshot.exists && snapshot.value != null) {
          final temple = Map<String, dynamic>.from(snapshot.value as Map);
          final adminUserId = temple['user_id'];
          
          Map<String, dynamic>? adminUser;
          if (adminUserId != null) {
            final uSnap = await _dbRef.child('Seva-v1/users/$adminUserId').get();
            if (uSnap.exists && uSnap.value != null) {
              adminUser = Map<String, dynamic>.from(uSnap.value as Map);
            }
          }
          
          return {
            'name': temple['name'] ?? '',
            'mobile': adminUser != null ? adminUser['mobile'] ?? '' : '',
            'email': adminUser != null ? adminUser['email'] ?? '' : '',
            'address': temple['location'] ?? ''
          };
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getBookingHistory(int userId) async {
    try {
      // 1. Fetch user role
      final uSnap = await _dbRef.child('Seva-v1/users/$userId').get();
      if (!uSnap.exists || uSnap.value == null) {
        throw Exception('User not found');
      }
      final user = Map<String, dynamic>.from(uSnap.value as Map);
      final role = user['role'];

      // 2. Fetch all bookings
      final bSnap = await _dbRef.child('Seva-v1/bookings').get();
      final List<Map<String, dynamic>> allBookings = [];
      if (bSnap.exists && bSnap.value != null) {
        void addBooking(dynamic val) {
          if (val is Map) {
            allBookings.add(Map<String, dynamic>.from(val));
          }
        }
        if (bSnap.value is Map) {
          (bSnap.value as Map).values.forEach(addBooking);
        } else if (bSnap.value is List) {
          (bSnap.value as List).forEach(addBooking);
        }
      }

      // 3. Filter bookings by role
      List<Map<String, dynamic>> filtered = [];
      if (role == 'devotee') {
        filtered = allBookings.where((b) => b['user_id'] == userId).toList();
      } else if (role == 'priest') {
        // Fetch priest accepted invitations
        final iSnap = await _dbRef.child('Seva-v1/invitations').get();
        final List<int> associatedTempleIds = [];
        if (iSnap.exists && iSnap.value != null) {
          void checkInvite(dynamic val) {
            if (val is Map) {
              final invite = Map<String, dynamic>.from(val);
              if (invite['priest_id'] == userId && invite['status'] == 'accepted') {
                final tId = invite['temple_id'];
                if (tId is int) associatedTempleIds.add(tId);
              }
            }
          }
          if (iSnap.value is Map) {
            (iSnap.value as Map).values.forEach(checkInvite);
          } else if (iSnap.value is List) {
            (iSnap.value as List).forEach(checkInvite);
          }
        }

        filtered = allBookings.where((b) =>
          b['priest_id'] == userId ||
          ( (b['priest_id'] == null || b['priest_id'] == 0 || b['priest_id'].toString().isEmpty) &&
            associatedTempleIds.contains(b['temple_id']) )
        ).toList();
      } else if (role == 'temple') {
        final temple = await templeService.getTempleByUserId(userId);
        if (temple != null) {
          final tId = temple['id'];
          filtered = allBookings.where((b) => b['temple_id'] == tId).toList();
        }
      }

      // 4. Fetch details of temple and service for each booking
      // Let's cache temples and services to save network calls
      final temples = await templeService.getTemples();
      final Map<int, Map<String, dynamic>> templesMap = {
        for (final t in temples) t['id']: t
      };

      final services = await serviceService.getAllServices(null);
      final Map<int, Map<String, dynamic>> servicesMap = {
        for (final s in services) s['id']: s
      };

      final List<Map<String, dynamic>> results = [];
      for (final b in filtered) {
        final templeId = b['temple_id'];
        final serviceId = b['service_id'];
        final temple = templesMap[templeId];
        final service = servicesMap[serviceId];

        final bDict = {
          'id': b['id'],
          'temple_id': templeId,
          'temple_name': temple != null ? temple['name'] ?? 'Temple' : 'Temple',
          'service_id': serviceId,
          'service_name': service != null ? service['name'] ?? 'Service' : 'Service',
          'price': service != null ? (service['price'] as num).toDouble() : 0.0,
          'user_id': b['user_id'],
          'attendee_name': b['attendee_name'],
          'booking_date': b['booking_date'],
          'slot_time': b['slot_time'],
          'payment_status': b['payment_status'],
          'status': b['status'],
          'created_at': b['created_at'] ?? '',
          'priest_id': b['priest_id'] is int ? b['priest_id'] : (int.tryParse(b['priest_id'].toString()) ?? 0),
          'room_code': b['room_code']?.toString() ?? '',
          'join_codes': b['join_codes'],
        };

        // Attach shared contacts if accepted
        if (b['status'] == 'accepted') {
          bDict['devotee_contact'] = await _fetchContactInfo(b['user_id'], 'devotee');
          bDict['temple_contact'] = await _fetchContactInfo(templeId, 'temple');
          final pId = b['priest_id'];
          if (pId != null && pId != 0 && pId.toString().isNotEmpty) {
            bDict['priest_contact'] = await _fetchContactInfo(int.parse(pId.toString()), 'priest');
          } else {
            bDict['priest_contact'] = null;
          }
        } else {
          bDict['devotee_contact'] = null;
          bDict['priest_contact'] = null;
          bDict['temple_contact'] = null;
        }

        results.add(bDict);
      }

      // Sort by booking date and slot time descending
      results.sort((a, b) {
        final cmpDate = (b['booking_date'] ?? '').compareTo(a['booking_date'] ?? '');
        if (cmpDate != 0) return cmpDate;
        return (b['slot_time'] ?? '').compareTo(a['slot_time'] ?? '');
      });

      return results;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> respondToBooking(int bookingId, int priestId, String status) async {
    try {
      if (status != 'accepted' && status != 'declined') {
        throw Exception('Invalid status. Must be accepted or declined.');
      }

      // Get booking
      final bSnap = await _dbRef.child('Seva-v1/bookings/$bookingId').get();
      if (!bSnap.exists || bSnap.value == null) {
        throw Exception('Booking request not found');
      }
      final booking = Map<String, dynamic>.from(bSnap.value as Map);
      final templeId = booking['temple_id'];

      // Verify association
      final iSnap = await _dbRef.child('Seva-v1/invitations').get();
      bool isLinked = false;
      if (iSnap.exists && iSnap.value != null) {
        void checkInvite(dynamic val) {
          if (val is Map) {
            final invite = Map<String, dynamic>.from(val);
            if (invite['temple_id'] == templeId && invite['priest_id'] == priestId && invite['status'] == 'accepted') {
              isLinked = true;
            }
          }
        }
        if (iSnap.value is Map) {
          (iSnap.value as Map).values.forEach(checkInvite);
        } else if (iSnap.value is List) {
          (iSnap.value as List).forEach(checkInvite);
        }
      }

      if (!isLinked) {
        throw Exception('Priest is not associated with this temple.');
      }

      if (status == 'accepted') {
        // Generate meeting codes: N codes for N attendees + 1 host room code
        final attendeeCount = (booking['attendee_count'] as int?) ?? 1;
        final roomCode = _generateCode(8);
        final joinCodes = List.generate(attendeeCount, (_) => _generateCode(8));

        // Get service name and priest name
        String serviceName = 'Seva';
        String priestName = 'Priest';
        try {
          final sSnap = await _dbRef.child('Seva-v1/services/${booking['service_id']}').get();
          if (sSnap.exists && sSnap.value is Map) {
            serviceName = (sSnap.value as Map)['name']?.toString() ?? serviceName;
          }
          final pSnap = await _dbRef.child('Seva-v1/users/$priestId').get();
          if (pSnap.exists && pSnap.value is Map) {
            priestName = (pSnap.value as Map)['full_name']?.toString() ?? priestName;
          }
        } catch (_) {}

        // Calculate expiry: booking_date + slot_to_time + 30 minutes
        DateTime? expiresAt;
        try {
          final bookingDate = booking['booking_date']?.toString();
          final slotTime = booking['slot_time']?.toString(); // format: HH:mm or HH:mm-HH:mm
          if (bookingDate != null && slotTime != null) {
            final slotTo = slotTime.contains('-') ? slotTime.split('-').last.trim() : slotTime;
            final parts = slotTo.split(':');
            final h = int.tryParse(parts[0]) ?? 0;
            final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
            final baseDate = DateTime.parse('${bookingDate}T00:00:00');
            expiresAt = baseDate.add(Duration(hours: h, minutes: m + 30)).toUtc();
          }
        } catch (_) {}

        // Store meeting in Firebase
        await _dbRef.child('Seva-v1/meetings/$roomCode').set({
          'room_code': roomCode,
          'join_codes': joinCodes,
          'booking_id': bookingId,
          'service_name': serviceName,
          'priest_id': priestId,
          'priest_name': priestName,
          'devotee_user_id': booking['user_id'],
          'slot_time': booking['slot_time'],
          'booking_date': booking['booking_date'],
          'attendee_count': attendeeCount,
          'expires_at': expiresAt?.toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        // Update booking record with meeting info
        await _dbRef.child('Seva-v1/bookings/$bookingId').update({
          'status': 'accepted',
          'priest_id': priestId,
          'room_code': roomCode,
          'join_codes': joinCodes,
        });
      } else {
        await _dbRef.child('Seva-v1/bookings/$bookingId').update({
          'status': 'declined',
          'priest_id': ''
        });
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Also allow temple admin to accept bookings directly (without a priest ID)
  Future<void> acceptBookingAsTemple(int bookingId, int templeUserId) async {
    try {
      final bSnap = await _dbRef.child('Seva-v1/bookings/$bookingId').get();
      if (!bSnap.exists || bSnap.value == null) throw Exception('Booking not found');
      final booking = Map<String, dynamic>.from(bSnap.value as Map);

      // Verify this temple owns the booking
      final tSnap = await _dbRef.child('Seva-v1/temples').get();
      int? templeId;
      if (tSnap.exists && tSnap.value != null) {
        void checkT(dynamic v) {
          if (v is Map) {
            final t = Map<String, dynamic>.from(v);
            if (t['user_id'] == templeUserId) templeId = t['id'];
          }
        }
        if (tSnap.value is Map) {
          (tSnap.value as Map).values.forEach(checkT);
        }
      }
      if (templeId == null || booking['temple_id'] != templeId) {
        throw Exception('Not authorized to accept this booking.');
      }

      // Generate codes
      final attendeeCount = (booking['attendee_count'] as int?) ?? 1;
      final roomCode = _generateCode(8);
      final joinCodes = List.generate(attendeeCount, (_) => _generateCode(8));

      String serviceName = 'Seva';
      String priestName = 'Temple Admin';
      try {
        final uSnap = await _dbRef.child('Seva-v1/users/$templeUserId').get();
        if (uSnap.exists && uSnap.value is Map) {
          priestName = (uSnap.value as Map)['full_name']?.toString() ?? priestName;
        }
      } catch (_) {}
      
      try {
        final sSnap = await _dbRef.child('Seva-v1/services/${booking['service_id']}').get();
        if (sSnap.exists && sSnap.value is Map) {
          serviceName = (sSnap.value as Map)['name']?.toString() ?? serviceName;
        }
      } catch (_) {}

      DateTime? expiresAt;
      try {
        final bookingDate = booking['booking_date']?.toString();
        final slotTime = booking['slot_time']?.toString();
        if (bookingDate != null && slotTime != null) {
          final slotTo = slotTime.contains('-') ? slotTime.split('-').last.trim() : slotTime;
          final parts = slotTo.split(':');
          final h = int.tryParse(parts[0]) ?? 0;
          final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          final baseDate = DateTime.parse('${bookingDate}T00:00:00');
          expiresAt = baseDate.add(Duration(hours: h, minutes: m + 30)).toUtc();
        }
      } catch (_) {}

      await _dbRef.child('Seva-v1/meetings/$roomCode').set({
        'room_code': roomCode,
        'join_codes': joinCodes,
        'booking_id': bookingId,
        'service_name': serviceName,
        'priest_id': templeUserId,
        'priest_name': priestName,
        'devotee_user_id': booking['user_id'],
        'slot_time': booking['slot_time'],
        'booking_date': booking['booking_date'],
        'attendee_count': attendeeCount,
        'expires_at': expiresAt?.toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      await _dbRef.child('Seva-v1/bookings/$bookingId').update({
        'status': 'accepted',
        'room_code': roomCode,
        'join_codes': joinCodes,
      });
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Generate a random uppercase alphanumeric code of [length] characters
  String _generateCode(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars like 0/O, 1/I
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // Placeholder for name — set externally or passed as param in real usage
  String? auth_currentUser_Name;
}
