import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/providers/booking_flow_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/theme.dart';
import '../cart/checkout_dialog.dart';

class TimingsTab extends StatefulWidget {
  final TabController tabController;
  const TimingsTab({super.key, required this.tabController});

  @override
  State<TimingsTab> createState() => _TimingsTabState();
}

class _TimingsTabState extends State<TimingsTab> {
  List<dynamic> _slots = [];
  StreamSubscription<DatabaseEvent>? _slotsSubscription;
  StreamSubscription<DatabaseEvent>? _bookingsSubscription;
  bool _isLoading = false;
  String? _error;
  
  int? _lastFetchedServiceId;
  String? _lastFetchedDateStr;

  List<dynamic> _customSlots = [];
  Map<String, int> _bookedCounts = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final flow = Provider.of<BookingFlowProvider>(context);
    final selectedDate = flow.selectedDate;
    final dateStr = selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate) : null;

    if (flow.selectedServiceId != null && dateStr != null) {
      if (_lastFetchedServiceId != flow.selectedServiceId || _lastFetchedDateStr != dateStr) {
        _lastFetchedServiceId = flow.selectedServiceId;
        _lastFetchedDateStr = dateStr;
        _listenToSlotsAndBookings(flow.selectedServiceId!, dateStr);
      }
    } else {
      _slotsSubscription?.cancel();
      _bookingsSubscription?.cancel();
    }
  }

  @override
  void dispose() {
    _slotsSubscription?.cancel();
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  void _listenToSlotsAndBookings(int serviceId, String dateStr) {
    _slotsSubscription?.cancel();
    _bookingsSubscription?.cancel();
    
    setState(() {
      _isLoading = true;
      _error = null;
      _customSlots = [];
      _bookedCounts = {};
    });

    // 1. Listen to custom configured slots
    _slotsSubscription = FirebaseDatabase.instance
        .ref('Seva-v1/services/$serviceId/slots/$dateStr')
        .onValue
        .listen((slotsEvent) {
      final slotsData = slotsEvent.snapshot.value;
      final List<dynamic> tempSlots = [];

      if (slotsData != null) {
        void parseSlot(dynamic val) {
          if (val is Map) {
            tempSlots.add(Map<String, dynamic>.from(val));
          }
        }
        if (slotsData is Map) {
          slotsData.values.forEach(parseSlot);
        } else if (slotsData is List) {
          slotsData.forEach(parseSlot);
        }
      }

      tempSlots.sort((a, b) => a['from'].toString().compareTo(b['from'].toString()));

      if (mounted) {
        setState(() {
          _customSlots = tempSlots;
          _updateSlotsGrid();
        });
      }
    }, onError: (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _isLoading = false;
        });
      }
    });

    // 2. Listen to actual bookings count
    _bookingsSubscription = FirebaseDatabase.instance
        .ref('Seva-v1/bookings')
        .onValue
        .listen((bookingsEvent) {
      final bookingsData = bookingsEvent.snapshot.value;
      final Map<String, int> tempBookings = {};

      void checkBooking(dynamic val) {
        if (val is Map) {
          final b = Map<String, dynamic>.from(val);
          if (b['service_id'] == serviceId &&
              b['booking_date'] == dateStr &&
              b['status'] != 'declined') {
            final slot = b['slot_time']?.toString();
            if (slot != null) {
              tempBookings[slot] = (tempBookings[slot] ?? 0) + 1;
            }
          }
        }
      }

      if (bookingsData != null) {
        if (bookingsData is Map) {
          bookingsData.values.forEach(checkBooking);
        } else if (bookingsData is List) {
          bookingsData.forEach(checkBooking);
        }
      }

      if (mounted) {
        setState(() {
          _bookedCounts = tempBookings;
          _updateSlotsGrid();
        });
      }
    });
  }

  void _updateSlotsGrid() {
    final List<dynamic> updatedSlots = [];
    
    if (_customSlots.isNotEmpty) {
      for (final slot in _customSlots) {
        final fromTime = slot['from']?.toString() ?? '';
        final toTime = slot['to']?.toString() ?? '';
        final capacity = slot['capacity'] is num ? (slot['capacity'] as num).toInt() : 1;
        final timeLabel = '$fromTime - $toTime';
        
        final count = _bookedCounts[timeLabel] ?? 0;
        updatedSlots.add({
          'time': timeLabel,
          'status': count >= capacity ? 'full' : 'available',
          'booked_count': count,
          'capacity': capacity,
        });
      }
    } else {
      // Fallback to default slots
      const List<String> defaultSlots = ["06:00", "07:30", "09:00", "10:30", "12:00", "16:00", "17:30", "19:00"];
      for (final slot in defaultSlots) {
        final count = _bookedCounts[slot] ?? 0;
        updatedSlots.add({
          'time': slot,
          'status': count >= 1 ? 'full' : 'available',
          'booked_count': count,
          'capacity': 1,
        });
      }
    }

    if (mounted) {
      setState(() {
        _slots = updatedSlots;
        _isLoading = false;
      });
    }
  }

  void _onSlotSelected(String slotTime, BookingFlowProvider flow, CartProvider cart) {
    flow.selectSlot(slotTime);
    
    // Add to cart (clears previous items since we restrict to single slot booking)
    cart.clearCart();
    cart.addItem(
      templeId: flow.selectedTempleId!,
      templeName: flow.selectedTempleName!,
      serviceId: flow.selectedServiceId!,
      serviceName: flow.selectedServiceName!,
      price: flow.selectedServicePrice!,
    );
    
    // Update cart item booking details
    final dateStr = DateFormat('yyyy-MM-dd').format(flow.selectedDate!);
    cart.updateBookingDetails(flow.selectedServiceId!, dateStr, slotTime);

    // Prompt checkout
    showDialog(
      context: context,
      builder: (context) => const CheckoutDialog(),
    );
  }

  Color _getStatusColor(String status) {
    return status == 'available' ? Colors.green.shade600 : Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final flow = Provider.of<BookingFlowProvider>(context);
    final cart = Provider.of<CartProvider>(context);

    // 1. Validate previous selections
    if (flow.selectedTempleId == null) {
      return _buildWarningView('No Temple Selected', 'Go to Temples', 0);
    }
    if (flow.selectedServiceId == null) {
      return _buildWarningView('No Service Selected', 'Go to Services', 1);
    }
    if (flow.selectedDate == null) {
      return _buildWarningView('No Date Selected', 'Go to Date Selector', 2);
    }

    final selectedDateStr = DateFormat('dd MMMM yyyy').format(flow.selectedDate!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selection Banner Info
          Card(
            color: SevaTheme.primaryMaroon.withOpacity(0.03),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: SevaTheme.primaryMaroon.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  const Icon(Icons.church_outlined, color: SevaTheme.secondaryGold, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flow.selectedTempleName ?? '',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon, fontSize: 14),
                        ),
                        Text(
                          '${flow.selectedServiceName} (₹${flow.selectedServicePrice})',
                          style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textCharcoal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Selected Date: $selectedDateStr',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: SevaTheme.secondaryGold),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.tabController.animateTo(2),
                    child: Text('Change Date', style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.secondaryGold, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Timings Slots Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Choose a Timing Slot',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: SevaTheme.primaryMaroon),
              ),
              Row(
                children: [
                  Container(width: 8, height: 8, color: Colors.green.shade600),
                  const SizedBox(width: 4),
                  Text('Available', style: GoogleFonts.outfit(fontSize: 10)),
                  const SizedBox(width: 12),
                  Container(width: 8, height: 8, color: Colors.red.shade700),
                  const SizedBox(width: 4),
                  Text('Booked', style: GoogleFonts.outfit(fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: CircularProgressIndicator(color: SevaTheme.primaryMaroon),
              ),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 28),
                    const SizedBox(height: 8),
                    Text('Error: $_error', style: GoogleFonts.outfit(fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (_slots.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Text('No slots configured for this service.', style: GoogleFonts.outfit(color: SevaTheme.textMuted)),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _slots.length,
              itemBuilder: (context, index) {
                final slot = _slots[index];
                final slotTime = slot['time'];
                final slotStatus = slot['status'];
                final color = _getStatusColor(slotStatus);
                final isFull = slotStatus == 'full';

                return GestureDetector(
                  onTap: isFull ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('This slot is already booked.')),
                    );
                  } : () => _onSlotSelected(slotTime, flow, cart),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        slotTime,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWarningView(String title, String buttonLabel, int tabIndex) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: SevaTheme.primaryMaroon.withOpacity(0.15)),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
            ),
            const SizedBox(height: 8),
            Text(
              'Please complete previous steps in the booking wizard to choose slots.',
              style: GoogleFonts.outfit(fontSize: 13, color: SevaTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => widget.tabController.animateTo(tabIndex),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
