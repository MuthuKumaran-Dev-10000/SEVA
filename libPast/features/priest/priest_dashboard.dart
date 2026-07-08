import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/models/user_model.dart';
import '../../core/models/order_model.dart';
import '../../core/models/service_model.dart';
import '../../core/models/priest_model.dart';
import '../../core/models/post_model.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/app_provider.dart';
import '../auth/login_screen.dart';
import '../user/meet_screen_stub.dart';
import '../../widgets/offline_banner.dart';

class PriestDashboard extends StatefulWidget {
  const PriestDashboard({super.key});

  @override
  State<PriestDashboard> createState() => _PriestDashboardState();
}

class _PriestDashboardState extends State<PriestDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final app = Provider.of<AppProvider>(context, listen: false);
      if (auth.currentUser != null) {
        app.listenAllGlobalData();
        app.listenUserSessions(auth.currentUser!.uid, UserRole.priest);
      }
    });
  }

  void _launchJitsi(String urlStr) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => getInAppMeetScreen(urlStr),
      ),
    );
  }

  Future<void> _startMeet(AppProvider app, OrderModel order) async {
    await app.startLiveSession(order);
    if (!mounted) return;
    _launchJitsi(order.jitsiLink);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final app = Provider.of<AppProvider>(context);

    if (auth.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: DivineTheme.maroon),
        ),
      );
    }

    final priestId = auth.currentUser!.uid;

    final tabs = [
      _buildBookingsTab(context, app, priestId),
      _buildPrivateServicesTab(context, app, priestId),
      _buildSocialWallTab(context, app, auth),
      _buildInvitationsTab(context, app, priestId),
      _buildProfileTab(context, app, priestId),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(_getTabTitle(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
        backgroundColor: DivineTheme.maroon,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: tabs[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: DivineTheme.maroon,
        unselectedItemColor: DivineTheme.textLight,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.room_service), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Studio'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active), label: 'Invites'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  String _getTabTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Priest Bookings';
      case 1:
        return 'Private Services';
      case 2:
        return 'Creator Studio';
      case 3:
        return 'Temple Invites';
      case 4:
        return 'Priest Profile';
      default:
        return 'Priest Panel';
    }
  }

  // --- TAB 1: BOOKINGS (PENDING, UPCOMING, COMPLETED) ---
  Widget _buildBookingsTab(BuildContext context, AppProvider app, String priestId) {
    // Include both unassigned temple assignments (assigned status) and direct private bookings
    final pending = app.orders.where((o) => 
        o.status == 'assigned' || 
        (o.priestId == priestId && o.templeId.isEmpty && o.status == 'pending')
    ).toList();
    final upcoming = app.orders.where((o) => o.status == 'accepted' || o.status == 'live_ready').toList();
    final completed = app.orders.where((o) => o.status == 'completed').toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: DivineTheme.maroon,
            indicatorColor: DivineTheme.saffron,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOrdersList(pending, isPending: true, app: app),
                _buildOrdersList(upcoming, isPending: false, app: app),
                _buildCompletedList(completed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<OrderModel> list, {required bool isPending, required AppProvider app}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isPending ? 'No pending assignments.' : 'No upcoming accepted services.',
          style: const TextStyle(color: DivineTheme.textLight),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final o = list[index];
        final isPrivate = o.templeId.isEmpty;

        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        o.serviceName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DivineTheme.maroon),
                      ),
                    ),
                    Text('₹${o.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Devotee: ${o.userName}', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  isPrivate ? 'Type: Private Booking' : 'Temple: ${o.templeName}',
                  style: TextStyle(color: isPrivate ? DivineTheme.saffron : DivineTheme.textLight, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Date: ${o.bookingDate}  •  Time: ${o.bookingTime}', style: const TextStyle(color: DivineTheme.textLight, fontSize: 13)),
                const SizedBox(height: 16),
                if (isPending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            if (isPrivate) {
                              final updated = o.copyWith(status: 'declined');
                              await app.updateOrderDetails(updated);
                            } else {
                              // Decline temple assignment: Set status back to pending, clear priest details
                              final updated = o.copyWith(
                                priestId: '',
                                assignedPriest: '',
                                assignedPriestName: '',
                                status: 'pending',
                              );
                              await app.updateOrderDetails(updated);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            foregroundColor: Colors.red,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('DECLINE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final updated = o.copyWith(status: 'accepted');
                            await app.updateOrderDetails(updated);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('ACCEPT'),
                        ),
                      ),
                    ],
                  ),
                  if (isPrivate) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showRescheduleSheet(context, app, o),
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text('RESCHEDULE'),
                        style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.saffron),
                      ),
                    ),
                  ],
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startMeet(app, o),
                          icon: const Icon(Icons.video_call),
                          label: const Text('MEET NOW'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DivineTheme.saffron,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final updated = o.copyWith(status: 'completed');
                            await app.updateOrderDetails(updated);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('COMPLETE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DivineTheme.maroon,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isPrivate) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showRescheduleSheet(context, app, o),
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text('RESCHEDULE'),
                        style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.saffron),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletedList(List<OrderModel> list) {
    if (list.isEmpty) {
      return const Center(child: Text('No completed orders found.', style: TextStyle(color: DivineTheme.textLight)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final o = list[index];
        final isPrivate = o.templeId.isEmpty;
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.done, color: Colors.white)),
            title: Text(o.serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Devotee: ${o.userName}\nType: ${isPrivate ? 'Private' : 'Temple'} • Date: ${o.bookingDate}'),
            trailing: Text('₹${o.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  void _showRescheduleSheet(BuildContext context, AppProvider app, OrderModel order) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String searchQuery = '';
    String? selectedSlot;

    final List<String> standardSlots = [
      "07:00 AM", "08:00 AM", "09:00 AM", "10:00 AM", "11:00 AM",
      "12:00 PM", "04:00 PM", "05:00 PM", "06:00 PM", "07:00 PM", "08:00 PM"
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final dateStr = selectedDate.toString().split(' ')[0];
            final filteredSlots = standardSlots.where((slot) {
              return slot.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reschedule Private Booking',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DivineTheme.maroon, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    order.serviceName,
                    style: const TextStyle(color: DivineTheme.textLight, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Date:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final date = DateTime.now().add(Duration(days: index + 1));
                        final isSelected = date.year == selectedDate.year &&
                            date.month == selectedDate.month &&
                            date.day == selectedDate.day;
                        final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final weekdayStr = weekdays[date.weekday - 1];

                        return Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: ChoiceChip(
                            label: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(weekdayStr, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : DivineTheme.textLight, fontWeight: FontWeight.w600)),
                                Text('${date.day}', style: TextStyle(fontSize: 14, color: isSelected ? Colors.white : DivineTheme.textDark, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: DivineTheme.maroon,
                            backgroundColor: DivineTheme.creamDark.withValues(alpha: 0.3),
                            onSelected: (selected) {
                              if (selected) {
                                setStateSheet(() {
                                  selectedDate = date;
                                  selectedSlot = null;
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) {
                      setStateSheet(() {
                        searchQuery = val;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search times (e.g. morning, PM, 09)...',
                      prefixIcon: Icon(Icons.search, color: DivineTheme.maroon, size: 20),
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Slot:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredSlots.isEmpty
                        ? const Center(child: Text('No slots match your search.', style: TextStyle(color: DivineTheme.textLight)))
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 2.2,
                            ),
                            itemCount: filteredSlots.length,
                            itemBuilder: (context, index) {
                              final slot = filteredSlots[index];

                              return FutureBuilder<int>(
                                future: app.getSlotBookingCount(order.serviceId, dateStr, slot),
                                builder: (context, snapshot) {
                                  final count = snapshot.data ?? 0;
                                  int maxParticipants = 1;
                                  try {
                                    maxParticipants = app.services.firstWhere((s) => s.id == order.serviceId).maxParticipants;
                                  } catch (_) {}

                                  final isFull = count >= maxParticipants;
                                  final isSelected = selectedSlot == slot;

                                  return InkWell(
                                    onTap: isFull
                                        ? null
                                        : () {
                                            setStateSheet(() {
                                              selectedSlot = slot;
                                            });
                                          },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isFull
                                            ? Colors.grey.shade100
                                            : (isSelected ? DivineTheme.saffron.withValues(alpha: 0.15) : Colors.white),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isFull
                                              ? Colors.grey.shade300
                                              : (isSelected ? DivineTheme.saffron : Colors.grey.shade300),
                                          width: isSelected ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              slot,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isFull
                                                    ? Colors.grey.shade400
                                                    : (isSelected ? DivineTheme.saffron : DivineTheme.textDark),
                                              ),
                                            ),
                                            if (isFull)
                                              const Text(
                                                'FULL',
                                                style: TextStyle(fontSize: 8, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedSlot == null
                          ? null
                          : () async {
                              final updatedOrder = order.copyWith(
                                bookingDate: dateStr,
                                bookingTime: selectedSlot!,
                              );
                              await app.updateOrderDetails(updatedOrder);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Rescheduled booking to $dateStr @ ${selectedSlot!}'),
                                    backgroundColor: DivineTheme.maroon,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DivineTheme.maroon,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('CONFIRM NEW SLOT', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {});
    });
  }

  // --- TAB 2: PRIVATE SERVICES CRUD ---
  Widget _buildPrivateServicesTab(BuildContext context, AppProvider app, String priestId) {
    final privateServices = app.services.where((s) => s.priestId == priestId).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: privateServices.isEmpty
          ? const Center(
              child: Text(
                'You have not added any private services yet.\nDevotees can book you directly when you offer services here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DivineTheme.textLight, height: 1.5),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: privateServices.length,
              itemBuilder: (context, index) {
                final s = privateServices[index];
                return Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.maroon)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(s.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.currency_rupee, size: 14, color: DivineTheme.gold),
                              Text('${s.amount.toStringAsFixed(0)}   ', style: const TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.textDark)),
                              const Icon(Icons.people_outline, size: 14, color: DivineTheme.textLight),
                              Text(' Max Limit: ${s.maxParticipants}', style: const TextStyle(fontSize: 12, color: DivineTheme.textLight)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: DivineTheme.maroon,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
        onPressed: () => _showAddPrivateServiceDialog(context, app, priestId),
      ),
    );
  }

  void _showAddPrivateServiceDialog(BuildContext context, AppProvider app, String priestId) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final amountController = TextEditingController();
    final maxPeopleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Private Offering', style: TextStyle(color: DivineTheme.maroon, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Puja Name (e.g. Grihapravesam)'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount (INR)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => double.tryParse(v ?? '') == null ? 'Enter valid amount' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: maxPeopleController,
                    decoration: const InputDecoration(labelText: 'Max Participants'),
                    keyboardType: TextInputType.number,
                    validator: (v) => int.tryParse(v ?? '') == null ? 'Enter valid number' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: DivineTheme.textLight)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final sModel = ServiceModel(
                  id: '',
                  templeId: '',
                  priestId: priestId,
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  amount: double.parse(amountController.text),
                  maxParticipants: int.parse(maxPeopleController.text),
                  duration: '1 Hour',
                  image: 'https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?q=80&w=600',
                );
                await app.createService(sModel);
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.maroon),
              child: const Text('Add Service'),
            ),
          ],
        );
      },
    );
  }

  // --- TAB 3: SOCIAL WALL STUDIO ---
  Widget _buildSocialWallTab(BuildContext context, AppProvider app, AuthProvider auth) {
    final priestId = auth.currentUser!.uid;
    final captionController = TextEditingController();
    final imageUrlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final priestPosts = app.posts.where((p) => p.authorId == priestId).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Publish a New Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: DivineTheme.textDark)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: captionController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Write a spiritual update...'),
                    validator: (v) => v == null || v.isEmpty ? 'Please enter caption' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(labelText: 'Spiritual Image URL'),
                    validator: (v) => v == null || v.isEmpty ? 'Please enter photo URL' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final newPost = PostModel(
                          id: '',
                          authorId: auth.currentUser!.uid,
                          authorName: auth.currentUser!.name,
                          authorImage: auth.currentUser!.profilePic,
                          imageUrl: imageUrlController.text.trim(),
                          videoUrl: '',
                          caption: captionController.text.trim(),
                          timestamp: DateTime.now().millisecondsSinceEpoch,
                        );
                        await app.addSocialPost(newPost);
                        captionController.clear();
                        imageUrlController.clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Successfully published update to Social Wall!'), backgroundColor: Colors.green),
                          );
                        }
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('PUBLISH POST'),
                      style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.maroon),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Published Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: DivineTheme.textDark)),
          const SizedBox(height: 12),
          priestPosts.isEmpty
              ? const Center(child: Text('No social posts created by you yet.', style: TextStyle(color: DivineTheme.textLight, fontSize: 12)))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: priestPosts.length,
                  itemBuilder: (context, index) {
                    final p = priestPosts[index];
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        leading: Image.network(p.imageUrl, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                        title: Text(p.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(DateFormat('dd MMM, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(p.timestamp)), style: const TextStyle(fontSize: 10)),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // --- TAB 4: INVITATIONS (LINKEDIN STYLE ACCEPT/REJECT) ---
  Widget _buildInvitationsTab(BuildContext context, AppProvider app, String priestId) {
    final invitingTemples = app.temples.where((t) => t.activePriests[priestId] == 'pending').toList();

    if (invitingTemples.isEmpty) {
      return const Center(
        child: Text('No pending temple invitations.', style: TextStyle(color: DivineTheme.textLight)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invitingTemples.length,
      itemBuilder: (context, index) {
        final t = invitingTemples[index];

        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  image: DecorationImage(
                    image: NetworkImage(t.coverImage.isNotEmpty ? t.coverImage : 'https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=600'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: DivineTheme.maroon),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.address,
                      style: const TextStyle(color: DivineTheme.textLight, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.description,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await app.respondToTempleInvitation(t.id, priestId, false);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('DECLINE'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await app.respondToTempleInvitation(t.id, priestId, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('ACCEPT'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 5: PROFILE & EDIT PROFILE ---
  Widget _buildProfileTab(BuildContext context, AppProvider app, String priestId) {
    final priest = app.priests.firstWhere((p) => p.id == priestId, orElse: () => PriestModel(
      id: priestId, name: 'Priest Profile', dob: '', age: 30, gender: 'Male', mobile: '', email: '', address: '', experience: '0', rasi: 'Mesha', nakshatra: 'Aswini', lagnam: 'Mesha', bio: '', photo: ''
    ));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: priest.photo.isNotEmpty ? NetworkImage(priest.photo) : null,
            backgroundColor: DivineTheme.gold,
            child: priest.photo.isEmpty ? const Icon(Icons.person, size: 50, color: DivineTheme.maroon) : null,
          ),
          const SizedBox(height: 16),
          Text(priest.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: DivineTheme.maroon)),
          Text('Experience: ${priest.experience}', style: const TextStyle(color: DivineTheme.textLight, fontStyle: FontStyle.italic)),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.star, color: DivineTheme.saffron),
            title: const Text('Rasi / Nakshatra'),
            subtitle: Text('${priest.rasi} / ${priest.nakshatra} (Lagnam: ${priest.lagnam})'),
          ),
          ListTile(
            leading: const Icon(Icons.phone, color: DivineTheme.maroon),
            title: const Text('Mobile'),
            subtitle: Text(priest.mobile),
          ),
          ListTile(
            leading: const Icon(Icons.email, color: DivineTheme.maroon),
            title: const Text('Email'),
            subtitle: Text(priest.email),
          ),
          ListTile(
            leading: const Icon(Icons.location_on, color: DivineTheme.maroon),
            title: const Text('Address'),
            subtitle: Text(priest.address),
          ),
          ListTile(
            leading: const Icon(Icons.description, color: DivineTheme.maroon),
            title: const Text('Bio'),
            subtitle: Text(priest.bio.isEmpty ? 'No bio added.' : priest.bio),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showEditProfileDialog(context, app, priest),
            icon: const Icon(Icons.edit),
            label: const Text('EDIT PROFILE DETAILS'),
            style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.maroon),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AppProvider app, PriestModel priest) {
    final bioController = TextEditingController(text: priest.bio);
    final expController = TextEditingController(text: priest.experience);
    final rasiController = TextEditingController(text: priest.rasi);
    final naksController = TextEditingController(text: priest.nakshatra);
    final lagnamController = TextEditingController(text: priest.lagnam);
    final photoController = TextEditingController(text: priest.photo);
    final addressController = TextEditingController(text: priest.address);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Profile Details', style: TextStyle(color: DivineTheme.maroon, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: expController, decoration: const InputDecoration(labelText: 'Experience (e.g. 10 Years)')),
                  const SizedBox(height: 12),
                  TextFormField(controller: rasiController, decoration: const InputDecoration(labelText: 'Rasi')),
                  const SizedBox(height: 12),
                  TextFormField(controller: naksController, decoration: const InputDecoration(labelText: 'Nakshatra')),
                  const SizedBox(height: 12),
                  TextFormField(controller: lagnamController, decoration: const InputDecoration(labelText: 'Lagnam')),
                  const SizedBox(height: 12),
                  TextFormField(controller: photoController, decoration: const InputDecoration(labelText: 'Photo URL')),
                  const SizedBox(height: 12),
                  TextFormField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
                  const SizedBox(height: 12),
                  TextFormField(controller: bioController, decoration: const InputDecoration(labelText: 'Bio Summary'), maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updated = PriestModel(
                  id: priest.id,
                  name: priest.name,
                  dob: priest.dob,
                  age: priest.age,
                  gender: priest.gender,
                  mobile: priest.mobile,
                  email: priest.email,
                  address: addressController.text,
                  experience: expController.text,
                  rasi: rasiController.text,
                  nakshatra: naksController.text,
                  lagnam: lagnamController.text,
                  bio: bioController.text,
                  photo: photoController.text,
                );
                await app.updatePriestProfile(updated);
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.maroon),
              child: const Text('Save Details'),
            ),
          ],
        );
      },
    );
  }
}
