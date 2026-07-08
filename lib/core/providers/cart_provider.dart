import 'package:flutter/material.dart';
import '../api_client.dart';
import 'auth_provider.dart';

class CartItem {
  final int templeId;
  final String templeName;
  final int serviceId;
  final String serviceName;
  final double price;
  String bookingDate; // YYYY-MM-DD
  String slotTime;    // HH:MM
  String attendeeName;

  CartItem({
    required this.templeId,
    required this.templeName,
    required this.serviceId,
    required this.serviceName,
    required this.price,
    required this.bookingDate,
    required this.slotTime,
    this.attendeeName = '',
  });

  CartItem copyWith({
    String? bookingDate,
    String? slotTime,
    String? attendeeName,
  }) {
    return CartItem(
      templeId: templeId,
      templeName: templeName,
      serviceId: serviceId,
      serviceName: serviceName,
      price: price,
      bookingDate: bookingDate ?? this.bookingDate,
      slotTime: slotTime ?? this.slotTime,
      attendeeName: attendeeName ?? this.attendeeName,
    );
  }
}

class CartProvider extends ChangeNotifier {
  final ApiClient api;
  final List<CartItem> _items = [];
  bool _isCheckingOut = false;
  String? _errorMessage;

  List<CartItem> get items => _items;
  double get totalPrice => _items.fold(0, (sum, item) => sum + item.price);
  bool get isCheckingOut => _isCheckingOut;
  String? get errorMessage => _errorMessage;

  CartProvider(this.api);

  void addItem({
    required int templeId,
    required String templeName,
    required int serviceId,
    required String serviceName,
    required double price,
  }) {
    // Check if item already exists
    final index = _items.indexWhere((item) => item.serviceId == serviceId);
    if (index == -1) {
      final todayStr = DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0]; // Default to tomorrow
      _items.add(CartItem(
        templeId: templeId,
        templeName: templeName,
        serviceId: serviceId,
        serviceName: serviceName,
        price: price,
        bookingDate: todayStr,
        slotTime: '09:00', // Default slot
      ));
      notifyListeners();
    }
  }

  void removeItem(int serviceId) {
    _items.removeWhere((item) => item.serviceId == serviceId);
    notifyListeners();
  }

  void updateBookingDetails(int serviceId, String date, String slot) {
    final index = _items.indexWhere((item) => item.serviceId == serviceId);
    if (index != -1) {
      _items[index].bookingDate = date;
      _items[index].slotTime = slot;
      notifyListeners();
    }
  }

  void updateAttendee(int serviceId, String attendeeName) {
    final index = _items.indexWhere((item) => item.serviceId == serviceId);
    if (index != -1) {
      _items[index].attendeeName = attendeeName;
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _errorMessage = null;
    notifyListeners();
  }

  // Checkout process: Locks the slot on the server & charges the payment
  Future<bool> processCheckout(int userId, AuthProvider auth) async {
    if (_items.isEmpty) return false;
    _isCheckingOut = true;
    _errorMessage = null;
    notifyListeners();

    List<int> bookedIds = [];

    try {
      // 1. For each item in the cart, create/lock the slot on the server
      for (var item in _items) {
        // Double-check attendee name: if empty, set to profile default
        final attendee = item.attendeeName.isEmpty 
            ? (auth.currentUser?['full_name'] ?? 'Devotee') 
            : item.attendeeName;

        final bookingResponse = await api.post('/bookings/book?user_id=$userId', {
          'temple_id': item.templeId,
          'service_id': item.serviceId,
          'attendee_name': attendee,
          'booking_date': item.bookingDate,
          'slot_time': item.slotTime,
        });

        int bookingId = bookingResponse['booking_id'];
        bookedIds.add(bookingId);
      }

      // 2. Perform payment for each locked slot
      for (var bId in bookedIds) {
        await api.post('/payments/checkout?booking_id=$bId&payment_method=Razorpay', {});
      }

      // 3. Clear the cart upon success
      _items.clear();
      _isCheckingOut = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isCheckingOut = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      // Note: in a production scenario, we would unlock/cancel any pending bookings if checkout fails.
      return false;
    }
  }
}
