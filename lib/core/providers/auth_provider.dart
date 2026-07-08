import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import '../api_client.dart';
import '../session_store.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient api;

  Map<String, dynamic>? _currentUser;
  List<dynamic> _familyMembers = [];
  
  // Priest specific state
  List<dynamic> _priestInvitations = [];
  
  // Temple specific state
  List<dynamic> _templePriests = [];
  Map<String, dynamic>? _templeStats;

  bool _isLoading = false;
  String? _errorMessage;

  // Real-time subscriptions
  StreamSubscription<DatabaseEvent>? _userDbSubscription;
  StreamSubscription<DatabaseEvent>? _familyDbSubscription;
  StreamSubscription<DatabaseEvent>? _invitesDbSubscription;
  StreamSubscription<DatabaseEvent>? _priestsDbSubscription;
  StreamSubscription<DatabaseEvent>? _statsDbSubscription;

  Map<String, dynamic>? get currentUser => _currentUser;
  List<dynamic> get familyMembers => _familyMembers;
  List<dynamic> get priestInvitations => _priestInvitations;
  List<dynamic> get templePriests => _templePriests;
  Map<String, dynamic>? get templeStats => _templeStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;

  String? _cachedSession;

  String get _sessionPrefix {
    if (_cachedSession != null) {
      return '${_cachedSession}_';
    }
    
    // 1. Try sessionStorage first to persist across tab refreshes
    final stored = getSessionCode();
    if (stored != null && stored.isNotEmpty) {
      _cachedSession = stored;
      return '${stored}_';
    }

    // 2. Try URL query parameter
    try {
      final session = Uri.base.queryParameters['session'];
      if (session != null && session.isNotEmpty) {
        _cachedSession = session;
        setSessionCode(session);
        return '${session}_';
      }
    } catch (_) {}
    
    return '';
  }

  AuthProvider(this.api) {
    _tryAutoLogin();
  }

  @override
  void dispose() {
    _cancelRealtimeListeners();
    super.dispose();
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('${_sessionPrefix}current_user');
    if (userJson != null) {
      try {
        _currentUser = jsonDecode(userJson);
        notifyListeners();
        _startRealtimeListeners();
        _fetchRoleBasedData();
      } catch (_) {
        await logout();
      }
    }
  }

  void _startRealtimeListeners() {
    _cancelRealtimeListeners();
    if (_currentUser == null) return;
    
    final userId = _currentUser!['id'];
    final role = _currentUser!['role'];

    // 1. Real-time User Node Listener
    _userDbSubscription = FirebaseDatabase.instance
        .ref('Seva-v1/users/$userId')
        .onValue
        .listen((event) async {
      final val = event.snapshot.value;
      if (val is Map) {
        _currentUser = Map<String, dynamic>.from(val);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${_sessionPrefix}current_user', jsonEncode(_currentUser));
        notifyListeners();
      }
    });

    // 2. Real-time Role specific listeners
    if (role == 'devotee') {
      _familyDbSubscription = FirebaseDatabase.instance
          .ref('Seva-v1/family_members')
          .onValue
          .listen((event) {
        final data = event.snapshot.value;
        final List<dynamic> tempMembers = [];
        void parse(dynamic v) {
          if (v is Map) {
            final m = Map<String, dynamic>.from(v);
            if (m['user_id'] == userId) tempMembers.add(m);
          }
        }
        if (data != null) {
          if (data is Map) {
            data.values.forEach(parse);
          } else if (data is List) {
            data.forEach(parse);
          }
        }
        _familyMembers = tempMembers;
        notifyListeners();
      });
    } else if (role == 'priest') {
      _invitesDbSubscription = FirebaseDatabase.instance
          .ref('Seva-v1/invitations')
          .onValue
          .listen((event) {
        final data = event.snapshot.value;
        final List<dynamic> tempInvites = [];
        void parse(dynamic v) {
          if (v is Map) {
            final m = Map<String, dynamic>.from(v);
            if (m['priest_id'] == userId) tempInvites.add(m);
          }
        }
        if (data != null) {
          if (data is Map) {
            data.values.forEach(parse);
          } else if (data is List) {
            data.forEach(parse);
          }
        }
        _priestInvitations = tempInvites;
        notifyListeners();
      });
    } else if (role == 'temple') {
      // Listen to accepted priests associated with this temple
      _priestsDbSubscription = FirebaseDatabase.instance
          .ref('Seva-v1/invitations')
          .onValue
          .listen((event) {
        final data = event.snapshot.value;
        final List<dynamic> tempPriests = [];
        void parse(dynamic v) {
          if (v is Map) {
            final m = Map<String, dynamic>.from(v);
            if (m['temple_user_id'] == userId && m['status'] == 'accepted') {
              tempPriests.add(m);
            }
          }
        }
        if (data != null) {
          if (data is Map) {
            data.values.forEach(parse);
          } else if (data is List) {
            data.forEach(parse);
          }
        }
        _templePriests = tempPriests;
        notifyListeners();
      });

      // Listen to booking metrics/stats for temple dashboard
      _statsDbSubscription = FirebaseDatabase.instance
          .ref('Seva-v1/bookings')
          .onValue
          .listen((event) async {
        final data = event.snapshot.value;
        int totalBookings = 0;
        double totalRevenue = 0.0;
        
        // Find temple ID
        final templesSnap = await FirebaseDatabase.instance.ref('Seva-v1/temples').get();
        int? templeId;
        if (templesSnap.exists && templesSnap.value != null) {
          void checkT(dynamic val) {
            if (val is Map) {
              final t = Map<String, dynamic>.from(val);
              if (t['user_id'] == userId) templeId = t['id'];
            }
          }
          if (templesSnap.value is Map) {
            (templesSnap.value as Map).values.forEach(checkT);
          } else if (templesSnap.value is List) {
            (templesSnap.value as List).forEach(checkT);
          }
        }

        if (templeId != null && data != null) {
          void checkB(dynamic val) {
            if (val is Map) {
              final b = Map<String, dynamic>.from(val);
              if (b['temple_id'] == templeId && b['status'] != 'declined') {
                totalBookings++;
                totalRevenue += b['price'] is num ? (b['price'] as num).toDouble() : 0.0;
              }
            }
          }
          if (data is Map) {
            data.values.forEach(checkB);
          } else if (data is List) {
            data.forEach(checkB);
          }
        }

        _templeStats = {
          'total_bookings': totalBookings,
          'total_revenue': totalRevenue,
        };
        notifyListeners();
      });
    }
  }

  void _cancelRealtimeListeners() {
    _userDbSubscription?.cancel();
    _familyDbSubscription?.cancel();
    _invitesDbSubscription?.cancel();
    _priestsDbSubscription?.cancel();
    _statsDbSubscription?.cancel();
  }

  void _fetchRoleBasedData() {
    if (_currentUser == null) return;
    final role = _currentUser!['role'];
    if (role == 'devotee') {
      fetchFamilyMembers();
    } else if (role == 'priest') {
      fetchPriestInvitations();
    } else if (role == 'temple') {
      fetchTemplePriests();
      fetchTempleStats();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> login(String emailOrPhone, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await api.post('/auth/login', {
        'email': emailOrPhone,
        'password': password,
      });
      _currentUser = response;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_sessionPrefix}current_user', jsonEncode(_currentUser));
      
      _isLoading = false;
      notifyListeners();
      _startRealtimeListeners();
      _fetchRoleBasedData();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup({
    required String email,
    required String password,
    required String fullName,
    required String mobile,
    required String role,
    String? dob,
    String? star,
    String? rasi,
    String? gender,
    String? address,
    String? description,
    String? locationLink,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'email': email,
        'password': password,
        'full_name': fullName,
        'mobile': mobile,
        'role': role,
        'dob': dob ?? '',
        'star': star ?? '',
        'rasi': rasi ?? '',
        'gender': gender ?? '',
        'address': address ?? '',
        'description': description ?? '',
        'location_link': locationLink ?? '',
      };
      
      final response = await api.post('/auth/signup', body);
      _currentUser = response;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_sessionPrefix}current_user', jsonEncode(_currentUser));

      _isLoading = false;
      notifyListeners();
      _startRealtimeListeners();
      _fetchRoleBasedData();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _cancelRealtimeListeners();
    _currentUser = null;
    _familyMembers = [];
    _priestInvitations = [];
    _templePriests = [];
    _templeStats = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_sessionPrefix}current_user');
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String fullName,
    required String mobile,
    String? address,
    String? dob,
    String? star,
    String? rasi,
    String? gender,
    String? description,
    String? locationLink,
  }) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await api.put('/auth/profile', {
        'user_id': _currentUser!['id'],
        'full_name': fullName,
        'mobile': mobile,
        'address': address ?? '',
        'dob': dob ?? '',
        'star': star ?? '',
        'rasi': rasi ?? '',
        'gender': gender ?? '',
        'description': description ?? '',
        'location_link': locationLink ?? '',
      });
      _currentUser = response;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_sessionPrefix}current_user', jsonEncode(_currentUser));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAvatar(String filePath) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await api.uploadFile(
        '/auth/profile/avatar',
        filePath,
        {'user_id': _currentUser!['id'].toString()},
      );
      
      _currentUser!['avatar_url'] = response['avatar_url'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_sessionPrefix}current_user', jsonEncode(_currentUser));
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ----------------- DEVOTEE METHODS -----------------

  Future<void> fetchFamilyMembers() async {
    if (_currentUser == null) return;
    try {
      final response = await api.get('/family?user_id=${_currentUser!['id']}');
      _familyMembers = response;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch family members: $e');
    }
  }

  Future<bool> addFamilyMember({
    required String name,
    required String dob,
    required String star,
    required String gender,
    required String rasi,
    String? email,
    String? mobile,
  }) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await api.post('/family/add?user_id=${_currentUser!['id']}', {
        'name': name,
        'dob': dob,
        'star': star,
        'gender': gender,
        'rasi': rasi,
        'email': email ?? '',
        'mobile_no': mobile ?? '',
      });
      _isLoading = false;
      notifyListeners();
      await fetchFamilyMembers();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ----------------- PRIEST METHODS -----------------

  Future<void> fetchPriestInvitations() async {
    if (_currentUser == null) return;
    try {
      final response = await api.get('/priests/invitations?priest_id=${_currentUser!['id']}');
      _priestInvitations = response;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch priest invitations: $e');
    }
  }

  Future<bool> respondToInvitation(int inviteId, String responseStatus) async {
    try {
      await api.post('/priests/invitations/respond?invite_id=$inviteId&status=$responseStatus', {});
      await fetchPriestInvitations();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ----------------- TEMPLE ADMIN METHODS -----------------

  Future<void> fetchTemplePriests() async {
    if (_currentUser == null) return;
    try {
      final response = await api.get('/temples/priests?user_id=${_currentUser!['id']}');
      _templePriests = response;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch temple priests: $e');
    }
  }

  Future<void> fetchTempleStats() async {
    if (_currentUser == null) return;
    try {
      final response = await api.get('/temples/stats?user_id=${_currentUser!['id']}');
      _templeStats = response;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch temple statistics: $e');
    }
  }

  Future<Map<String, dynamic>?> searchPriestByEmail(String email) async {
    try {
      final response = await api.get('/priests/search?email=${Uri.encodeComponent(email)}');
      return response;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> sendPriestInvitation(String email) async {
    if (_currentUser == null) return false;
    _errorMessage = null;
    notifyListeners();
    try {
      await api.post('/temples/invite?user_id=${_currentUser!['id']}', {
        'priest_email': email,
      });
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Temple Service Creation Helper
  Future<bool> createTempleService({
    required int templeId,
    required String name,
    required double price,
    required String description,
    required String duration,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final sId = DateTime.now().millisecondsSinceEpoch;
      final newService = {
        'id': sId,
        'temple_id': templeId,
        'name': name,
        'price': price,
        'description': description,
        'duration': duration,
      };

      await FirebaseDatabase.instance.ref('Seva-v1/services/$sId').set(newService);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Add Service Slot Helper
  Future<bool> addTempleServiceSlot({
    required int serviceId,
    required String dateStr,
    required String from,
    required String to,
    required int capacity,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final slotId = DateTime.now().millisecondsSinceEpoch.toString();
      final newSlot = {
        'id': slotId,
        'from': from,
        'to': to,
        'capacity': capacity,
      };

      await FirebaseDatabase.instance
          .ref('Seva-v1/services/$serviceId/slots/$dateStr/$slotId')
          .set(newSlot);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
