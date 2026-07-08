import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/models/user_model.dart';
import '../../core/models/temple_model.dart';
import '../../core/models/service_model.dart';
import '../../core/models/order_model.dart';
import '../../core/models/post_model.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/app_provider.dart';
import '../auth/login_screen.dart';
import '../user/meet_screen_stub.dart';
import '../../widgets/offline_banner.dart';

class TempleDashboard extends StatefulWidget {
  const TempleDashboard({super.key});

  @override
  State<TempleDashboard> createState() => _TempleDashboardState();
}

class _TempleDashboardState extends State<TempleDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final app = Provider.of<AppProvider>(context, listen: false);
      if (auth.currentUser != null) {
        app.listenAllGlobalData();
        app.listenUserSessions(auth.currentUser!.uid, UserRole.temple);
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

    final templeId = auth.currentUser!.uid;

    final tabs = [
      _buildAnalyticsTab(context, app, auth),
      _buildServicesTab(context, app, templeId),
      _buildOrdersTab(context, app, templeId),
      _buildStudioTab(context, app, auth),
      _buildPriestsTab(context, app, templeId),
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
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: DivineTheme.maroon,
        unselectedItemColor: DivineTheme.textLight,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.room_service), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Studio'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Priests'),
        ],
      ),
    );
  }

  String _getTabTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Temple Analytics';
      case 1:
        return 'Manage Services';
      case 2:
        return 'Booking Orders';
      case 3:
        return 'Creator Studio';
      case 4:
        return 'Manage Priests';
      default:
        return 'Temple';
    }
  }

  // --- TAB 1: ANALYTICS DASHBOARD ---
  Widget _buildAnalyticsTab(BuildContext context, AppProvider app, AuthProvider auth) {
    final templeId = auth.currentUser!.uid;
    final temple = app.temples.firstWhere((t) => t.id == templeId, orElse: () => TempleModel(
      id: templeId,
      name: auth.currentUser!.name,
      description: 'Welcome',
      address: '',
      contact: '',
      profileImage: '',
      coverImage: '',
      galleryImages: [],
      ownerUid: '',
      activePriests: {},
    ));

    final templeOrders = app.orders.where((o) => o.templeId == templeId).toList();
    final todayStr = DateTime.now().toString().split(' ')[0];
    final currentMonthStr = DateTime.now().toString().substring(0, 7);

    // Calculations
    final double totalIncome = templeOrders
        .where((o) => o.status == 'completed' || o.paymentStatus == 'success')
        .fold(0.0, (sum, o) => sum + o.amount);

    final double monthlyIncome = templeOrders
        .where((o) => (o.status == 'completed' || o.status == 'accepted' || o.status == 'live_ready') && o.bookingDate.startsWith(currentMonthStr))
        .fold(0.0, (sum, o) => sum + o.amount);

    final double todayIncome = templeOrders
        .where((o) => (o.status == 'completed' || o.status == 'accepted' || o.status == 'live_ready') && o.bookingDate == todayStr)
        .fold(0.0, (sum, o) => sum + o.amount);

    final totalDevoteesCount = templeOrders.map((o) => o.userId).toSet().length;
    final activePriestsCount = app.priests
        .where((p) => temple.activePriests[p.id] == 'accepted')
        .length;

    // Top Service
    String topService = 'None';
    if (templeOrders.isNotEmpty) {
      final Map<String, int> counts = {};
      for (var o in templeOrders) {
        counts[o.serviceName] = (counts[o.serviceName] ?? 0) + 1;
      }
      var maxCount = 0;
      counts.forEach((name, count) {
        if (count > maxCount) {
          maxCount = count;
          topService = name;
        }
      });
    }

    // Today's Bookings Timeline
    final todayBookings = templeOrders.where((o) => o.bookingDate == todayStr).toList()
      ..sort((a, b) => a.bookingTime.compareTo(b.bookingTime));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [DivineTheme.maroon, Color(0xFF8B1E2F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: DivineTheme.diyaGlow,
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: DivineTheme.gold,
                  child: Icon(Icons.account_balance, color: DivineTheme.maroon, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back, Admin',
                        style: TextStyle(color: DivineTheme.gold.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        temple.name.isEmpty ? auth.currentUser!.name : temple.name,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Revenue & Bookings Overview',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DivineTheme.textDark),
          ),
          const SizedBox(height: 12),
          // Stats Row 1: Revenues
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Today\'s Revenue', '₹${todayIncome.toStringAsFixed(0)}', Icons.today, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Monthly Revenue', '₹${monthlyIncome.toStringAsFixed(0)}', Icons.calendar_month, DivineTheme.saffron),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats Row 2: Devotees / Top service
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total Devotees', '$totalDevoteesCount', Icons.people_outline, Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Active Priests', '$activePriestsCount', Icons.workspace_premium, DivineTheme.gold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Top Puja Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: DivineTheme.creamDark,
                  child: Icon(Icons.star, color: DivineTheme.saffron),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Top Performing Seva', style: TextStyle(fontSize: 11, color: DivineTheme.textLight, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(topService, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DivineTheme.textDark)),
                    ],
                  ),
                ),
                Text('Total Income: ₹${totalIncome.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Today\'s Booking Timeline',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DivineTheme.textDark),
          ),
          const SizedBox(height: 12),
          if (todayBookings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text('No bookings scheduled for today.', style: TextStyle(color: DivineTheme.textLight, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayBookings.length,
              itemBuilder: (context, index) {
                final o = todayBookings[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: DivineTheme.maroon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          o.bookingTime,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: DivineTheme.maroon),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                            const SizedBox(height: 2),
                            Text('Devotee: ${o.userName}', style: const TextStyle(fontSize: 11, color: DivineTheme.textLight)),
                          ],
                        ),
                      ),
                      _buildMiniStatusChip(o.status),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: DivineTheme.textLight, fontWeight: FontWeight.w600)),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: DivineTheme.textDark)),
        ],
      ),
    );
  }

  Widget _buildMiniStatusChip(String status) {
    Color color = Colors.orange;
    if (status == 'accepted' || status == 'assigned') color = Colors.blue;
    if (status == 'completed') color = Colors.green;
    if (status == 'declined' || status == 'cancelled') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- TAB 2: SERVICES TAB (AS-IS WITH SMALL TWEAKS) ---
  Widget _buildServicesTab(BuildContext context, AppProvider app, String templeId) {
    final templeServices = app.services.where((s) => s.templeId == templeId).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: templeServices.isEmpty
          ? const Center(
              child: Text(
                'No services added yet.\nTap the + button to offer Archana, Abhishekam, etc.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DivineTheme.textLight, height: 1.5),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: templeServices.length,
              itemBuilder: (context, index) {
                final s = templeServices[index];
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
                          Text(s.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.currency_rupee, size: 14, color: DivineTheme.gold),
                              Text('${s.amount.toStringAsFixed(0)}   ', style: const TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.textDark, fontSize: 13)),
                              const Icon(Icons.people_outline, size: 14, color: DivineTheme.textLight),
                              Text(' Max Limit: ${s.maxParticipants}', style: const TextStyle(fontSize: 11, color: DivineTheme.textLight)),
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showServiceDialog(context, app, templeId, service: s),
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
        onPressed: () => _showServiceDialog(context, app, templeId),
      ),
    );
  }

  void _showServiceDialog(BuildContext context, AppProvider app, String templeId, {ServiceModel? service}) {
    final nameController = TextEditingController(text: service?.name);
    final descController = TextEditingController(text: service?.description);
    final amountController = TextEditingController(text: service?.amount.toString());
    final maxPeopleController = TextEditingController(text: service?.maxParticipants.toString());
    bool isVideoCall = service?.isVideoCall ?? false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(service == null ? 'Add Offering' : 'Edit Offering', style: const TextStyle(color: DivineTheme.maroon, fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Service Name (e.g., Archana)'),
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
                        decoration: const InputDecoration(labelText: 'Max Devotees per Slot'),
                        keyboardType: TextInputType.number,
                        validator: (v) => int.tryParse(v ?? '') == null ? 'Enter valid number' : null,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Contains Video Call Service (Virtual Seva)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        value: isVideoCall,
                        activeColor: DivineTheme.saffron,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setStateDialog(() {
                            isVideoCall = val;
                          });
                        },
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
                      id: service?.id ?? '',
                      templeId: templeId,
                      priestId: '',
                      name: nameController.text.trim(),
                      description: descController.text.trim(),
                      amount: double.parse(amountController.text),
                      maxParticipants: int.parse(maxPeopleController.text),
                      duration: '30 Minutes',
                      image: 'https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=600',
                      isVideoCall: isVideoCall,
                    );
                    await app.createService(sModel);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.maroon),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- TAB 3: ORDERS TAB ---
  Widget _buildOrdersTab(BuildContext context, AppProvider app, String templeId) {
    final templeOrders = app.orders.where((o) => o.templeId == templeId).toList();

    if (templeOrders.isEmpty) {
      return const Center(child: Text('No bookings received yet.', style: TextStyle(color: DivineTheme.textLight)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templeOrders.length,
      itemBuilder: (context, index) {
        final o = templeOrders[index];
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(o.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.maroon)),
            subtitle: Text('Devotee: ${o.userName} • Date: ${o.bookingDate}'),
            trailing: _buildStatusChip(o.status),
            childrenPadding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Booking ID:'),
                  Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount Paid:'),
                  Text('₹${o.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Time Slot:'),
                  Text(o.bookingTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Participants:'),
                  Text(o.participants.isEmpty ? o.userName : o.participants.join(', '), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Priest Assigned:'),
                  Text(o.assignedPriestName.isEmpty ? 'Not Assigned' : o.assignedPriestName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: o.assignedPriestName.isEmpty ? Colors.red : DivineTheme.textDark,
                      )),
                ],
              ),
              const SizedBox(height: 16),
              if (o.status == 'pending') ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final updated = o.copyWith(status: 'declined');
                          await app.updateOrderDetails(updated);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('DECLINE'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final updated = o.copyWith(status: 'accepted');
                          await app.updateOrderDetails(updated);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('ACCEPT'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAssignPriestDialog(context, app, o),
                    icon: const Icon(Icons.person_add),
                    label: const Text('ASSIGN PRIEST'),
                    style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.saffron),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.orange;
    if (status == 'accepted' || status == 'assigned') color = Colors.blue;
    if (status == 'completed') color = Colors.green;
    if (status == 'declined' || status == 'cancelled') color = Colors.red;

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showAssignPriestDialog(BuildContext context, AppProvider app, OrderModel order) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final templeId = auth.currentUser!.uid;
    final temple = app.temples.firstWhere((t) => t.id == templeId, orElse: () => TempleModel(
      id: templeId,
      name: '', description: '', address: '', contact: '', profileImage: '', coverImage: '', galleryImages: [], ownerUid: '', activePriests: {}
    ));

    final templePriests = app.priests
        .where((p) => temple.activePriests[p.id] == 'accepted')
        .toList();

    if (templePriests.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Priests Available'),
          content: const Text('Please add or invite a priest first in the "Priests" tab.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Assign Priest', style: TextStyle(color: DivineTheme.maroon, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templePriests.length,
              itemBuilder: (context, index) {
                final p = templePriests[index];
                return ListTile(
                  leading: const CircleAvatar(backgroundColor: DivineTheme.saffron, child: Icon(Icons.person, color: Colors.white)),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(p.mobile),
                  onTap: () async {
                    final updatedOrder = order.copyWith(
                      priestId: p.id,
                      assignedPriest: p.id,
                      assignedPriestName: p.name,
                      status: 'assigned',
                    );
                    await app.updateOrderDetails(updatedOrder);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // --- TAB 4: CREATOR STUDIO ---
  Widget _buildStudioTab(BuildContext context, AppProvider app, AuthProvider auth) {
    final templeId = auth.currentUser!.uid;
    final temple = app.temples.firstWhere((t) => t.id == templeId, orElse: () => TempleModel(
      id: templeId,
      name: auth.currentUser!.name,
      description: '', address: '', contact: '', profileImage: '', coverImage: '', galleryImages: [], ownerUid: '', activePriests: {}
    ));

    final templePosts = app.posts.where((p) => p.authorId == templeId).toList();
    final virtualOrders = app.orders.where((o) => o.templeId == templeId && app.services.any((s) => s.id == o.serviceId && s.isVideoCall)).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: TabBar(
            labelColor: DivineTheme.maroon,
            indicatorColor: DivineTheme.saffron,
            indicatorWeight: 3.0,
            tabs: [
              Tab(text: 'Social Wall'),
              Tab(text: 'Gallery'),
              Tab(text: 'Virtual Live'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Studio Tab 1: Social Wall Posting
            _buildSocialWallStudio(context, app, auth, templePosts),
            // Studio Tab 2: Gallery uploads
            _buildGalleryStudio(context, app, temple),
            // Studio Tab 3: Virtual Live streams list
            _buildVirtualLiveStudio(context, app, virtualOrders),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialWallStudio(BuildContext context, AppProvider app, AuthProvider auth, List<PostModel> posts) {
    final captionController = TextEditingController();
    final imageUrlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

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
                    decoration: const InputDecoration(labelText: 'What is happening at the temple today?'),
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
          posts.isEmpty
              ? const Center(child: Text('No social posts created by you yet.', style: TextStyle(color: DivineTheme.textLight, fontSize: 12)))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final p = posts[index];
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

  Widget _buildGalleryStudio(BuildContext context, AppProvider app, TempleModel temple) {
    final galleryUrlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Photo to Temple Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: DivineTheme.textDark)),
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
                    controller: galleryUrlController,
                    decoration: const InputDecoration(labelText: 'Direct Photo URL'),
                    validator: (v) => v == null || v.isEmpty ? 'Required URL' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        await app.addTempleGalleryImage(temple.id, galleryUrlController.text.trim());
                        galleryUrlController.clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Successfully added photo to gallery!'), backgroundColor: Colors.green),
                          );
                        }
                      },
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('ADD TO GALLERY'),
                      style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.maroon),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Current Gallery Grid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: DivineTheme.textDark)),
          const SizedBox(height: 12),
          temple.galleryImages.isEmpty
              ? const Center(child: Text('No gallery images found.', style: TextStyle(color: DivineTheme.textLight, fontSize: 12)))
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: temple.galleryImages.length,
                  itemBuilder: (context, index) {
                    final img = temple.galleryImages[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: DivineTheme.creamDark)),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildVirtualLiveStudio(BuildContext context, AppProvider app, List<OrderModel> orders) {
    if (orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No virtual live bookings received.', style: TextStyle(color: DivineTheme.textLight, fontSize: 13)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final o = orders[index];
        final isLive = o.status == 'accepted' || o.status == 'live_ready';

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
                      child: Text(o.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: DivineTheme.maroon)),
                    ),
                    _buildMiniStatusChip(o.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Devotee: ${o.userName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('Schedule: ${o.bookingDate} @ ${o.bookingTime}', style: const TextStyle(fontSize: 11, color: DivineTheme.textLight)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (isLive) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startMeet(app, o),
                          icon: const Icon(Icons.videocam),
                          label: const Text('MEET NOW'),
                          style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.saffron),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (o.status != 'completed')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final updated = o.copyWith(status: 'completed');
                            await app.updateOrderDetails(updated);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Virtual session successfully marked as completed!'), backgroundColor: Colors.green),
                              );
                            }
                          },
                          icon: const Icon(Icons.stop),
                          label: const Text('END SESSION'),
                          style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.maroon),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 5: PRIESTS TAB ---
  Widget _buildPriestsTab(BuildContext context, AppProvider app, String templeId) {
    final temple = app.temples.firstWhere((t) => t.id == templeId, orElse: () => TempleModel(
      id: templeId,
      name: '', description: '', address: '', contact: '', profileImage: '', coverImage: '', galleryImages: [], ownerUid: '', activePriests: {}
    ));

    final acceptedPriests = app.priests
        .where((p) => temple.activePriests[p.id] == 'accepted')
        .toList();

    final pendingPriests = app.priests
        .where((p) => temple.activePriests[p.id] == 'pending')
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: TabBar(
            labelColor: DivineTheme.maroon,
            indicatorColor: DivineTheme.saffron,
            indicatorWeight: 3.0,
            tabs: [
              Tab(text: 'Active Priests'),
              Tab(text: 'Invited / Pending'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Active Priests
            acceptedPriests.isEmpty
                ? const Center(
                    child: Text('No active priests.\nTap the + button to create or invite a priest.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DivineTheme.textLight, height: 1.5)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: acceptedPriests.length,
                    itemBuilder: (context, index) {
                      final p = acceptedPriests[index];
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: p.photo.isNotEmpty ? NetworkImage(p.photo) : null,
                            backgroundColor: DivineTheme.gold,
                            child: p.photo.isEmpty ? const Icon(Icons.person, color: DivineTheme.maroon) : null,
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.maroon)),
                          subtitle: Text('Mobile: ${p.mobile}\nExperience: ${p.experience}'),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
            // Invited / Pending
            pendingPriests.isEmpty
                ? const Center(
                    child: Text('No pending invitations.',
                        style: TextStyle(color: DivineTheme.textLight)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pendingPriests.length,
                    itemBuilder: (context, index) {
                      final p = pendingPriests[index];
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Status: PENDING INVITATION'),
                          trailing: const Icon(Icons.hourglass_empty, color: Colors.orange),
                        ),
                      );
                    },
                  ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: DivineTheme.maroon,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.person_add),
          onPressed: () => _showAddOrInvitePriestDialog(context, app, temple),
        ),
      ),
    );
  }

  void _showAddOrInvitePriestDialog(BuildContext context, AppProvider app, TempleModel temple) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Manage Priests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DivineTheme.maroon)),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(backgroundColor: DivineTheme.saffron, child: Icon(Icons.mail_outline, color: Colors.white)),
                title: const Text('Invite Existing Priest', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Select and invite a priest registered on SevaSetu'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showInviteExistingPriestDialog(context, app, temple);
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(backgroundColor: DivineTheme.maroon, child: Icon(Icons.person_add_alt_1, color: Colors.white)),
                title: const Text('Create New Priest Account', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Directly register a new priest credentials for your temple'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showCreatePriestDialog(context, app, temple.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInviteExistingPriestDialog(BuildContext context, AppProvider app, TempleModel temple) {
    final availablePriests = app.priests
        .where((p) => !temple.activePriests.containsKey(p.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Invite Existing Priest', style: TextStyle(color: DivineTheme.maroon, fontWeight: FontWeight.bold)),
          content: availablePriests.isEmpty
              ? const Text('All registered priests are already added/invited to your temple.', style: TextStyle(color: DivineTheme.textLight))
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availablePriests.length,
                    itemBuilder: (context, index) {
                      final p = availablePriests[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: p.photo.isNotEmpty ? NetworkImage(p.photo) : null,
                          child: p.photo.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Exp: ${p.experience}'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await app.invitePriestToTemple(temple.id, p.id);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.saffron, visualDensity: VisualDensity.compact),
                          child: const Text('INVITE'),
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePriestDialog(BuildContext context, AppProvider app, String templeId) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create Priest Account', style: TextStyle(color: DivineTheme.maroon, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Priest Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.length < 10 ? 'Enter valid phone' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email Address'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) => v == null || v.length < 6 ? 'At least 6 chars required' : null,
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
                await app.createPriestAccountByTemple(
                  templeId: templeId,
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  password: passController.text.trim(),
                );
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.maroon),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
