import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../family/family_service.dart';
import '../temple/temple_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  final FamilyService familyService = FamilyService();
  final TempleService templeService = TempleService();

  // SHA-256 Hashing helper
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>> login(String emailOrPhone, String password) async {
    try {
      String email = emailOrPhone.trim();
      
      // If input is not an email, lookup phone number in the database to retrieve email
      if (!email.contains('@')) {
        final uSnapshot = await _dbRef.child('Seva-v1/users').get();
        String? foundEmail;
        if (uSnapshot.exists && uSnapshot.value != null) {
          void checkUser(dynamic key, dynamic val) {
            if (val is Map) {
              final u = Map<String, dynamic>.from(val);
              final inputDigits = email.replaceAll(RegExp(r'\D'), '');
              final userPhoneDigits = (u['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
              if (inputDigits.isNotEmpty && userPhoneDigits.isNotEmpty && userPhoneDigits == inputDigits) {
                foundEmail = u['email']?.toString();
              }
            }
          }
          if (uSnapshot.value is Map) {
            (uSnapshot.value as Map).forEach(checkUser);
          } else if (uSnapshot.value is List) {
            final list = uSnapshot.value as List;
            for (var i = 0; i < list.length; i++) {
              checkUser(i, list[i]);
            }
          }
        }
        if (foundEmail != null) {
          email = foundEmail!;
        } else {
          throw Exception('No account found with this phone number.');
        }
      }

      bool firebaseAuthSuccess = false;

      try {
        await _firebaseAuth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        firebaseAuthSuccess = true;
      } on FirebaseAuthException catch (authEx) {
        // If the user doesn't exist in Firebase Auth yet, it might be a pre-seeded account in the DB.
        if (authEx.code != 'user-not-found' && authEx.code != 'invalid-email' && authEx.code != 'invalid-credential') {
          // If it is another error (like wrong password), rethrow it
          throw Exception(authEx.message ?? 'Authentication failed');
        }
      }

      // 1. Fetch user from RTDB where email == email
      final snapshot = await _dbRef.child('Seva-v1/users').get();
      Map<String, dynamic>? rtdbUser;
      dynamic rtdbKey;

      if (snapshot.exists && snapshot.value != null) {
        void checkUser(dynamic key, dynamic val) {
          if (val is Map) {
            final u = Map<String, dynamic>.from(val);
            if (u['email']?.toString().toLowerCase() == email.trim().toLowerCase()) {
              rtdbUser = u;
              rtdbKey = key;
            }
          }
        }
        if (snapshot.value is Map) {
          (snapshot.value as Map).forEach(checkUser);
        } else if (snapshot.value is List) {
          final list = snapshot.value as List;
          for (var i = 0; i < list.length; i++) {
            checkUser(i, list[i]);
          }
        }
      }

      // If user not found in RTDB, fail
      if (rtdbUser == null) {
        throw Exception('Invalid email/phone or password');
      }

      final enteredHash = _hashPassword(password);

      // If we didn't log into Firebase Auth (e.g. user was not in Firebase Auth dashboard yet)
      if (!firebaseAuthSuccess) {
        // Validate password against SHA-256 hash in RTDB
        if (rtdbUser!['password_hash'] != enteredHash) {
          throw Exception('Invalid email or password');
        }

        // Automatic Migration: Create user in Firebase Auth so next time they can log in natively
        try {
          await _firebaseAuth.createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        } catch (migrationEx) {
          // If they already exist in Firebase Auth but signin failed (e.g. password mismatch), we try to sync password or ignore
          // Simply log in with signIn if they exist
          try {
            await _firebaseAuth.signInWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
          } catch (_) {
            // If sync fails, proceed anyway since RTDB matched
          }
        }
      } else {
        // Double check password hash in RTDB matches to be secure (or update it if empty)
        if (rtdbUser!['password_hash'] != enteredHash) {
          // If password was reset or changed in Firebase Auth, we update the RTDB hash
          await _dbRef.child('Seva-v1/users/$rtdbKey/password_hash').set(enteredHash);
          rtdbUser!['password_hash'] = enteredHash;
        }
      }

      return rtdbUser!;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> signup(Map<String, dynamic> userData) async {
    try {
      final email = userData['email'];
      final password = userData['password'];
      final fullName = userData['full_name'];
      final mobile = userData['mobile'];
      final role = userData['role'];

      // 1. Create in Firebase Auth
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // 2. Generate integer user ID
      final uId = DateTime.now().millisecondsSinceEpoch;
      final pwHash = _hashPassword(password);

      final userNode = {
        'id': uId,
        'email': email.trim(),
        'password_hash': pwHash,
        'full_name': fullName,
        'mobile': mobile,
        'role': role,
        'dob': userData['dob'] ?? '',
        'star': userData['star'] ?? '',
        'rasi': userData['rasi'] ?? '',
        'gender': userData['gender'] ?? '',
        'address': userData['address'] ?? '',
        'description': userData['description'] ?? '',
        'location_link': userData['location_link'] ?? '',
        'avatar_url': ''
      };

      // 3. Save to RTDB
      await _dbRef.child('Seva-v1/users/$uId').set(userNode);

      // 4. Role specific seeding
      if (role == 'devotee') {
        await familyService.addFamilyMember(uId, {
          'name': fullName,
          'dob': userData['dob'] ?? '1990-01-01',
          'star': userData['star'] ?? '',
          'gender': userData['gender'] ?? 'Male',
          'rasi': userData['rasi'] ?? '',
          'email': email,
          'mobile_no': mobile
        });
      } else if (role == 'temple') {
        await templeService.createTemple({
          'user_id': uId,
          'name': fullName,
          'location': userData['address'] ?? 'Address',
          'description': userData['description'] ?? 'Temple description',
          'location_link': userData['location_link'] ?? ''
        });
      }

      return userNode;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updateData) async {
    try {
      final userId = updateData['user_id'];
      if (userId == null) throw Exception('User ID is required');

      // Fetch existing user to find role and name
      final snapshot = await _dbRef.child('Seva-v1/users/$userId').get();
      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('User not found');
      }
      final existingUser = Map<String, dynamic>.from(snapshot.value as Map);
      final role = existingUser['role'];
      final oldName = existingUser['full_name'];

      final updateFields = {
        'full_name': updateData['full_name'],
        'mobile': updateData['mobile'],
        'address': updateData['address'] ?? '',
        'dob': updateData['dob'] ?? '',
        'star': updateData['star'] ?? '',
        'rasi': updateData['rasi'] ?? '',
        'gender': updateData['gender'] ?? '',
        'description': updateData['description'] ?? '',
        'location_link': updateData['location_link'] ?? ''
      };

      // Update in RTDB
      await _dbRef.child('Seva-v1/users/$userId').update(updateFields);

      // Also update role-specific secondary entities
      if (role == 'devotee') {
        await familyService.updateFamilyMemberDetails(userId, oldName, {
          'name': updateData['full_name'],
          'mobile_no': updateData['mobile'],
          'dob': updateData['dob'] ?? '1990-01-01',
          'star': updateData['star'] ?? '',
          'rasi': updateData['rasi'] ?? '',
          'gender': updateData['gender'] ?? 'Male'
        });
      } else if (role == 'temple') {
        final temple = await templeService.getTempleByUserId(userId);
        if (temple != null) {
          await templeService.updateTemple(temple['id'], {
            'name': updateData['full_name'],
            'location': updateData['address'] ?? 'Address',
            'description': updateData['description'] ?? 'Description',
            'location_link': updateData['location_link'] ?? ''
          });
        }
      }

      // Return updated user
      final updatedSnap = await _dbRef.child('Seva-v1/users/$userId').get();
      return Map<String, dynamic>.from(updatedSnap.value as Map);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> uploadAvatar(int userId, String filePath) async {
    try {
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'seva';

      if (cloudName == null || cloudName.isEmpty) {
        throw Exception('Cloudinary configuration missing in .env');
      }

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);
      
      request.fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        final bytes = await http.readBytes(Uri.parse(filePath));
        final multipartFile = http.MultipartFile.fromBytes(
          'file', 
          bytes,
          filename: 'avatar.jpg',
        );
        request.files.add(multipartFile);
      } else {
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('File does not exist: $filePath');
        }
        final multipartFile = await http.MultipartFile.fromPath('file', file.path);
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw Exception('Cloudinary upload failed: ${response.body}');
      }

      final responseData = jsonDecode(response.body);
      final secureUrl = responseData['secure_url'];

      if (secureUrl == null) {
        throw Exception('Failed to retrieve secure URL from Cloudinary');
      }

      // Update in RTDB
      await _dbRef.child('Seva-v1/users/$userId/avatar_url').set(secureUrl);

      return {'avatar_url': secureUrl};
    } catch (e) {
      throw Exception('Avatar upload failed: $e');
    }
  }
}
