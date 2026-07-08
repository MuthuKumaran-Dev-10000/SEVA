import 'package:flutter_test/flutter_test.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:seva/core/models/user_model.dart';
import 'package:seva/core/models/priest_model.dart';
import 'package:seva/core/services/firebase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseService service;

  setUp(() async {
    service = FirebaseService();
    await service.clearSession();
  });

  tearDown(() async {
    await service.clearSession();
  });

  group('Auth Hashing & Models Tests', () {
    test('BCrypt Hashing and Verification Works', () {
      final password = "my_secret_password";
      final salt = BCrypt.gensalt();
      final hash = BCrypt.hashpw(password, salt);

      expect(hash, isNot(password));
      expect(BCrypt.checkpw(password, hash), isTrue);
      expect(BCrypt.checkpw("wrong_password", hash), isFalse);
    });

    test('UserModel JSON Parsing is Robust', () {
      final Map<dynamic, dynamic> userJson = {
        'name': 'Kumaran Dev',
        'email': 'kumaran@gmail.com',
        'phone': '9876543212',
        'passwordHash': 'bcrypt_stub_hash',
        'securityQuestion': 'What is your birth city?',
        'securityAnswer': 'Madurai',
        'profilePic': 'https://example.com/pic.png',
        'bio': 'Spiritual seeker.',
        'role': 'user'
      };

      final user = UserModel.fromJson(userJson, 'usr_kumaran');

      expect(user.uid, 'usr_kumaran');
      expect(user.name, 'Kumaran Dev');
      expect(user.role, UserRole.user);
      expect(user.passwordHash, 'bcrypt_stub_hash');
    });

    test('PriestModel JSON Parsing is Robust', () {
      final Map<dynamic, dynamic> priestJson = {
        'name': 'Gokul Gurukkal',
        'dob': '1982-03-15',
        'age': '44',
        'gender': 'Male',
        'mobile': '9876543005',
        'email': 'gokul@gmail.com',
        'address': 'Madurai',
        'experience': '14 Years',
        'rasi': 'Simha',
        'nakshatra': 'Magha',
        'lagnam': 'Simha',
        'bio': 'Specialist in Shanmuga Archana.',
        'photo': 'https://example.com/photo.jpg',
      };

      final priest = PriestModel.fromJson(priestJson, 'priest_gokul');

      expect(priest.id, 'priest_gokul');
      expect(priest.name, 'Gokul Gurukkal');
      expect(priest.age, 44);
      expect(priest.rasi, 'Simha');
    });

    test('Session Fallback and Offline Database Operations Work', () async {
      // Ensure local offline mode functions correctly
      await service.saveSession('usr_test', UserRole.priest);
      final sessionUid = await service.getSessionUserId();
      final sessionRole = await service.getSessionUserRole();

      expect(sessionUid, 'usr_test');
      expect(sessionRole, UserRole.priest);

      await service.clearSession();
      final sessionUidCleared = await service.getSessionUserId();
      expect(sessionUidCleared, isNull);
    });

    test('Signup and signin persist the active user session', () async {
      final email = 'unit_test_${DateTime.now().millisecondsSinceEpoch}@gmail.com';

      final createdUser = await service.signUp(
        email: email,
        password: '123456',
        name: 'Unit Test Devotee',
        phone: '9999999999',
        role: UserRole.user,
        securityQuestion: 'What is your birth city?',
        securityAnswer: 'Madurai',
        profilePic: '',
      );

      expect(createdUser.email, email);
      expect(createdUser.role, UserRole.user);

      final signedInUser = await service.signIn(email: email, password: '123456');
      expect(signedInUser.uid, createdUser.uid);
      expect(signedInUser.name, 'Unit Test Devotee');

      final currentUser = await service.getCurrentUser();
      expect(currentUser?.uid, createdUser.uid);
    });
  });
}
