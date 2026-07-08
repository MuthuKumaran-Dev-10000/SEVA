import 'dart:async';
import 'package:flutter/material.dart';
import '../models/temple_model.dart';
import '../models/priest_model.dart';
import '../models/service_model.dart';
import '../models/order_model.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/notification_model.dart';
import '../models/family_profile_model.dart';
import '../models/user_model.dart';
import '../models/cart_item.dart';
import 'firebase_service.dart';

class AppProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  // Stream Subscriptions
  StreamSubscription? _templesSub;
  StreamSubscription? _priestsSub;
  StreamSubscription? _servicesSub;
  StreamSubscription? _ordersSub;
  StreamSubscription? _postsSub;
  StreamSubscription? _familySub;
  StreamSubscription? _notifSub;

  List<TempleModel> temples = [];
  List<PriestModel> priests = [];
  List<ServiceModel> services = [];
  List<OrderModel> orders = [];
  List<PostModel> posts = [];
  List<FamilyProfileModel> familyMembers = [];
  List<NotificationModel> notifications = [];
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Shopping Cart
  final List<CartItem> _cart = [];
  List<CartItem> get cart => _cart;
  double get cartTotal => _cart.fold(0.0, (sum, item) => sum + (item.service.amount * item.quantity));

  int getQuantity(ServiceModel s) {
    try {
      return _cart.firstWhere((item) => item.service.id == s.id).quantity;
    } catch (_) {
      return 0;
    }
  }

  void addToCart(ServiceModel s, String date, String slot) {
    final idx = _cart.indexWhere((item) => item.service.id == s.id && item.selectedDate == date && item.selectedTimeSlot == slot);
    if (idx != -1) {
      _cart[idx].quantity++;
    } else {
      _cart.add(CartItem(service: s, selectedDate: date, selectedTimeSlot: slot, quantity: 1));
    }
    notifyListeners();
  }

  void removeFromCart(CartItem item) {
    _cart.removeWhere((i) => i.service.id == item.service.id && i.selectedDate == item.selectedDate && i.selectedTimeSlot == item.selectedTimeSlot);
    notifyListeners();
  }

  void incrementQuantity(CartItem item) {
    final idx = _cart.indexWhere((i) => i.service.id == item.service.id && i.selectedDate == item.selectedDate && i.selectedTimeSlot == item.selectedTimeSlot);
    if (idx != -1) {
      _cart[idx].quantity++;
      notifyListeners();
    }
  }

  void decrementQuantity(CartItem item) {
    final idx = _cart.indexWhere((i) => i.service.id == item.service.id && i.selectedDate == item.selectedDate && i.selectedTimeSlot == item.selectedTimeSlot);
    if (idx != -1) {
      if (_cart[idx].quantity > 1) {
        _cart[idx].quantity--;
      } else {
        _cart.removeAt(idx);
      }
      notifyListeners();
    }
  }

  // Backwards compatibility for list views
  void removeFromCartByService(ServiceModel s) {
    _cart.removeWhere((item) => item.service.id == s.id);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  // --- STREAM LISTENERS ---
  void listenAllGlobalData() {
    _templesSub?.cancel();
    _templesSub = _firebaseService.getTemplesStream().listen((list) {
      temples = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error listening to temples: $e");
    });

    _priestsSub?.cancel();
    _priestsSub = _firebaseService.getPriestsStream().listen((list) {
      priests = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error listening to priests: $e");
    });

    _servicesSub?.cancel();
    _servicesSub = _firebaseService.getServicesStream().listen((list) {
      services = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error listening to services: $e");
    });

    _postsSub?.cancel();
    _postsSub = _firebaseService.getPostsStream().listen((list) {
      posts = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error listening to posts: $e");
    });
  }

  void listenUserSessions(String userId, UserRole role) {
    _ordersSub?.cancel();
    _ordersSub = _firebaseService.getOrdersStream(userId, role).listen((list) {
      orders = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error listening to orders: $e");
    });

    _notifSub?.cancel();
    _notifSub = _firebaseService.getNotificationsStream(userId).listen((list) {
      notifications = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error listening to notifications: $e");
    });

    if (role == UserRole.user) {
      _familySub?.cancel();
      _familySub = _firebaseService.getFamilyProfilesStream(userId).listen((list) {
        familyMembers = list;
        notifyListeners();
      }, onError: (e) {
        debugPrint("Error listening to family profiles: $e");
      });
    }
  }

  // --- FAMILY MEMBERS CRUD ---
  Future<void> addFamilyMember(String userId, FamilyProfileModel member) async {
    await _firebaseService.addFamilyMember(userId, member);
  }

  // --- TEMPLE CRUD ---
  Future<void> updateTempleProfile(TempleModel temple) async {
    await _firebaseService.updateTemple(temple);
  }

  // --- PRIEST CRUD ---
  Future<void> updatePriestProfile(PriestModel priest) async {
    await _firebaseService.updatePriest(priest);
  }

  Future<void> createPriestAccountByTemple({
    required String templeId,
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firebaseService.createPriestAccountByTemple(
        templeId: templeId,
        name: name,
        phone: phone,
        email: email,
        password: password,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- SERVICES CRUD ---
  Future<void> createService(ServiceModel service) async {
    await _firebaseService.addService(service);
  }

  // --- ORDER PROCESSING ---
  Future<void> bookCartServices({
    required String userId,
    required String userName,
    required String paymentRef,
    List<String> participants = const [],
  }) async {
    _isLoading = true;
    notifyListeners();

    for (var cartItem in _cart) {
      final service = cartItem.service;
      String resolvedTempleName = 'Spiritual Priest';
      if (service.templeId.isNotEmpty) {
        try {
          resolvedTempleName = temples.firstWhere((t) => t.id == service.templeId).name;
        } catch (_) {}
      }

      for (int i = 0; i < cartItem.quantity; i++) {
        final order = OrderModel(
          id: '',
          userId: userId,
          userName: userName,
          templeId: service.templeId,
          templeName: resolvedTempleName,
          priestId: service.priestId,
          serviceId: service.id,
          serviceName: service.name,
          assignedPriest: service.priestId,
          assignedPriestName: '',
          bookingDate: cartItem.selectedDate,
          bookingTime: cartItem.selectedTimeSlot,
          amount: service.amount,
          status: 'pending',
          paymentStatus: 'success',
          paymentReference: paymentRef,
          jitsiLink: 'https://meet.jit.si/sevasetu_${service.id}_${DateTime.now().millisecondsSinceEpoch}_$i',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          participants: participants,
        );

        await _firebaseService.createOrder(order);
        await _firebaseService.incrementSlotBookingCount(service.id, cartItem.selectedDate, cartItem.selectedTimeSlot);
      }

      // Trigger notifications for booking
      if (service.templeId.isNotEmpty) {
        await _firebaseService.createNotification(
          service.templeId,
          'New Booking Received',
          'A booking for ${service.name} has been placed by devotee $userName.',
          'booking_created',
        );
      } else if (service.priestId.isNotEmpty) {
        await _firebaseService.createNotification(
          service.priestId,
          'New Private Booking',
          'A booking for your private service ${service.name} has been placed by $userName.',
          'booking_created',
        );
      }
    }

    clearCart();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateOrderDetails(OrderModel order) async {
    try {
      final oldOrder = orders.firstWhere((o) => o.id == order.id);
      if (oldOrder.status != 'cancelled' && oldOrder.status != 'declined' && 
          (order.status == 'cancelled' || order.status == 'declined')) {
        await _firebaseService.decrementSlotBookingCount(order.serviceId, order.bookingDate, order.bookingTime);
      } else if (order.status != 'cancelled' && order.status != 'declined' &&
          (oldOrder.bookingDate != order.bookingDate || oldOrder.bookingTime != order.bookingTime)) {
        await _firebaseService.decrementSlotBookingCount(oldOrder.serviceId, oldOrder.bookingDate, oldOrder.bookingTime);
        await _firebaseService.incrementSlotBookingCount(order.serviceId, order.bookingDate, order.bookingTime);
      }
    } catch (_) {}
    await _firebaseService.updateOrder(order);
  }

  Future<void> startLiveSession(OrderModel order) async {
    await updateOrderDetails(order.copyWith(status: 'live_ready'));
    await _firebaseService.createNotification(
      order.userId,
      'Live session is ready',
      'Your ${order.serviceName} is ready. Tap Join Now to enter the meeting.',
      'live_session',
    );
  }

  // --- TEMPLE INVITATIONS ---
  Future<void> invitePriestToTemple(String templeId, String priestId) async {
    // Find temple
    final templeIdx = temples.indexWhere((t) => t.id == templeId);
    if (templeIdx == -1) return; // Temple not found, skip silently
    final temple = temples[templeIdx];
    final updatedPriests = Map<String, String>.from(temple.activePriests);
    updatedPriests[priestId] = 'pending'; // Invite state set to pending

    final updatedTemple = TempleModel(
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

    await _firebaseService.updateTemple(updatedTemple);

    // Send invitation notification to priest
    await _firebaseService.createNotification(
      priestId,
      'Temple Invitation',
      'You have been invited to join the priesthood at ${temple.name}.',
      'invitation_received',
    );
  }

  Future<void> respondToTempleInvitation(String templeId, String priestId, bool accept) async {
    final templeIdx = temples.indexWhere((t) => t.id == templeId);
    if (templeIdx == -1) return;
    final temple = temples[templeIdx];
    final updatedPriests = Map<String, String>.from(temple.activePriests);
    updatedPriests[priestId] = accept ? 'accepted' : 'rejected';

    final updatedTemple = TempleModel(
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

    await _firebaseService.updateTemple(updatedTemple);

    // Notify temple
    await _firebaseService.createNotification(
      templeId,
      accept ? 'Invitation Accepted' : 'Invitation Rejected',
      'Priest response received for your association invitation.',
      'invitation_received',
    );
  }

  // --- SOCIAL FEED ---
  Future<void> addSocialPost(PostModel post) async {
    await _firebaseService.createPost(post);
  }

  Future<void> toggleLike(String postId, String userId) async {
    await _firebaseService.toggleLike(postId, userId);
    notifyListeners();
  }

  Future<int> getPostLikes(String postId) async {
    return await _firebaseService.getLikesCount(postId);
  }

  Future<bool> checkUserLiked(String postId, String userId) async {
    return await _firebaseService.hasLiked(postId, userId);
  }

  Future<List<CommentModel>> getComments(String postId) async {
    return await _firebaseService.getComments(postId);
  }

  Future<void> addComment(CommentModel comment) async {
    await _firebaseService.addComment(comment);
    notifyListeners();
  }

  // --- BOOKMARKS & REPORTS ---
  Future<void> toggleBookmark(String userId, String postId) async {
    await _firebaseService.toggleBookmark(userId, postId);
    notifyListeners();
  }

  Future<bool> checkUserBookmarked(String userId, String postId) async {
    return await _firebaseService.isBookmarked(userId, postId);
  }

  Future<List<String>> getSavedPostIds(String userId) async {
    return await _firebaseService.getSavedPostIds(userId);
  }

  Future<void> reportPost(String userId, String postId) async {
    await _firebaseService.reportPost(userId, postId);
    notifyListeners();
  }

  Future<List<String>> getReportedPostIds(String userId) async {
    return await _firebaseService.getReportedPostIds(userId);
  }

  // --- FOLLOW SYSTEM ---
  Future<void> toggleFollow(String userId, String targetId) async {
    await _firebaseService.toggleFollow(userId, targetId);
    notifyListeners();
  }

  Future<bool> isFollowing(String userId, String targetId) async {
    return await _firebaseService.isFollowing(userId, targetId);
  }

  Future<List<String>> getFollowingIds(String userId) async {
    return await _firebaseService.getFollowingIds(userId);
  }

  // --- GALLERY ---
  Future<void> addTempleGalleryImage(String templeId, String imageUrl) async {
    await _firebaseService.addTempleGalleryImage(templeId, imageUrl);
    notifyListeners();
  }

  // --- CAPACITY CHECKS ---
  Future<int> getSlotBookingCount(String serviceId, String date, String time) async {
    return await _firebaseService.getSlotBookingCount(serviceId, date, time);
  }

  // --- NOTIFICATIONS ---
  Future<void> clearNotifications(String userId) async {
    await _firebaseService.markNotificationsRead(userId);
  }

  @override
  void dispose() {
    _templesSub?.cancel();
    _priestsSub?.cancel();
    _servicesSub?.cancel();
    _ordersSub?.cancel();
    _postsSub?.cancel();
    _familySub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }
}
