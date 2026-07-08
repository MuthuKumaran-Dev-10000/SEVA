import 'package:flutter/material.dart';

class BookingFlowProvider extends ChangeNotifier {
  int? _selectedTempleId;
  String? _selectedTempleName;
  
  int? _selectedServiceId;
  String? _selectedServiceName;
  double? _selectedServicePrice;
  
  DateTime? _selectedDate;
  String? _selectedSlotTime;

  int? get selectedTempleId => _selectedTempleId;
  String? get selectedTempleName => _selectedTempleName;
  
  int? get selectedServiceId => _selectedServiceId;
  String? get selectedServiceName => _selectedServiceName;
  double? get selectedServicePrice => _selectedServicePrice;
  
  DateTime? get selectedDate => _selectedDate;
  String? get selectedSlotTime => _selectedSlotTime;

  BookingFlowProvider() {
    // Default the date selection to tomorrow automatically
    _selectedDate = DateTime.now().add(const Duration(days: 1));
  }

  void selectTemple(int id, String name, TabController tabController) {
    _selectedTempleId = id;
    _selectedTempleName = name;
    
    // Reset subsequent selections
    _selectedServiceId = null;
    _selectedServiceName = null;
    _selectedServicePrice = null;
    _selectedSlotTime = null;
    
    notifyListeners();
    tabController.animateTo(1); // Slide to Services Tab
  }

  void selectService(int id, String name, double price, TabController tabController) {
    _selectedServiceId = id;
    _selectedServiceName = name;
    _selectedServicePrice = price;
    
    // Reset subsequent selections
    _selectedSlotTime = null;
    
    notifyListeners();
    tabController.animateTo(2); // Slide to Date Tab (Index 2)
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    _selectedSlotTime = null;
    notifyListeners();
  }

  void selectSlot(String time) {
    _selectedSlotTime = time;
    notifyListeners();
  }

  void resetFlow() {
    _selectedTempleId = null;
    _selectedTempleName = null;
    _selectedServiceId = null;
    _selectedServiceName = null;
    _selectedServicePrice = null;
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _selectedSlotTime = null;
    notifyListeners();
  }
}
