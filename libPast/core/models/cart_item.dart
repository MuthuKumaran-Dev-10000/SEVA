import 'service_model.dart';

class CartItem {
  final ServiceModel service;
  int quantity;
  String selectedDate;      // Format: YYYY-MM-DD
  String selectedTimeSlot;  // Format: e.g. "10:00 AM"

  CartItem({
    required this.service,
    this.quantity = 1,
    required this.selectedDate,
    required this.selectedTimeSlot,
  });
}
