import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';
import '../models/user_model.dart';
import '../models/family_profile_model.dart';
import '../models/temple_model.dart';
import '../models/priest_model.dart';
import '../models/service_model.dart';
import '../models/order_model.dart';
import '../models/payment_model.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/notification_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal() {
    seedOfflineMockData();
  }

  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Sanitizes keys for Firebase RTDB compatibility
  String _buildPathKey(String id, String name) {
    final cleanName = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return '${id}_$cleanName';
  }

  // --- LOCAL SESSION KEYS ---
  static const String _keyUserId = "session_user_id";
  static const String _keyUserRole = "session_user_role";

  // --- LOCAL MEMORY DB (OFFLINE FALLBACK) ---
  final Map<String, UserModel> _mockUsers = {};
  final Map<String, FamilyProfileModel> _mockFamily = {}; // format: "userId_memberId" -> Member
  final Map<String, TempleModel> _mockTemples = {};
  final Map<String, PriestModel> _mockPriests = {};
  final Map<String, ServiceModel> _mockServices = {};
  final Map<String, OrderModel> _mockOrders = {};
  final Map<String, PaymentModel> _mockPayments = {};
  final Map<String, PostModel> _mockPosts = {};
  final Map<String, Map<String, bool>> _mockLikes = {}; // postId -> userId -> bool
  final Map<String, List<CommentModel>> _mockComments = {}; // postId -> comments
  final Map<String, List<NotificationModel>> _mockNotifications = {}; // userId -> notifications
  final Map<String, Map<String, bool>> _mockSavedPosts = {}; // userId -> postId -> bool
  final Map<String, Map<String, bool>> _mockReports = {}; // postId -> userId -> bool
  final Map<String, Map<String, bool>> _mockUserReports = {}; // userId -> postId -> bool
  final Map<String, int> _mockBookedSlots = {}; // "serviceId|date|time" -> count
  final Map<String, Map<String, bool>> _mockFollowing = {}; // userId -> targetId -> bool
  final Map<String, Map<String, bool>> _mockFollowers = {}; // targetId -> userId -> bool

  
  UserModel? _mockCurrentUser;

  // Real-time broadcast controllers
  final _templesController = StreamController<List<TempleModel>>.broadcast();
  final _priestsController = StreamController<List<PriestModel>>.broadcast();
  final _servicesController = StreamController<List<ServiceModel>>.broadcast();
  final _ordersController = StreamController<List<OrderModel>>.broadcast();
  final _postsController = StreamController<List<PostModel>>.broadcast();
  final _notificationsController = StreamController<List<NotificationModel>>.broadcast();
  final _familyController = StreamController<List<FamilyProfileModel>>.broadcast();

  // --- SESSION PERSISTENCE ---
  String? _fallbackUserId;
  UserRole? _fallbackUserRole;
  bool _useSharedPreferences = true;
  bool _sharedPrefsInitialized = false;

  Future<SharedPreferences?> _getPrefs() async {
    if (!_useSharedPreferences) return null;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 1),
      );
      _sharedPrefsInitialized = true;
      return prefs;
    } catch (e) {
      _useSharedPreferences = false;
      print("SharedPreferences is not available, using in-memory fallback. Error: $e");
      return null;
    }
  }

  Future<void> saveSession(String userId, UserRole role) async {
    _fallbackUserId = userId;
    _fallbackUserRole = role;
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString(_keyUserId, userId);
        await prefs.setString(_keyUserRole, role.name);
      }
    } catch (e) {
      print("SharedPreferences fallback active: $e");
    }
  }

  Future<void> clearSession() async {
    _fallbackUserId = null;
    _fallbackUserRole = null;
    _mockCurrentUser = null;
    try {
      if (isFirebaseAvailable) {
        await FirebaseAuth.instance.signOut();
      }
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.remove(_keyUserId);
        await prefs.remove(_keyUserRole);
      }
    } catch (e) {
      print("SharedPreferences fallback active: $e");
    }
  }

  Future<String?> getSessionUserId() async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        return prefs.getString(_keyUserId) ?? _fallbackUserId;
      }
      return _fallbackUserId;
    } catch (e) {
      print("SharedPreferences fallback active: $e");
      return _fallbackUserId;
    }
  }

  Future<UserRole?> getSessionUserRole() async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        final roleStr = prefs.getString(_keyUserRole);
        if (roleStr == null) return _fallbackUserRole;
        return UserRole.values.firstWhere((e) => e.name == roleStr, orElse: () => UserRole.user);
      }
      return _fallbackUserRole;
    } catch (e) {
      print("SharedPreferences fallback active: $e");
      return _fallbackUserRole;
    }
  }

  // --- CUSTOM AUTHENTICATION REPOSITORY ---
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
    required String securityQuestion,
    required String securityAnswer,
    required String profilePic,
  }) async {
    final salt = BCrypt.gensalt();
    final passwordHash = BCrypt.hashpw(password, salt);

    if (isFirebaseAvailable) {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uidName = credential.user?.uid ?? _buildPathKey('usr_${DateTime.now().millisecondsSinceEpoch}', name);
      final user = UserModel(
        uid: uidName,
        name: name,
        email: email,
        phone: phone,
        passwordHash: passwordHash,
        securityQuestion: securityQuestion,
        securityAnswer: securityAnswer,
        profilePic: profilePic.isEmpty ? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150' : profilePic,
        bio: '',
        role: role,
      );

      await FirebaseDatabase.instance.ref('seva/users/$uidName').set(user.toJson());

      if (role == UserRole.temple) {
        await FirebaseDatabase.instance.ref('seva/temples/$uidName').set({
          'name': name,
          'description': 'Welcome to $name. Add a detailed description.',
          'address': 'Address Details',
          'contact': phone,
          'profileImage': user.profilePic,
          'coverImage': 'https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=600',
          'galleryImages': [user.profilePic],
          'ownerUid': uidName,
          'activePriests': {},
        });
      } else if (role == UserRole.priest) {
        await FirebaseDatabase.instance.ref('seva/priests/$uidName').set({
          'name': name,
          'dob': '1990-01-01',
          'age': 36,
          'gender': 'Male',
          'mobile': phone,
          'email': email,
          'address': 'Sandalwood Street',
          'experience': '5 Years',
          'rasi': 'Mesha',
          'nakshatra': 'Aswini',
          'lagnam': 'Mesha',
          'bio': 'Spiritual Priest assisting in all family prayers.',
          'photo': user.profilePic,
        });
      }

      await saveSession(uidName, role);
      return user;
    } else {
      final rawUid = 'mock_usr_${DateTime.now().millisecondsSinceEpoch}';
      final uidName = _buildPathKey(rawUid, name);
      final user = UserModel(
        uid: uidName,
        name: name,
        email: email,
        phone: phone,
        passwordHash: passwordHash,
        securityQuestion: securityQuestion,
        securityAnswer: securityAnswer,
        profilePic: profilePic.isEmpty ? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150' : profilePic,
        bio: '',
        role: role,
      );

      _mockUsers[uidName] = user;
      _mockCurrentUser = user;

      if (role == UserRole.temple) {
        _mockTemples[uidName] = TempleModel(
          id: uidName,
          name: name,
          description: 'A beautiful temple of prayers.',
          address: 'Main Town',
          contact: phone,
          profileImage: user.profilePic,
          coverImage: 'https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=600',
          galleryImages: [user.profilePic],
          ownerUid: uidName,
          activePriests: {},
        );
      } else if (role == UserRole.priest) {
        _mockPriests[uidName] = PriestModel(
          id: uidName,
          name: name,
          dob: '1990-01-01',
          age: 36,
          gender: 'Male',
          mobile: phone,
          email: email,
          address: 'Main Town',
          experience: '5 Years',
          rasi: 'Mesha',
          nakshatra: 'Aswini',
          lagnam: 'Mesha',
          bio: 'Priest specialized in sacred rites.',
          photo: user.profilePic,
        );
      }

      await saveSession(uidName, role);
      return user;
    }
  }

  Future<UserModel> signIn({required String email, required String password}) async {
    if (isFirebaseAvailable) {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw Exception('Invalid email or password.');
      }
      final profile = await _getUserProfileByUid(uid);
      if (profile == null) {
        await FirebaseAuth.instance.signOut();
        throw Exception('USER_NOT_FOUND:Devotee profile not found for this account.');
      }
      await saveSession(uid, profile.role);
      return profile;
    } else {
      UserModel? found;
      for (var u in _mockUsers.values) {
        if (u.email.toLowerCase() == email.toLowerCase()) {
          found = u;
          break;
        }
      }

      if (found != null && BCrypt.checkpw(password, found.passwordHash)) {
        _mockCurrentUser = found;
        await saveSession(found.uid, found.role);
        return found;
      }
      throw Exception('Invalid email or password.');
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final sessionUid = await getSessionUserId();
    if (isFirebaseAvailable) {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) return null;
      final uid = authUser.uid;
      return _getUserProfileByUid(uid);
    } else {
      if (sessionUid == null) return null;
      _mockCurrentUser = _mockUsers[sessionUid];
      return _mockCurrentUser;
    }
  }

  Future<String?> getSecurityQuestion(String email) async {
    if (isFirebaseAvailable) {
      final snapshot = await FirebaseDatabase.instance
          .ref('seva/users')
          .orderByChild('email')
          .equalTo(email)
          .get();
      if (snapshot.exists && snapshot.value is Map) {
        final map = snapshot.value as Map;
        for (var val in map.values) {
          if (val is Map && val['email']?.toString().toLowerCase().trim() == email.toLowerCase().trim()) {
            return val['securityQuestion']?.toString();
          }
        }
      }
      return null;
    } else {
      for (var u in _mockUsers.values) {
        if (u.email.toLowerCase() == email.toLowerCase()) {
          return u.securityQuestion;
        }
      }
      return null;
    }
  }

  Future<void> resetPassword({required String email, required String securityAnswer, required String newPassword}) async {
    final salt = BCrypt.gensalt();
    final newHash = BCrypt.hashpw(newPassword, salt);

    if (isFirebaseAvailable) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return;
    } else {
      UserModel? found;
      for (var u in _mockUsers.values) {
        if (u.email.toLowerCase() == email.toLowerCase()) {
          found = u;
          break;
        }
      }

      if (found != null && found.securityAnswer.toLowerCase().trim() == securityAnswer.toLowerCase().trim()) {
        _mockUsers[found.uid] = UserModel(
          uid: found.uid,
          name: found.name,
          email: found.email,
          phone: found.phone,
          passwordHash: newHash,
          securityQuestion: found.securityQuestion,
          securityAnswer: found.securityAnswer,
          profilePic: found.profilePic,
          bio: found.bio,
          role: found.role,
        );
        return;
      }
      throw Exception('Security answer verification failed.');
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    if (isFirebaseAvailable) {
      await FirebaseDatabase.instance.ref('seva/users/${user.uid}').update(user.toJson());
    } else {
      _mockUsers[user.uid] = user;
      if (_mockCurrentUser?.uid == user.uid) {
        _mockCurrentUser = user;
      }
    }
  }

  // --- FAMILY PROFILES COLLECTION ---
  Stream<List<FamilyProfileModel>> getFamilyProfilesStream(String userId) {
    if (isFirebaseAvailable) {
      return FirebaseDatabase.instance.ref('seva/family_profiles/$userId').onValue.map((event) {
        final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
        if (data == null) return [];
        return data.entries.map((e) => FamilyProfileModel.fromJson(e.value as Map, e.key.toString())).toList();
      });
    } else {
      final list = _mockFamily.entries
          .where((e) => e.key.startsWith('${userId}_'))
          .map((e) => e.value)
          .toList();
      scheduleMicrotask(() => _familyController.add(list));
      return _familyController.stream;
    }
  }

  Future<void> addFamilyMember(String userId, FamilyProfileModel member) async {
    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/family_profiles/$userId').push();
      final newMember = FamilyProfileModel(
        id: ref.key!,
        name: member.name,
        dob: member.dob,
        age: member.age,
        gender: member.gender,
        rasi: member.rasi,
        nakshatra: member.nakshatra,
        lagnam: member.lagnam,
        gothram: member.gothram,
        relationship: member.relationship,
        profilePhoto: member.profilePhoto,
      );
      await ref.set(newMember.toJson());
    } else {
      final id = 'fam_${DateTime.now().millisecondsSinceEpoch}';
      final newMember = FamilyProfileModel(
        id: id,
        name: member.name,
        dob: member.dob,
        age: member.age,
        gender: member.gender,
        rasi: member.rasi,
        nakshatra: member.nakshatra,
        lagnam: member.lagnam,
        gothram: member.gothram,
        relationship: member.relationship,
        profilePhoto: member.profilePhoto,
      );
      _mockFamily['${userId}_$id'] = newMember;
      
      final list = _mockFamily.entries
          .where((e) => e.key.startsWith('${userId}_'))
          .map((e) => e.value)
          .toList();
      _familyController.add(list);
    }
  }

  // --- TEMPLES API ---
  Stream<List<TempleModel>> getTemplesStream() {
    if (isFirebaseAvailable) {
      return FirebaseDatabase.instance.ref('seva/temples').onValue.map((event) {
        final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
        if (data == null) return [];
        return data.entries.map((e) => TempleModel.fromJson(e.value as Map, e.key.toString())).toList();
      });
    } else {
      scheduleMicrotask(() => _templesController.add(_mockTemples.values.toList()));
      return _templesController.stream;
    }
  }

  Future<void> updateTemple(TempleModel temple) async {
    if (isFirebaseAvailable) {
      await FirebaseDatabase.instance.ref('seva/temples/${temple.id}').update(temple.toJson());
    } else {
      _mockTemples[temple.id] = temple;
      _templesController.add(_mockTemples.values.toList());
    }
  }

  // --- PRIESTS API ---
  Stream<List<PriestModel>> getPriestsStream() {
    if (isFirebaseAvailable) {
      return FirebaseDatabase.instance.ref('seva/priests').onValue.map((event) {
        final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
        if (data == null) return [];
        return data.entries.map((e) => PriestModel.fromJson(e.value as Map, e.key.toString())).toList();
      });
    } else {
      scheduleMicrotask(() => _priestsController.add(_mockPriests.values.toList()));
      return _priestsController.stream;
    }
  }

  Future<void> updatePriest(PriestModel priest) async {
    if (isFirebaseAvailable) {
      await FirebaseDatabase.instance.ref('seva/priests/${priest.id}').update(priest.toJson());
    } else {
      _mockPriests[priest.id] = priest;
      _priestsController.add(_mockPriests.values.toList());
    }
  }

  // --- SERVICES API ---
  Stream<List<ServiceModel>> getServicesStream() {
    if (isFirebaseAvailable) {
      return FirebaseDatabase.instance.ref('seva/services').onValue.map((event) {
        final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
        if (data == null) return [];
        return data.entries.map((e) => ServiceModel.fromJson(e.value as Map, e.key.toString())).toList();
      });
    } else {
      scheduleMicrotask(() => _servicesController.add(_mockServices.values.toList()));
      return _servicesController.stream;
    }
  }

  Future<void> addService(ServiceModel service) async {
    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/services').push();
      final key = _buildPathKey(ref.key!, service.name);
      final newService = ServiceModel(
        id: key,
        templeId: service.templeId,
        priestId: service.priestId,
        name: service.name,
        description: service.description,
        amount: service.amount,
        maxParticipants: service.maxParticipants,
        duration: service.duration,
        image: service.image,
      );
      await FirebaseDatabase.instance.ref('seva/services/$key').set(newService.toJson());
    } else {
      final rawId = 'srv_${DateTime.now().millisecondsSinceEpoch}';
      final key = _buildPathKey(rawId, service.name);
      final newService = ServiceModel(
        id: key,
        templeId: service.templeId,
        priestId: service.priestId,
        name: service.name,
        description: service.description,
        amount: service.amount,
        maxParticipants: service.maxParticipants,
        duration: service.duration,
        image: service.image,
      );
      _mockServices[key] = newService;
      _servicesController.add(_mockServices.values.toList());
    }
  }

  // --- ORDERS API ---
  Stream<List<OrderModel>> getOrdersStream(String id, UserRole role) {
    if (isFirebaseAvailable) {
      var query = FirebaseDatabase.instance.ref('seva/orders');
      if (role == UserRole.user) {
        return query.orderByChild('userId').equalTo(id).onValue.map((event) {
          final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
          if (data == null) return [];
          return data.entries.map((e) => OrderModel.fromJson(e.value as Map, e.key.toString())).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      } else if (role == UserRole.temple) {
        return query.orderByChild('templeId').equalTo(id).onValue.map((event) {
          final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
          if (data == null) return [];
          return data.entries.map((e) => OrderModel.fromJson(e.value as Map, e.key.toString())).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      } else {
        return query.orderByChild('assignedPriest').equalTo(id).onValue.map((event) {
          final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
          if (data == null) return [];
          return data.entries.map((e) => OrderModel.fromJson(e.value as Map, e.key.toString())).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      }
    } else {
      List<OrderModel> list = [];
      if (role == UserRole.user) {
        list = _mockOrders.values.where((o) => o.userId == id).toList();
      } else if (role == UserRole.temple) {
        list = _mockOrders.values.where((o) => o.templeId == id).toList();
      } else {
        list = _mockOrders.values.where((o) => o.assignedPriest == id || o.priestId == id).toList();
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      scheduleMicrotask(() => _ordersController.add(list));
      return _ordersController.stream;
    }
  }

  Future<void> createOrder(OrderModel order) async {
    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/orders').push();
      final newOrder = OrderModel(
        id: ref.key!,
        userId: order.userId,
        userName: order.userName,
        templeId: order.templeId,
        templeName: order.templeName,
        priestId: order.priestId,
        serviceId: order.serviceId,
        serviceName: order.serviceName,
        assignedPriest: order.assignedPriest,
        assignedPriestName: order.assignedPriestName,
        bookingDate: order.bookingDate,
        bookingTime: order.bookingTime,
        amount: order.amount,
        status: order.status,
        paymentStatus: order.paymentStatus,
        paymentReference: order.paymentReference,
        jitsiLink: order.jitsiLink,
        createdAt: order.createdAt,
        participants: order.participants,
      );
      await ref.set(newOrder.toJson());
    } else {
      final id = 'ord_${DateTime.now().millisecondsSinceEpoch}';
      final newOrder = OrderModel(
        id: id,
        userId: order.userId,
        userName: order.userName,
        templeId: order.templeId,
        templeName: order.templeName,
        priestId: order.priestId,
        serviceId: order.serviceId,
        serviceName: order.serviceName,
        assignedPriest: order.assignedPriest,
        assignedPriestName: order.assignedPriestName,
        bookingDate: order.bookingDate,
        bookingTime: order.bookingTime,
        amount: order.amount,
        status: order.status,
        paymentStatus: order.paymentStatus,
        paymentReference: order.paymentReference,
        jitsiLink: order.jitsiLink,
        createdAt: order.createdAt,
        participants: order.participants,
      );
      _mockOrders[id] = newOrder;
      
      final sessionUid = await getSessionUserId();
      final sessionRole = await getSessionUserRole();
      if (sessionUid != null && sessionRole != null) {
        List<OrderModel> list = [];
        if (sessionRole == UserRole.user) {
          list = _mockOrders.values.where((o) => o.userId == sessionUid).toList();
        } else if (sessionRole == UserRole.temple) {
          list = _mockOrders.values.where((o) => o.templeId == sessionUid).toList();
        } else {
          list = _mockOrders.values.where((o) => o.assignedPriest == sessionUid || o.priestId == sessionUid).toList();
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _ordersController.add(list);
      }
    }
  }

  Future<void> updateOrder(OrderModel order) async {
    if (isFirebaseAvailable) {
      await FirebaseDatabase.instance.ref('seva/orders/${order.id}').update(order.toJson());
    } else {
      _mockOrders[order.id] = order;
      final sessionUid = await getSessionUserId();
      final sessionRole = await getSessionUserRole();
      if (sessionUid != null && sessionRole != null) {
        List<OrderModel> list = [];
        if (sessionRole == UserRole.user) {
          list = _mockOrders.values.where((o) => o.userId == sessionUid).toList();
        } else if (sessionRole == UserRole.temple) {
          list = _mockOrders.values.where((o) => o.templeId == sessionUid).toList();
        } else {
          list = _mockOrders.values.where((o) => o.assignedPriest == sessionUid || o.priestId == sessionUid).toList();
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _ordersController.add(list);
      }
    }
  }

  // --- SOCIAL FEED API ---
  Stream<List<PostModel>> getPostsStream() {
    if (isFirebaseAvailable) {
      return FirebaseDatabase.instance.ref('seva/posts').onValue.map((event) {
        final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
        if (data == null) return [];
        return data.entries.map((e) => PostModel.fromJson(e.value as Map, e.key.toString())).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
    } else {
      scheduleMicrotask(() => _postsController.add(_mockPosts.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp))));
      return _postsController.stream;
    }
  }

  Future<void> createPost(PostModel post) async {
    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/posts').push();
      final newPost = PostModel(
        id: ref.key!,
        authorId: post.authorId,
        authorName: post.authorName,
        authorImage: post.authorImage,
        imageUrl: post.imageUrl,
        videoUrl: post.videoUrl,
        caption: post.caption,
        timestamp: post.timestamp,
      );
      await ref.set(newPost.toJson());
    } else {
      final id = 'pst_${DateTime.now().millisecondsSinceEpoch}';
      final newPost = PostModel(
        id: id,
        authorId: post.authorId,
        authorName: post.authorName,
        authorImage: post.authorImage,
        imageUrl: post.imageUrl,
        videoUrl: post.videoUrl,
        caption: post.caption,
        timestamp: post.timestamp,
      );
      _mockPosts[id] = newPost;
      _postsController.add(_mockPosts.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
    }
  }

  // --- LIKES API ---
  Future<void> toggleLike(String postId, String userId) async {
    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/likes/$postId/$userId');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        await ref.remove();
      } else {
        await ref.set(true);
      }
    } else {
      final postLikes = _mockLikes[postId] ?? {};
      if (postLikes[userId] == true) {
        postLikes.remove(userId);
      } else {
        postLikes[userId] = true;
      }
      _mockLikes[postId] = postLikes;
    }
  }

  Future<int> getLikesCount(String postId) async {
    if (isFirebaseAvailable) {
      final snapshot = await FirebaseDatabase.instance.ref('seva/likes/$postId').get();
      if (snapshot.exists && snapshot.value is Map) {
        return (snapshot.value as Map).length;
      }
      return 0;
    } else {
      return (_mockLikes[postId] ?? {}).length;
    }
  }

  Future<bool> hasLiked(String postId, String userId) async {
    if (isFirebaseAvailable) {
      final snapshot = await FirebaseDatabase.instance.ref('seva/likes/$postId/$userId').get();
      return snapshot.exists;
    } else {
      return (_mockLikes[postId] ?? {})[userId] == true;
    }
  }

  // --- COMMENTS API ---
  Future<List<CommentModel>> getComments(String postId) async {
    if (isFirebaseAvailable) {
      final snapshot = await FirebaseDatabase.instance.ref('seva/comments/$postId').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        return data.entries.map((e) => CommentModel.fromJson(e.value as Map, e.key.toString())).toList();
      }
      return [];
    } else {
      return _mockComments[postId] ?? [];
    }
  }

  Future<void> addComment(CommentModel comment) async {
    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/comments/${comment.postId}').push();
      final newComment = CommentModel(
        id: ref.key!,
        postId: comment.postId,
        userId: comment.userId,
        userName: comment.userName,
        content: comment.content,
        timestamp: comment.timestamp,
      );
      await ref.set(newComment.toJson());
    } else {
      final id = 'cmt_${DateTime.now().millisecondsSinceEpoch}';
      final newComment = CommentModel(
        id: id,
        postId: comment.postId,
        userId: comment.userId,
        userName: comment.userName,
        content: comment.content,
        timestamp: comment.timestamp,
      );
      final list = _mockComments[comment.postId] ?? [];
      list.add(newComment);
      _mockComments[comment.postId] = list;
    }
  }

  // --- NOTIFICATIONS API ---
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    if (isFirebaseAvailable) {
      return FirebaseDatabase.instance.ref('seva/notifications/$userId').onValue.map((event) {
        final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
        if (data == null) return [];
        return data.entries.map((e) => NotificationModel.fromJson(e.value as Map, e.key.toString())).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
    } else {
      final list = _mockNotifications[userId] ?? [];
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      scheduleMicrotask(() => _notificationsController.add(list));
      return _notificationsController.stream;
    }
  }

  Future<void> createNotification(String userId, String title, String body, String type) async {
    final notification = NotificationModel(
      id: '',
      title: title,
      body: body,
      type: type,
      read: false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/notifications/$userId').push();
      await ref.set(notification.toJson());
    } else {
      final id = 'not_${DateTime.now().millisecondsSinceEpoch}';
      final newNot = NotificationModel(
        id: id,
        title: title,
        body: body,
        type: type,
        read: false,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      final list = _mockNotifications[userId] ?? [];
      list.add(newNot);
      _mockNotifications[userId] = list;
      _notificationsController.add(list);
    }
  }

  Future<void> markNotificationsRead(String userId) async {
    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/notifications/$userId');
      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        for (var key in data.keys) {
          await ref.child('$key/read').set(true);
        }
      }
    } else {
      final list = _mockNotifications[userId] ?? [];
      final updated = list.map((n) => NotificationModel(
        id: n.id,
        title: n.title,
        body: n.body,
        type: n.type,
        read: true,
        timestamp: n.timestamp,
      )).toList();
      _mockNotifications[userId] = updated;
      _notificationsController.add(updated);
    }
  }

  // --- SAVED POSTS API ---
  Future<void> toggleBookmark(String userId, String postId) async {
    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/saved_posts/$userId/$postId');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        await ref.remove();
      } else {
        await ref.set(true);
      }
    } else {
      final userSaved = _mockSavedPosts[userId] ?? {};
      if (userSaved[postId] == true) {
        userSaved.remove(postId);
      } else {
        userSaved[postId] = true;
      }
      _mockSavedPosts[userId] = userSaved;
    }
  }

  Future<bool> isBookmarked(String userId, String postId) async {
    if (isFirebaseAvailable) {
      final snapshot = await FirebaseDatabase.instance.ref('seva/saved_posts/$userId/$postId').get();
      return snapshot.exists;
    } else {
      return (_mockSavedPosts[userId] ?? {})[postId] == true;
    }
  }

  Future<List<String>> getSavedPostIds(String userId) async {
    if (isFirebaseAvailable) {
      final snapshot = await FirebaseDatabase.instance.ref('seva/saved_posts/$userId').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        return data.keys.map((k) => k.toString()).toList();
      }
      return [];
    } else {
      return (_mockSavedPosts[userId] ?? {}).keys.toList();
    }
  }

  // --- REPORTS API ---
  Future<void> reportPost(String userId, String postId) async {
    if (isFirebaseAvailable) {
      await FirebaseDatabase.instance.ref('seva/reports/$postId/$userId').set(true);
      await FirebaseDatabase.instance.ref('seva/user_reports/$userId/$postId').set(true);
    } else {
      final reports = _mockReports[postId] ?? {};
      reports[userId] = true;
      _mockReports[postId] = reports;

      final userReports = _mockUserReports[userId] ?? {};
      userReports[postId] = true;
      _mockUserReports[userId] = userReports;
    }
  }

  Future<List<String>> getReportedPostIds(String userId) async {
    if (isFirebaseAvailable) {
      final snapshot = await FirebaseDatabase.instance.ref('seva/user_reports/$userId').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        return data.keys.map((k) => k.toString()).toList();
      }
      return [];
    } else {
      return (_mockUserReports[userId] ?? {}).keys.toList();
    }
  }


  Future<void> createPriestAccountByTemple({
    required String templeId,
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final salt = BCrypt.gensalt();
    final passwordHash = BCrypt.hashpw(password, salt);
    final rawUid = 'usr_priest_${DateTime.now().millisecondsSinceEpoch}';
    final uidName = _buildPathKey(rawUid, name);

    final user = UserModel(
      uid: uidName,
      name: name,
      email: email,
      phone: phone,
      passwordHash: passwordHash,
      securityQuestion: 'What is your birth city?',
      securityAnswer: 'temple_created',
      profilePic: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150',
      bio: 'Priest added by temple.',
      role: UserRole.priest,
    );

    final priest = PriestModel(
      id: uidName,
      name: name,
      dob: '1990-01-01',
      age: 36,
      gender: 'Male',
      mobile: phone,
      email: email,
      address: 'Temple Campus',
      experience: '5 Years',
      rasi: 'Mesha',
      nakshatra: 'Aswini',
      lagnam: 'Mesha',
      bio: 'Spiritual Priest assisting in all family prayers.',
      photo: user.profilePic,
    );

    if (isFirebaseAvailable) {
      // Create user auth profile
      await FirebaseDatabase.instance.ref('seva/users/$uidName').set(user.toJson());
      // Create priest profile
      await FirebaseDatabase.instance.ref('seva/priests/$uidName').set(priest.toJson());
      // Add priest to temple's activePriests
      await FirebaseDatabase.instance.ref('seva/temples/$templeId/activePriests/$uidName').set('accepted');
    } else {
      _mockUsers[uidName] = user;
      _mockPriests[uidName] = priest;
      final temple = _mockTemples[templeId];
      if (temple != null) {
        final updatedPriests = Map<String, String>.from(temple.activePriests);
        updatedPriests[uidName] = 'accepted';
        _mockTemples[templeId] = TempleModel(
          id: temple.id,
          name: temple.name,
          description: temple.description,
          address: temple.address,
          contact: temple.contact,
          profileImage: temple.profileImage,
          coverImage: temple.coverImage,
          galleryImages: temple.galleryImages,
          ownerUid: temple.ownerUid,
          activePriests: updatedPriests,
        );
        _templesController.add(_mockTemples.values.toList());
      }
      _priestsController.add(_mockPriests.values.toList());
    }
  }

  // --- MOCK SEED INITIALIZER HELPER FOR REAL DATABASE ---
  Future<bool> isDatabaseSeeded() async {
    if (isFirebaseAvailable) {
      final snapshot = await FirebaseDatabase.instance.ref('seva/system/seeded').get();
      return snapshot.value == true;
    } else {
      return false; // Seeder can run locally always
    }
  }

  Future<void> setDatabaseSeeded() async {
    if (isFirebaseAvailable) {
      await FirebaseDatabase.instance.ref('seva/system/seeded').set(true);
    }
  }

  void seedOfflineMockData() {
    if (_mockUsers.isNotEmpty) return; // already seeded

    final salt = BCrypt.gensalt();
    final hash = BCrypt.hashpw("123456", salt);

    // Users
    final uMuthu = UserModel(
      uid: "usr_muthu",
      name: "Muthu Kumaran",
      email: "muthu@gmail.com",
      phone: "9876543210",
      passwordHash: hash,
      securityQuestion: "What is your birth city?",
      securityAnswer: "Madurai",
      profilePic: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150",
      bio: "Spiritual seeker and devotee.",
      role: UserRole.user,
    );
    _mockUsers[uMuthu.uid] = uMuthu;

    final uGanesan = UserModel(
      uid: "usr_ganesan",
      name: "Ganesan",
      email: "ganesan@gmail.com",
      phone: "9876543211",
      passwordHash: hash,
      securityQuestion: "What is your birth city?",
      securityAnswer: "Madurai",
      profilePic: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150",
      bio: "Regular temple visitor.",
      role: UserRole.user,
    );
    _mockUsers[uGanesan.uid] = uGanesan;

    final uKumaran = UserModel(
      uid: "usr_kumaran",
      name: "Kumaran",
      email: "kumaran@gmail.com",
      phone: "9876543212",
      passwordHash: hash,
      securityQuestion: "What is your birth city?",
      securityAnswer: "Madurai",
      profilePic: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150",
      bio: "Devotee and volunteer.",
      role: UserRole.user,
    );
    _mockUsers[uKumaran.uid] = uKumaran;

    // Temple Admins
    final adminMeenakshi = UserModel(
      uid: "admin_meenakshi",
      name: "Meenakshi Amman Admin",
      email: "meenakshi_admin@gmail.com",
      phone: "9876543201",
      passwordHash: hash,
      securityQuestion: "What is your pet name?",
      securityAnswer: "Meena",
      profilePic: "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=150",
      bio: "Administrator for Meenakshi Temple.",
      role: UserRole.temple,
    );
    _mockUsers[adminMeenakshi.uid] = adminMeenakshi;

    final adminPillayar = UserModel(
      uid: "admin_pillayar",
      name: "Pillayar Patti Admin",
      email: "pillayarpatti_admin@gmail.com",
      phone: "9876543202",
      passwordHash: hash,
      securityQuestion: "What is your pet name?",
      securityAnswer: "Karpaka",
      profilePic: "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=150",
      bio: "Administrator for Pillayar Patti Temple.",
      role: UserRole.temple,
    );
    _mockUsers[adminPillayar.uid] = adminPillayar;

    final adminThiruparam = UserModel(
      uid: "admin_thiruparam",
      name: "Thiruparamkundram Admin",
      email: "thiruparam_admin@gmail.com",
      phone: "9876543203",
      passwordHash: hash,
      securityQuestion: "What is your pet name?",
      securityAnswer: "Muruga",
      profilePic: "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=150",
      bio: "Administrator for Thiruparamkundram Temple.",
      role: UserRole.temple,
    );
    _mockUsers[adminThiruparam.uid] = adminThiruparam;

    // Temples
    _mockTemples["admin_meenakshi"] = TempleModel(
      id: "admin_meenakshi",
      name: "Meenakshi Amman Temple",
      description: "Historic Hindu temple located on the southern bank of the Vaigai River in Madurai, Tamil Nadu.",
      address: "Madurai, Tamil Nadu 625001",
      contact: "9876543201",
      profileImage: "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=200",
      coverImage: "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=800",
      galleryImages: ["https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=200"],
      ownerUid: "admin_meenakshi",
      activePriests: {
        "priest_prassana": "accepted",
        "priest_mukuntha": "accepted",
      },
    );

    _mockTemples["admin_pillayar"] = TempleModel(
      id: "admin_pillayar",
      name: "Pillayar Patti Temple",
      description: "Ancient rock-cut cave temple dedicated to Karpaka Vinayagar in Tiruppathur, Tamil Nadu.",
      address: "Pillayarpatti, Tamil Nadu 630207",
      contact: "9876543202",
      profileImage: "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=200",
      coverImage: "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=800",
      galleryImages: ["https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=200"],
      ownerUid: "admin_pillayar",
      activePriests: {
        "priest_vengadesh": "accepted",
        "priest_madesh": "accepted",
      },
    );

    _mockTemples["admin_thiruparam"] = TempleModel(
      id: "admin_thiruparam",
      name: "Thiruparamkundram Murugan Temple",
      description: "One of the Six Abodes of Lord Murugan, carved in rock, situated at Thirupparankundram, Madurai.",
      address: "Thirupparankundram, Madurai, Tamil Nadu 625005",
      contact: "9876543203",
      profileImage: "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=200",
      coverImage: "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=800",
      galleryImages: ["https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=200"],
      ownerUid: "admin_thiruparam",
      activePriests: {
        "priest_gokul": "accepted",
        "priest_arun": "accepted",
      },
    );

    // Priests
    final priestsData = {
      "priest_prassana": {
        "name": "Prassana Gurukkal",
        "email": "prassana@gmail.com",
        "mobile": "9876543001",
        "experience": "12 Years",
        "rasi": "Mesha",
        "nakshatra": "Aswini",
        "lagnam": "Mesha",
        "bio": "Specialist in Meenakshi Amman pujas and sacred wedding rituals.",
        "photo": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150",
      },
      "priest_mukuntha": {
        "name": "Mukuntha Gurukkal",
        "email": "mukuntha@gmail.com",
        "mobile": "9876543002",
        "experience": "15 Years",
        "rasi": "Rishaba",
        "nakshatra": "Rohini",
        "lagnam": "Rishaba",
        "bio": "Senior Vedic scholar performing Lakshmi Homam and Abhishekam.",
        "photo": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=150",
      },
      "priest_vengadesh": {
        "name": "Vengadesh Bhattar",
        "email": "vengadesh@gmail.com",
        "mobile": "9876543003",
        "experience": "10 Years",
        "rasi": "Mithuna",
        "nakshatra": "Arudra",
        "lagnam": "Mithuna",
        "bio": "Specialist in Karpaka Vinayagar Abhishekam and Vinayagar Chaturthi special homams.",
        "photo": "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?q=80&w=150",
      },
      "priest_madesh": {
        "name": "Madesh Bhattar",
        "email": "madesh@gmail.com",
        "mobile": "9876543004",
        "experience": "8 Years",
        "rasi": "Karka",
        "nakshatra": "Punarvasu",
        "lagnam": "Karka",
        "bio": "Vedic rituals coordinator and home puja practitioner.",
        "photo": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=150",
      },
      "priest_gokul": {
        "name": "Gokul Gurukkal",
        "email": "gokul@gmail.com",
        "mobile": "9876543005",
        "experience": "14 Years",
        "rasi": "Simha",
        "nakshatra": "Magha",
        "lagnam": "Simha",
        "bio": "Specialist in Shanmuga Archana and Murugan Abhishekam.",
        "photo": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150",
      },
      "priest_arun": {
        "name": "Arun Gurukkal",
        "email": "arun@gmail.com",
        "mobile": "9876543006",
        "experience": "6 Years",
        "rasi": "Kanya",
        "nakshatra": "Uttara",
        "lagnam": "Kanya",
        "bio": "Assists in all Murugan temple services and special festival events.",
        "photo": "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?q=80&w=150",
      },
    };

    priestsData.forEach((id, p) {
      _mockPriests[id] = PriestModel(
        id: id,
        name: p["name"]!,
        dob: "1985-01-01",
        age: 41,
        gender: "Male",
        mobile: p["mobile"]!,
        email: p["email"]!,
        address: "Temple Campus",
        experience: p["experience"]!,
        rasi: p["rasi"]!,
        nakshatra: p["nakshatra"]!,
        lagnam: p["lagnam"]!,
        bio: p["bio"]!,
        photo: p["photo"]!,
      );

      _mockUsers[id] = UserModel(
        uid: id,
        name: p["name"]!,
        email: p["email"]!,
        phone: p["mobile"]!,
        passwordHash: hash,
        securityQuestion: "What is your birth city?",
        securityAnswer: "Madurai",
        profilePic: p["photo"]!,
        bio: p["bio"]!,
        role: UserRole.priest,
      );
    });

    // Services
    final servicesList = [
      ServiceModel(id: "srv_meenakshi_1", templeId: "admin_meenakshi", priestId: "", name: "Meenakshi Amman Maha Archana", description: "Comprehensive offering with flower petals and coconuts.", amount: 100.0, maxParticipants: 20, duration: "20 Mins", image: "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=200"),
      ServiceModel(id: "srv_meenakshi_2", templeId: "admin_meenakshi", priestId: "", name: "Special Abhishekam", description: "Bathing of deities with milk, honey and sandalwood.", amount: 1500.0, maxParticipants: 5, duration: "1 Hour", image: "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=200"),
      ServiceModel(id: "srv_pillayar_1", templeId: "admin_pillayar", priestId: "", name: "Ganapathy Homam", description: "Auspicious fire ritual seeking obstacles removal.", amount: 2500.0, maxParticipants: 10, duration: "2 Hours", image: "https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?q=80&w=200"),
      ServiceModel(id: "srv_pillayar_2", templeId: "admin_pillayar", priestId: "", name: "Karpaka Vinayagar Archana", description: "Simple archana for family blessings.", amount: 50.0, maxParticipants: 50, duration: "10 Mins", image: "https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=200"),
      ServiceModel(id: "srv_thiruparam_1", templeId: "admin_thiruparam", priestId: "", name: "Subramanya Sahasranama Archana", description: "Chanting of 1000 names of Lord Murugan.", amount: 200.0, maxParticipants: 15, duration: "30 Mins", image: "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=200"),
      ServiceModel(id: "srv_thiruparam_2", templeId: "admin_thiruparam", priestId: "", name: "Special Kavadi Puja", description: "Pooja for devotees carrying Kavadi offering.", amount: 1000.0, maxParticipants: 5, duration: "1.5 Hours", image: "https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=200"),
    ];

    for (var s in servicesList) {
      _mockServices[s.id] = s;
    }

    // Posts
    for (var i = 0; i < 5; i++) {
      final id = "mock_post_$i";
      _mockPosts[id] = PostModel(
        id: id,
        authorId: "admin_meenakshi",
        authorName: "Meenakshi Amman Temple",
        authorImage: "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=150",
        imageUrl: "https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=600",
        videoUrl: "",
        caption: "Evening prayers and blessings from Madurai Meenakshi Amman Temple. May peace be with all devotees.",
        timestamp: DateTime.now().subtract(Duration(hours: i * 6)).millisecondsSinceEpoch,
      );
    }
  }

  // --- BOOKED SLOTS COUNTER ---
  Future<int> getSlotBookingCount(String serviceId, String date, String time) async {
    if (isFirebaseAvailable) {
      final snapshot = await FirebaseDatabase.instance
          .ref('seva/booked_slots/$serviceId/$date/$time/bookingCount')
          .get();
      if (snapshot.exists) {
        return int.tryParse(snapshot.value.toString()) ?? 0;
      }
      return 0;
    } else {
      return _mockBookedSlots["$serviceId|$date|$time"] ?? 0;
    }
  }

  Future<void> incrementSlotBookingCount(String serviceId, String date, String time) async {
    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/booked_slots/$serviceId/$date/$time/bookingCount');
      final snapshot = await ref.get();
      int current = 0;
      if (snapshot.exists) {
        current = int.tryParse(snapshot.value.toString()) ?? 0;
      }
      await ref.set(current + 1);
    } else {
      final key = "$serviceId|$date|$time";
      _mockBookedSlots[key] = (_mockBookedSlots[key] ?? 0) + 1;
    }
  }

  Future<void> decrementSlotBookingCount(String serviceId, String date, String time) async {
    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/booked_slots/$serviceId/$date/$time/bookingCount');
      final snapshot = await ref.get();
      int current = 0;
      if (snapshot.exists) {
        current = int.tryParse(snapshot.value.toString()) ?? 0;
      }
      if (current > 0) {
        await ref.set(current - 1);
      }
    } else {
      final key = "$serviceId|$date|$time";
      int val = _mockBookedSlots[key] ?? 0;
      if (val > 0) {
        _mockBookedSlots[key] = val - 1;
      }
    }
  }

  // --- FOLLOW SYSTEM ---
  Future<void> toggleFollow(String userId, String targetId) async {
    if (isFirebaseAvailable) {
      final followingRef = FirebaseDatabase.instance.ref('seva/following/$userId/$targetId');
      final followerRef = FirebaseDatabase.instance.ref('seva/followers/$targetId/$userId');
      final snapshot = await followingRef.get();
      if (snapshot.exists) {
        await followingRef.remove();
        await followerRef.remove();
      } else {
        await followingRef.set(true);
        await followerRef.set(true);
      }
    } else {
      final userFollowing = _mockFollowing[userId] ?? {};
      final targetFollowers = _mockFollowers[targetId] ?? {};
      if (userFollowing[targetId] == true) {
        userFollowing.remove(targetId);
        targetFollowers.remove(userId);
      } else {
        userFollowing[targetId] = true;
        targetFollowers[userId] = true;
      }
      _mockFollowing[userId] = userFollowing;
      _mockFollowers[targetId] = targetFollowers;
    }
  }

  Future<bool> isFollowing(String userId, String targetId) async {
    if (isFirebaseAvailable) {
      final snapshot = await FirebaseDatabase.instance.ref('seva/following/$userId/$targetId').get();
      return snapshot.exists;
    } else {
      return (_mockFollowing[userId] ?? {})[targetId] == true;
    }
  }

  Future<List<String>> getFollowingIds(String userId) async {
    if (isFirebaseAvailable) {
      final snapshot = await FirebaseDatabase.instance.ref('seva/following/$userId').get();
      if (snapshot.exists && snapshot.value is Map) {
        return (snapshot.value as Map).keys.map((k) => k.toString()).toList();
      }
      return [];
    } else {
      return (_mockFollowing[userId] ?? {}).keys.toList();
    }
  }

  // --- UPLOAD TEMPLE GALLERY ---
  Future<void> addTempleGalleryImage(String templeId, String imageUrl) async {
    if (isFirebaseAvailable) {
      final ref = FirebaseDatabase.instance.ref('seva/temples/$templeId');
      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final List gallery = List.from(data['galleryImages'] ?? []);
        gallery.add(imageUrl);
        await ref.child('galleryImages').set(gallery);
      }
    } else {
      final temple = _mockTemples[templeId];
      if (temple != null) {
        final updatedGallery = List<String>.from(temple.galleryImages)..add(imageUrl);
        _mockTemples[templeId] = temple.copyWith(galleryImages: updatedGallery);
        _templesController.add(_mockTemples.values.toList());
      }
    }
  }

  Future<UserModel?> _getUserProfileByUid(String uid) async {
    final snapshot = await FirebaseDatabase.instance.ref('seva/users/$uid').get();
    if (!snapshot.exists || snapshot.value == null) return null;
    final value = snapshot.value;
    if (value is Map) {
      return UserModel.fromJson(value, uid);
    }
    return null;
  }
}
