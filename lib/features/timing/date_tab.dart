import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/providers/booking_flow_provider.dart';
import '../../core/theme.dart';

class DateTab extends StatefulWidget {
  final TabController tabController;
  const DateTab({super.key, required this.tabController});

  @override
  State<DateTab> createState() => _DateTabState();
}

class _DateTabState extends State<DateTab> {
  late DateTime _currentMonth;
  StreamSubscription<DatabaseEvent>? _bookingsSubscription;
  Map<String, int> _bookingsCountMap = {}; // key: yyyy-MM-dd, value: count of bookings
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _startBookingsListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Restart bookings listener in case service selection changed
    _startBookingsListener();
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  void _startBookingsListener() {
    _bookingsSubscription?.cancel();
    final flow = Provider.of<BookingFlowProvider>(context, listen: false);
    final serviceId = flow.selectedServiceId;

    if (serviceId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    _bookingsSubscription = FirebaseDatabase.instance
        .ref('Seva-v1/bookings')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      final Map<String, int> tempCounts = {};

      void checkBooking(dynamic val) {
        if (val is Map) {
          final b = Map<String, dynamic>.from(val);
          if (b['service_id'] == serviceId && b['status'] != 'declined') {
            final dateStr = b['booking_date']?.toString(); // yyyy-MM-dd
            if (dateStr != null) {
              tempCounts[dateStr] = (tempCounts[dateStr] ?? 0) + 1;
            }
          }
        }
      }

      if (data != null) {
        if (data is Map) {
          data.values.forEach(checkBooking);
        } else if (data is List) {
          data.forEach(checkBooking);
        }
      }

      if (mounted) {
        setState(() {
          _bookingsCountMap = tempCounts;
          _isLoading = false;
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
  }

  int _daysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _prevMonth() {
    final now = DateTime.now();
    // Do not go before the current month
    if (_currentMonth.year == now.year && _currentMonth.month == now.month) {
      return;
    }
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  Color _getDateColor(int count) {
    if (count >= 8) {
      return Colors.red.shade700; // Red for fully booked (8/8)
    } else if (count >= 6) {
      return Colors.orange.shade700; // Orange for mostly booked (6-7)
    } else if (count >= 4) {
      return Colors.yellow.shade800; // Yellow for half full (4-5)
    } else {
      return Colors.green.shade600; // Green for less than half full (0-3)
    }
  }

  void _selectDate(DateTime date, BookingFlowProvider flow) {
    flow.selectDate(date);
    widget.tabController.animateTo(3); // Navigate to TimingsTab (Tab index 3)
  }

  @override
  Widget build(BuildContext context) {
    final flow = Provider.of<BookingFlowProvider>(context);

    // 1. Validation checks
    if (flow.selectedTempleId == null) {
      return _buildWarningView('No Temple Selected', 'Go to Temples', 0);
    }
    if (flow.selectedServiceId == null) {
      return _buildWarningView('No Service Selected', 'Go to Services', 1);
    }

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    final daysCount = _daysInMonth(_currentMonth);
    // Find the day of the week the 1st of the month falls on (Sunday = 0, Monday = 1, etc.)
    final int offset = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;

    final monthName = DateFormat('MMMM yyyy').format(_currentMonth);
    final isCurrentMonth = _currentMonth.year == now.year && _currentMonth.month == now.month;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Service Selection Summary Card
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
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.tabController.animateTo(1),
                    child: Text('Change Seva', style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.secondaryGold, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Select Booking Date',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: SevaTheme.primaryMaroon),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: CircularProgressIndicator(color: SevaTheme.primaryMaroon),
              ),
            )
          else if (_error != null)
            Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 28),
                  const SizedBox(height: 8),
                  Text('Error loading slot information: $_error', style: GoogleFonts.outfit(fontSize: 13)),
                  ElevatedButton(onPressed: _startBookingsListener, child: const Text('Retry')),
                ],
              ),
            )
          else ...[
            // Calendar Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SevaTheme.primaryMaroon.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: Column(
                children: [
                  // Calendar Header: Month Selector
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: isCurrentMonth ? Colors.grey.shade400 : SevaTheme.primaryMaroon),
                          onPressed: isCurrentMonth ? null : _prevMonth,
                        ),
                        Text(
                          monthName.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: SevaTheme.primaryMaroon,
                            letterSpacing: 1.0,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: SevaTheme.primaryMaroon),
                          onPressed: _nextMonth,
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Weekdays Header Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 2.0,
                    ),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
                      return Center(
                        child: Text(
                          days[index],
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: SevaTheme.textMuted,
                          ),
                        ),
                      );
                    },
                  ),

                  // Month Days Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    padding: const EdgeInsets.all(4.0),
                    itemCount: offset + daysCount,
                    itemBuilder: (context, index) {
                      if (index < offset) {
                        return const SizedBox.shrink(); // Empty space
                      }

                      final day = index - offset + 1;
                      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                      final isPast = date.isBefore(todayMidnight);

                      final dateStr = DateFormat('yyyy-MM-dd').format(date);
                      final count = _bookingsCountMap[dateStr] ?? 0;

                      final color = isPast ? Colors.grey.shade300 : _getDateColor(count);
                      final isSelected = flow.selectedDate != null &&
                          flow.selectedDate!.year == date.year &&
                          flow.selectedDate!.month == date.month &&
                          flow.selectedDate!.day == date.day;

                      return GestureDetector(
                        onTap: isPast
                            ? null
                            : () => _selectDate(date, flow),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? SevaTheme.primaryMaroon
                                : (isPast ? Colors.grey.shade100 : color.withOpacity(0.08)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected 
                                  ? SevaTheme.secondaryGold 
                                  : (isPast ? Colors.grey.shade200 : color),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  day.toString(),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: isSelected 
                                        ? Colors.white 
                                        : (isPast ? Colors.grey.shade400 : SevaTheme.textCharcoal),
                                  ),
                                ),
                                if (!isPast) ...[
                                  const SizedBox(height: 1),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: isSelected ? SevaTheme.secondaryGold : color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Color Coding Legend Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: SevaTheme.primaryMaroon.withOpacity(0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AVAILABILITY LEGEND',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: SevaTheme.primaryMaroon,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLegendItem(Colors.green.shade600, 'Available'),
                        _buildLegendItem(Colors.yellow.shade800, 'Half Full'),
                        _buildLegendItem(Colors.orange.shade700, 'Mostly Booked'),
                        _buildLegendItem(Colors.red.shade700, 'Fully Booked'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w500, color: SevaTheme.textCharcoal),
        ),
      ],
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
              'Please complete previous steps in the booking wizard to select a date.',
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
