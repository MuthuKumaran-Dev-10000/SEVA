import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  FirebaseService get firebaseService => _firebaseService;
  UserModel? _currentUser;
  // Start as true so AuthWrapper shows a loading spinner during session restore
  bool _isLoading = true;
  String? _errorMessage;
  int _authVersion = 0;
  bool _profileMissing = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get profileMissing => _profileMissing;

  AuthProvider() {
    checkActiveSession();
  }

  Future<void> checkActiveSession() async {
    final int requestVersion = _authVersion;
    // _isLoading is already true from initialization
    try {
      final restoredUser = await _firebaseService.getCurrentUser();
      if (requestVersion == _authVersion) {
        _currentUser = restoredUser;
        _profileMissing = _firebaseService.isFirebaseAvailable &&
            FirebaseAuth.instance.currentUser != null &&
            restoredUser == null;
        if (_profileMissing) {
          _errorMessage = 'Devotee profile not found for this authenticated account.';
        }
      }
    } catch (e) {
      if (requestVersion == _authVersion) {
        _errorMessage = e.toString();
      }
    } finally {
      if (requestVersion == _authVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> signIn(String email, String password) async {
    final int requestVersion = ++_authVersion;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final signedInUser = await _firebaseService.signIn(email: email, password: password);
      if (requestVersion == _authVersion) {
        _currentUser = signedInUser;
        _profileMissing = false;
      }
      return true;
    } catch (e) {
      if (requestVersion == _authVersion) {
        _errorMessage = e.toString();
        _profileMissing = e.toString().contains('USER_NOT_FOUND');
        if (_profileMissing) {
          _currentUser = null;
        }
      }
      return false;
    } finally {
      if (requestVersion == _authVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
    required String securityQuestion,
    required String securityAnswer,
    required String profilePic,
  }) async {
    final int requestVersion = ++_authVersion;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final signedUpUser = await _firebaseService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
        securityQuestion: securityQuestion,
        securityAnswer: securityAnswer,
        profilePic: profilePic,
      );
      if (requestVersion == _authVersion) {
        _currentUser = signedUpUser;
        _profileMissing = false;
      }
      return true;
    } catch (e) {
      if (requestVersion == _authVersion) {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      if (requestVersion == _authVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String securityAnswer,
    required String newPassword,
  }) async {
    final int requestVersion = ++_authVersion;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _firebaseService.resetPassword(
        email: email,
        securityAnswer: securityAnswer,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      if (requestVersion == _authVersion) {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      if (requestVersion == _authVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> signOut() async {
    final int requestVersion = ++_authVersion;
    _isLoading = true;
    notifyListeners();
    try {
      await _firebaseService.clearSession();
      if (requestVersion == _authVersion) {
        _currentUser = null;
        _profileMissing = false;
      }
    } catch (e) {
      if (requestVersion == _authVersion) {
        _errorMessage = e.toString();
      }
    } finally {
      if (requestVersion == _authVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshProfile() async {
    if (_currentUser != null) {
      _currentUser = await _firebaseService.getCurrentUser();
      notifyListeners();
    }
  }
}
