import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme.dart';
import '../home/sidebar.dart';
import '../video/video_tab.dart';
import '../video/video_call_screen.dart';

class PriestDashboard extends StatefulWidget {
  const PriestDashboard({super.key});

  @override
  State<PriestDashboard> createState() => _PriestDashboardState();
}

class _PriestDashboardState extends State<PriestDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<dynamic> _serviceOrders = [];
  bool _isLoadingOrders = true;
  String? _ordersError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchOrders();
    // Also fetch invitations immediately
    Provider.of<AuthProvider>(context, listen: false).fetchPriestInvitations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _fetchOrders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final client = Provider.of<ApiClient>(context, listen: false);
    try {
      final data = await client.get('/bookings/history?user_id=${auth.currentUser!['id']}');
      if (mounted) {
        setState(() {
          _serviceOrders = data;
          _isLoadingOrders = false;
          _ordersError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ordersError = e.toString().replaceAll('Exception: ', '');
          _isLoadingOrders = false;
        });
      }
    }
  }

  Future<void> _respondToBooking(int bookingId, String responseStatus) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final client = Provider.of<ApiClient>(context, listen: false);
    
    setState(() => _isLoadingOrders = true);
    
    try {
      await client.post('/bookings/respond?booking_id=$bookingId&priest_id=${auth.currentUser!['id']}&status=$responseStatus', {});
      await _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service order successfully $responseStatus.'),
            backgroundColor: SevaTheme.primaryMaroon,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (_) {}
  }

  Widget _buildOrdersTab(AuthProvider auth, ApiClient client) {
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator(color: SevaTheme.primaryMaroon));
    }

    if (_ordersError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_ordersError', style: GoogleFonts.outfit(fontSize: 14)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _fetchOrders, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_serviceOrders.isEmpty) {
      return Center(
        child: Text(
          'No service orders received yet.',
          style: GoogleFonts.outfit(color: SevaTheme.textMuted),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: SevaTheme.primaryMaroon,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _serviceOrders.length,
        itemBuilder: (context, index) {
          final order = _serviceOrders[index];
          final isPending = order['status'] == 'pending';
          final isAccepted = order['status'] == 'accepted';
          final isDeclined = order['status'] == 'declined';
          
          Color statusColor = Colors.orange;
          if (isAccepted) statusColor = Colors.green;
          if (isDeclined) statusColor = Colors.red;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order['service_name'],
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: SevaTheme.primaryMaroon),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order['status'].toUpperCase(),
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    order['temple_name'],
                    style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.secondaryGold, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scheduled: ${order['booking_date']} | ${order['slot_time']}',
                    style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textMuted),
                  ),
                  Text(
                    'Attendee: ${order['attendee_name']}',
                    style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textCharcoal),
                  ),
                  const SizedBox(height: 12),
                  
                  if (isPending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _respondToBooking(order['id'], 'declined'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _respondToBooking(order['id'], 'accepted'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (isAccepted && order['devotee_contact'] != null) ...[
                    const Divider(),
                    const SizedBox(height: 6),
                    Text(
                      '📞 Devotee Contact Details (Shared):',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: SevaTheme.textCharcoal),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order['devotee_contact']['name'] ?? '',
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                              ),
                              if (order['devotee_contact']['address'] != null && order['devotee_contact']['address'].toString().isNotEmpty)
                                Text(
                                  order['devotee_contact']['address'],
                                  style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.textMuted),
                                ),
                              Text(
                                'Email: ${order['devotee_contact']['email'] ?? ''}',
                                style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () => _makeCall(order['devotee_contact']['mobile'] ?? ''),
                        ),
                      ],
                    ),
                  ],
                  if (isAccepted && order['room_code'] != null && order['room_code'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.video_call_rounded, color: SevaTheme.primaryMaroon, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Meeting Room Code:',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: SevaTheme.textCharcoal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order['room_code'].toString(),
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon, letterSpacing: 2),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SevaTheme.primaryMaroon,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _joinVideoCall(context, order),
                        icon: const Icon(Icons.video_call_rounded, color: Colors.white),
                        label: Text('Join Video Call', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInvitationsTab(AuthProvider auth) {
    if (auth.priestInvitations.isEmpty) {
      return Center(
        child: Text(
          'No temple invites received yet.',
          style: GoogleFonts.outfit(color: SevaTheme.textMuted),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => auth.fetchPriestInvitations(),
      color: SevaTheme.primaryMaroon,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: auth.priestInvitations.length,
        itemBuilder: (context, index) {
          final invite = auth.priestInvitations[index];
          final isPending = invite['status'] == 'pending';
          final isAccepted = invite['status'] == 'accepted';
          final isDeclined = invite['status'] == 'declined';

          Color statusColor = Colors.orange;
          if (isAccepted) statusColor = Colors.green;
          if (isDeclined) statusColor = Colors.red;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          invite['temple_name'],
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: SevaTheme.primaryMaroon),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          invite['status'].toUpperCase(),
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Association request to join temple priesthood roster.',
                    style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  
                  if (isPending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final success = await auth.respondToInvitation(invite['id'], 'declined');
                              if (success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invitation declined.')),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final success = await auth.respondToInvitation(invite['id'], 'accepted');
                              if (success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invitation accepted! You are now linked to this temple.')),
                                );
                                _fetchOrders(); // Reload orders in case of automatic updates
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Accept Invite'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final client = Provider.of<ApiClient>(context);

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
              'PRIEST PORTAL',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: SevaTheme.secondaryGold),
            ),
            Text(
              'Manage Service Orders & Associations',
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
            Tab(text: 'Service Orders', icon: Icon(Icons.assignment_outlined, size: 20)),
            Tab(text: 'Temple Invites', icon: Icon(Icons.mail_outline, size: 20)),
            Tab(text: 'Video', icon: Icon(Icons.video_call_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersTab(auth, client),
          _buildInvitationsTab(auth),
          const VideoTab(),
        ],
      ),
    );
  }
}
