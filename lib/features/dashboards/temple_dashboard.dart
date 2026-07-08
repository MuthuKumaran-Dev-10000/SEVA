import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme.dart';
import '../home/sidebar.dart';
import '../video/video_tab.dart';
import '../video/video_call_screen.dart';

class TempleDashboard extends StatefulWidget {
  const TempleDashboard({super.key});

  @override
  State<TempleDashboard> createState() => _TempleDashboardState();
}

class _TempleDashboardState extends State<TempleDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Booking & Revenue State
  List<dynamic> _templeBookings = [];
  bool _isLoadingBookings = true;
  String? _bookingsError;

  // Priest Recruitment State
  final _searchEmailController = TextEditingController();
  Map<String, dynamic>? _searchedPriest;
  bool _isSearchingPriest = false;
  String? _searchError;

  // Temple Profile & Service State
  Map<String, dynamic>? _myTemple;
  bool _isLoadingTemple = true;
  List<dynamic> _fetchedServices = [];
  bool _isLoadingServices = true;
  String? _servicesError;

  // Service slot config state
  int? _selectedServiceForSlots;
  String? _selectedServiceNameForSlots;
  DateTime? _slotsConfigDate;

  // Controllers for service form
  final _serviceNameController = TextEditingController();
  final _servicePriceController = TextEditingController();
  final _serviceDescController = TextEditingController();
  final _serviceDurationController = TextEditingController();

  // Controllers for slot form
  final _slotFromController = TextEditingController(text: "09:00");
  final _slotToController = TextEditingController(text: "10:30");
  final _slotCapacityController = TextEditingController(text: "5");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchBookingsAndStats();
    _fetchMyTemple().then((_) => _fetchTempleServices());
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.fetchTemplePriests();
    auth.fetchTempleStats();
  }

  Future<String> _getDynamicSignalingUrl(String derivedFallback) async {
    try {
      final snap = await FirebaseDatabase.instance.ref('Seva-v1/signaling_url').get();
      if (snap.exists && snap.value != null) {
        final url = snap.value.toString().trim();
        if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
          return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
        }
      }
    } catch (_) {}
    return derivedFallback;
  }

  Future<void> _joinVideoCall(BuildContext context, Map<String, dynamic> booking) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final client = Provider.of<ApiClient>(context, listen: false);

    final roomCode = booking['room_code']?.toString();
    if (roomCode == null || roomCode.isEmpty) return;

    DateTime? expiresAt;
    String priestName = 'Priest';
    String serviceName = booking['service_name'] ?? 'Seva';
    try {
      final snap = await FirebaseDatabase.instance.ref('Seva-v1/meetings/$roomCode').get();
      if (snap.exists && snap.value is Map) {
        final m = Map<String, dynamic>.from(snap.value as Map);
        if (m['expires_at'] != null) expiresAt = DateTime.tryParse(m['expires_at']);
        priestName = m['priest_name'] ?? priestName;
        serviceName = m['service_name'] ?? serviceName;
      }
    } catch (_) {}

    final signalingBase = client.baseUrl
        .replaceAll('/api', '')
        .replaceAll(':8000', ':8001');

    final dynamicUrl = await _getDynamicSignalingUrl(signalingBase);

    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            roomCode: roomCode,
            displayName: auth.currentUser?['full_name'] ?? 'Participant',
            isHost: true,
            priestName: priestName,
            serviceName: serviceName,
            signalingUrl: dynamicUrl,
            expiresAt: expiresAt,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchEmailController.dispose();
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    _serviceDescController.dispose();
    _serviceDurationController.dispose();
    _slotFromController.dispose();
    _slotToController.dispose();
    _slotCapacityController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyTemple() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser == null) return;
    try {
      final snap = await FirebaseDatabase.instance.ref('Seva-v1/temples').get();
      Map<String, dynamic>? found;
      if (snap.exists && snap.value != null) {
        void check(dynamic k, dynamic v) {
          if (v is Map) {
            final t = Map<String, dynamic>.from(v);
            if (t['user_id'] == auth.currentUser!['id']) {
              found = t;
            }
          }
        }
        if (snap.value is Map) {
          (snap.value as Map).forEach(check);
        } else if (snap.value is List) {
          final list = snap.value as List;
          for (var i = 0; i < list.length; i++) {
            if (list[i] != null) check(i, list[i]);
          }
        }
      }
      if (mounted) {
        setState(() {
          _myTemple = found;
          _isLoadingTemple = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingTemple = false;
        });
      }
    }
  }

  Future<void> _fetchBookingsAndStats() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final client = Provider.of<ApiClient>(context, listen: false);
    
    try {
      final data = await client.get('/bookings/history?user_id=${auth.currentUser!['id']}');
      if (mounted) {
        setState(() {
          _templeBookings = data;
          _isLoadingBookings = false;
          _bookingsError = null;
        });
      }
      await auth.fetchTempleStats();
      await auth.fetchTemplePriests();
    } catch (e) {
      if (mounted) {
        setState(() {
          _bookingsError = e.toString().replaceAll('Exception: ', '');
          _isLoadingBookings = false;
        });
      }
    }
  }

  void _searchPriest() async {
    final email = _searchEmailController.text.trim();
    if (email.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isSearchingPriest = true;
      _searchedPriest = null;
      _searchError = null;
    });

    final res = await auth.searchPriestByEmail(email);
    if (mounted) {
      setState(() {
        _isSearchingPriest = false;
        if (res != null) {
          _searchedPriest = res;
        } else {
          _searchError = auth.errorMessage ?? "Priest not found.";
        }
      });
    }
  }

  void _sendInvitation(int priestId, String priestName, List<dynamic> associations) {
    // Check if priest is already associated with other temples, if so warn before sending
    if (associations.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'Confirm Invite Send',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
            ),
            content: Text(
              '$priestName is already linked with ${associations.join(', ')}. Sending an invitation will allow them to associate with your temple as well. Proceed?',
              style: GoogleFonts.outfit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.outfit(color: SevaTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _executeInvite();
                },
                child: const Text('Send Invite'),
              ),
            ],
          );
        },
      );
    } else {
      _executeInvite();
    }
  }

  void _executeInvite() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.sendPriestInvitation(_searchEmailController.text.trim());
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation successfully sent to priest!'),
          backgroundColor: SevaTheme.primaryMaroon,
        ),
      );
      setState(() {
        _searchedPriest = null;
        _searchEmailController.clear();
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to send invitation.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildBookingsTab(AuthProvider auth) {
    if (_isLoadingBookings) {
      return const Center(child: CircularProgressIndicator(color: SevaTheme.primaryMaroon));
    }

    if (_bookingsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_bookingsError', style: GoogleFonts.outfit(fontSize: 14)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _fetchBookingsAndStats, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final stats = auth.templeStats;
    final totalRev = stats?['total_revenue'] ?? 0.0;
    final totalBook = stats?['total_bookings'] ?? 0;

    return RefreshIndicator(
      onRefresh: _fetchBookingsAndStats,
      color: SevaTheme.primaryMaroon,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stat cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: SevaTheme.primaryMaroon.withOpacity(0.04),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(Icons.currency_rupee, color: SevaTheme.secondaryGold, size: 28),
                          const SizedBox(height: 6),
                          Text('Total Income', style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textMuted)),
                          Text(
                            '₹$totalRev',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: SevaTheme.primaryMaroon.withOpacity(0.04),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long_outlined, color: SevaTheme.secondaryGold, size: 28),
                          const SizedBox(height: 6),
                          Text('Total Orders', style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textMuted)),
                          Text(
                            '$totalBook',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              'Order & Booking History',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: SevaTheme.primaryMaroon),
            ),
            const SizedBox(height: 8),
            
            _templeBookings.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Text('No orders received yet.', style: GoogleFonts.outfit(color: SevaTheme.textMuted)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _templeBookings.length,
                    itemBuilder: (context, index) {
                      final b = _templeBookings[index];
                      final isAccepted = b['status'] == 'accepted';
                      final isDeclined = b['status'] == 'declined';
                      
                      Color statCol = Colors.orange;
                      if (isAccepted) statCol = Colors.green;
                      if (isDeclined) statCol = Colors.red;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            b['service_name'],
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Attendee: ${b['attendee_name']} | Date: ${b['booking_date']}', style: GoogleFonts.outfit(fontSize: 11)),
                              Text('Timing: ${b['slot_time']} | Price: ₹${b['price']}', style: GoogleFonts.outfit(fontSize: 11)),
                              if (isAccepted && b['room_code'] != null && b['room_code'].toString().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: SevaTheme.primaryMaroon,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      onPressed: () => _joinVideoCall(context, b),
                                      icon: const Icon(Icons.video_call_rounded, color: Colors.white, size: 14),
                                      label: Text('Join Video', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Code: ${b['room_code']}', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: SevaTheme.textCharcoal)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: statCol.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              b['status'].toUpperCase(),
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: statCol),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriestsTab(AuthProvider auth) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: SevaTheme.primaryMaroon,
            unselectedLabelColor: SevaTheme.textMuted,
            indicatorColor: SevaTheme.secondaryGold,
            tabs: const [
              Tab(text: 'Current Priests', icon: Icon(Icons.people_alt_outlined, size: 18)),
              Tab(text: 'Invite New Priest', icon: Icon(Icons.person_add_alt_1_outlined, size: 18)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 1. Current Priests list
                RefreshIndicator(
                  onRefresh: () => auth.fetchTemplePriests(),
                  child: auth.templePriests.isEmpty
                      ? Center(
                          child: Text(
                            'No priests linked to this temple roster.',
                            style: GoogleFonts.outfit(color: SevaTheme.textMuted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: auth.templePriests.length,
                          itemBuilder: (context, index) {
                            final p = auth.templePriests[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: SevaTheme.primaryMaroon.withOpacity(0.1),
                                  child: Text(
                                    p['full_name'][0].toUpperCase(),
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                                  ),
                                ),
                                title: Text(p['full_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                subtitle: Text('Email: ${p['email']} | Mobile: ${p['mobile']}\nAddress: ${p['address']}', style: GoogleFonts.outfit(fontSize: 11)),
                              ),
                            );
                          },
                        ),
                ),

                // 2. Invite Priest Search View
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Recruit Priests',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: SevaTheme.primaryMaroon),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Search priests by email to send temple association invites.',
                        style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textMuted),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Priest Email Address',
                                prefixIcon: Icon(Icons.search),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _searchPriest,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            child: const Icon(Icons.arrow_forward),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (_isSearchingPriest)
                        const Center(child: CircularProgressIndicator(color: SevaTheme.primaryMaroon)),

                      if (_searchError != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _searchError!,
                            style: GoogleFonts.outfit(color: Colors.red.shade900, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      if (_searchedPriest != null) ...[
                        Card(
                          color: SevaTheme.surfaceStone,
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Priest Profile Found:',
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: SevaTheme.secondaryGold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchedPriest!['full_name'],
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                                ),
                                Text('Email: ${_searchedPriest!['email']}', style: GoogleFonts.outfit(fontSize: 12)),
                                Text('Gender: ${_searchedPriest!['gender']} | Address: ${_searchedPriest!['address']}', style: GoogleFonts.outfit(fontSize: 12)),
                                const SizedBox(height: 12),
                                if (_searchedPriest!['associated_temples'] != null &&
                                    List.from(_searchedPriest!['associated_temples']).isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amber.shade700.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      '⚠️ Working at: ${List.from(_searchedPriest!['associated_temples']).join(', ')}',
                                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                ElevatedButton(
                                  onPressed: () => _sendInvitation(
                                    _searchedPriest!['id'],
                                    _searchedPriest!['full_name'],
                                    List.from(_searchedPriest!['associated_temples'] ?? []),
                                  ),
                                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                                  child: const Text('Send Association Invite'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const Sidebar(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white, size: 28),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TEMPLE PORTAL',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: SevaTheme.secondaryGold),
            ),
            Text(
              auth.currentUser?['full_name'] ?? 'Manage Temple Admin Roster',
              style: GoogleFonts.outfit(fontSize: 10, color: Colors.white.withOpacity(0.8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              auth.logout();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out successfully.')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Orders & Revenue', icon: Icon(Icons.dashboard_customize_outlined, size: 20)),
            Tab(text: 'Priests Management', icon: Icon(Icons.manage_accounts_outlined, size: 20)),
            Tab(text: 'Services & Slots', icon: Icon(Icons.volunteer_activism_outlined, size: 20)),
            Tab(text: 'Video', icon: Icon(Icons.video_call_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsTab(auth),
          _buildPriestsTab(auth),
          _buildServicesTab(auth),
          const VideoTab(),
        ],
      ),
    );
  }

  Future<void> _fetchTempleServices() async {
    if (_myTemple == null) return;
    setState(() {
      _isLoadingServices = true;
      _servicesError = null;
    });

    try {
      final snap = await FirebaseDatabase.instance.ref('Seva-v1/services').get();
      final List<dynamic> tempServices = [];
      if (snap.exists && snap.value != null) {
        void addService(dynamic val) {
          if (val is Map) {
            final s = Map<String, dynamic>.from(val);
            if (s['temple_id'] == _myTemple!['id']) {
              tempServices.add(s);
            }
          }
        }
        if (snap.value is Map) {
          (snap.value as Map).values.forEach(addService);
        } else if (snap.value is List) {
          (snap.value as List).forEach(addService);
        }
      }
      if (mounted) {
        setState(() {
          _fetchedServices = tempServices;
          _isLoadingServices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _servicesError = e.toString();
          _isLoadingServices = false;
        });
      }
    }
  }

  void _showCreateServiceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Create New Service',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _serviceNameController,
                  decoration: const InputDecoration(labelText: 'Service Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _servicePriceController,
                  decoration: const InputDecoration(labelText: 'Price (₹) *'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serviceDurationController,
                  decoration: const InputDecoration(labelText: 'Duration (e.g. 45 mins) *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serviceDescController,
                  decoration: const InputDecoration(labelText: 'Description *'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _serviceNameController.text.trim();
                final price = double.tryParse(_servicePriceController.text.trim()) ?? 0.0;
                final dur = _serviceDurationController.text.trim();
                final desc = _serviceDescController.text.trim();

                if (name.isEmpty || price <= 0 || dur.isEmpty || desc.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields correctly.')),
                  );
                  return;
                }

                final auth = Provider.of<AuthProvider>(context, listen: false);
                final success = await auth.createTempleService(
                  templeId: _myTemple!['id'],
                  name: name,
                  price: price,
                  description: desc,
                  duration: dur,
                );

                if (success && context.mounted) {
                  Navigator.pop(context);
                  _serviceNameController.clear();
                  _servicePriceController.clear();
                  _serviceDurationController.clear();
                  _serviceDescController.clear();
                  _fetchTempleServices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Service created successfully!')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServicesTab(AuthProvider auth) {
    if (_isLoadingTemple) {
      return const Center(child: CircularProgressIndicator(color: SevaTheme.primaryMaroon));
    }
    if (_myTemple == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No temple profile registered under your admin account. Please complete your registration.',
            style: GoogleFonts.outfit(color: SevaTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_selectedServiceForSlots != null) {
      return _buildSlotsConfigurationView();
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SevaTheme.primaryMaroon,
        onPressed: _showCreateServiceDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Service', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTempleServices,
        color: SevaTheme.primaryMaroon,
        child: _isLoadingServices
            ? const Center(child: CircularProgressIndicator(color: SevaTheme.primaryMaroon))
            : _servicesError != null
                ? Center(child: Text(_servicesError!))
                : _fetchedServices.isEmpty
                    ? Center(
                        child: Text(
                          'No services created yet. Click Add Service below.',
                          style: GoogleFonts.outfit(color: SevaTheme.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _fetchedServices.length,
                        itemBuilder: (context, index) {
                          final s = _fetchedServices[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        s['name'],
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: SevaTheme.primaryMaroon),
                                      ),
                                      Text(
                                        '₹${s['price']}',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: SevaTheme.secondaryGold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s['description'] ?? '',
                                    style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textCharcoal),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Duration: ${s['duration']}', style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.textMuted)),
                                      TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _selectedServiceForSlots = s['id'];
                                            _selectedServiceNameForSlots = s['name'];
                                            _slotsConfigDate = DateTime.now().add(const Duration(days: 1));
                                          });
                                        },
                                        icon: const Icon(Icons.calendar_month, size: 14, color: SevaTheme.primaryMaroon),
                                        label: Text('Configure Slots', style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.primaryMaroon, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildSlotsConfigurationView() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_slotsConfigDate!);
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    
    // Custom calendar calculations
    final daysCount = DateTime(_slotsConfigDate!.year, _slotsConfigDate!.month + 1, 0).day;
    final int offset = DateTime(_slotsConfigDate!.year, _slotsConfigDate!.month, 1).weekday % 7;
    final monthName = DateFormat('MMMM yyyy').format(_slotsConfigDate!);
    final isCurrentMonth = _slotsConfigDate!.year == now.year && _slotsConfigDate!.month == now.month;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: SevaTheme.primaryMaroon),
                onPressed: () => setState(() => _selectedServiceForSlots = null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Manage Slots: $_selectedServiceNameForSlots',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: SevaTheme.primaryMaroon),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Calendar for Temple Admin
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SevaTheme.primaryMaroon.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: isCurrentMonth ? Colors.grey.shade400 : SevaTheme.primaryMaroon, size: 20),
                        onPressed: isCurrentMonth ? null : () {
                          setState(() {
                            _slotsConfigDate = DateTime(_slotsConfigDate!.year, _slotsConfigDate!.month - 1, 1);
                          });
                        },
                      ),
                      Text(
                        monthName.toUpperCase(),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: SevaTheme.primaryMaroon),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: SevaTheme.primaryMaroon, size: 20),
                        onPressed: () {
                          setState(() {
                            _slotsConfigDate = DateTime(_slotsConfigDate!.year, _slotsConfigDate!.month + 1, 1);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Weekday headers
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
                    return Center(child: Text(days[index], style: GoogleFonts.outfit(fontSize: 8, color: SevaTheme.textMuted)));
                  },
                ),

                // Days grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                  ),
                  padding: const EdgeInsets.all(4.0),
                  itemCount: offset + daysCount,
                  itemBuilder: (context, index) {
                    if (index < offset) return const SizedBox.shrink();
                    final day = index - offset + 1;
                    final date = DateTime(_slotsConfigDate!.year, _slotsConfigDate!.month, day);
                    final isPast = date.isBefore(todayMidnight);
                    final isSelected = _slotsConfigDate!.year == date.year &&
                        _slotsConfigDate!.month == date.month &&
                        _slotsConfigDate!.day == date.day;

                    return GestureDetector(
                      onTap: isPast ? null : () => setState(() => _slotsConfigDate = date),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? SevaTheme.primaryMaroon
                              : (isPast ? Colors.grey.shade100 : Colors.green.shade50),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? SevaTheme.secondaryGold
                                : (isPast ? Colors.grey.shade200 : Colors.green.shade200),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            day.toString(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: isSelected
                                  ? Colors.white
                                  : (isPast ? Colors.grey.shade400 : SevaTheme.textCharcoal),
                            ),
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

          Text(
            'Slots Configured for ${DateFormat('dd MMMM yyyy').format(_slotsConfigDate!)}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: SevaTheme.primaryMaroon),
          ),
          const SizedBox(height: 10),

          // Real-time custom slots viewer & deletor
          StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('Seva-v1/services/$_selectedServiceForSlots/slots/$dateStr')
                .onValue,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: SevaTheme.primaryMaroon));
              }

              final data = snapshot.data?.snapshot.value;
              final List<Map<String, dynamic>> slots = [];
              if (data != null) {
                void addSlot(dynamic k, dynamic v) {
                  if (v is Map) {
                    slots.add(Map<String, dynamic>.from(v));
                  }
                }
                if (data is Map) {
                  data.forEach(addSlot);
                } else if (data is List) {
                  for (var i = 0; i < data.length; i++) {
                    if (data[i] != null) addSlot(i, data[i]);
                  }
                }
              }

              slots.sort((a, b) => a['from'].toString().compareTo(b['from'].toString()));

              if (slots.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No custom timeslots defined. Standard fallback slots will be shown to devotees.',
                      style: GoogleFonts.outfit(color: SevaTheme.textMuted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: slots.length,
                itemBuilder: (context, index) {
                  final s = slots[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      dense: true,
                      title: Text('${s['from']} - ${s['to']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('Max Attendees capacity: ${s['capacity']}', style: GoogleFonts.outfit(fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          await FirebaseDatabase.instance
                              .ref('Seva-v1/services/$_selectedServiceForSlots/slots/$dateStr/${s['id']}')
                              .remove();
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),

          // Add Slot Form Card
          Card(
            color: SevaTheme.surfaceStone,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ADD TIMESLOT',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: SevaTheme.primaryMaroon, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _slotFromController,
                          decoration: const InputDecoration(labelText: 'From (HH:mm)', hintText: '09:00', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                          style: GoogleFonts.outfit(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _slotToController,
                          decoration: const InputDecoration(labelText: 'To (HH:mm)', hintText: '10:30', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                          style: GoogleFonts.outfit(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _slotCapacityController,
                          decoration: const InputDecoration(labelText: 'Capacity', hintText: '5', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.outfit(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final from = _slotFromController.text.trim();
                      final to = _slotToController.text.trim();
                      final cap = int.tryParse(_slotCapacityController.text.trim()) ?? 0;

                      if (from.isEmpty || to.isEmpty || cap <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all slot fields correctly.')),
                        );
                        return;
                      }

                      // Check 24hr time format
                      final timeReg = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
                      if (!timeReg.hasMatch(from) || !timeReg.hasMatch(to)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Times must be in 24-hour HH:mm format (e.g. 09:00).')),
                        );
                        return;
                      }

                      // Retrieve current slots for overlap checking
                      final snap = await FirebaseDatabase.instance
                          .ref('Seva-v1/services/$_selectedServiceForSlots/slots/$dateStr')
                          .get();
                      final List<Map<String, dynamic>> currentSlots = [];
                      if (snap.exists && snap.value != null) {
                        void parseSlot(dynamic v) {
                          if (v is Map) currentSlots.add(Map<String, dynamic>.from(v));
                        }
                        if (snap.value is Map) {
                          (snap.value as Map).values.forEach(parseSlot);
                        } else if (snap.value is List) {
                          for (final v in snap.value as List) {
                            if (v != null) parseSlot(v);
                          }
                        }
                      }

                      int timeToMin(String time) {
                        final p = time.split(':');
                        return int.parse(p[0]) * 60 + int.parse(p[1]);
                      }

                      final newStart = timeToMin(from);
                      final newEnd = timeToMin(to);

                      if (newStart >= newEnd) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('From time must be before To time.')),
                        );
                        return;
                      }

                      bool hasOverlap = false;
                      String overlapRange = "";
                      for (final s in currentSlots) {
                        final sStart = timeToMin(s['from']);
                        final sEnd = timeToMin(s['to']);
                        if (newStart < sEnd && newEnd > sStart) {
                          hasOverlap = true;
                          overlapRange = "${s['from']} - ${s['to']}";
                          break;
                        }
                      }

                      if (hasOverlap) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red, size: 24),
                                const SizedBox(width: 8),
                                Text('Overlap Conflict!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red)),
                              ],
                            ),
                            content: Text('The timeslot $from - $to overlaps with an existing slot: $overlapRange! Please enter a non-overlapping range.'),
                            actions: [
                              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                            ],
                          ),
                        );
                        return;
                      }

                      // Write to database
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      await auth.addTempleServiceSlot(
                        serviceId: _selectedServiceForSlots!,
                        dateStr: dateStr,
                        from: from,
                        to: to,
                        capacity: cap,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Timeslot created successfully!')),
                      );
                    },
                    child: const Text('Add Timeslot'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
