import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme.dart';
import '../auth/login_signup_sheet.dart';
import '../video/video_call_screen.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }

    final client = Provider.of<ApiClient>(context, listen: false);
    try {
      final data = await client.get('/bookings/history?user_id=${auth.currentUser!['id']}');
      if (mounted) {
        setState(() {
          _bookings = data;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
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

  Widget _buildContactCard(String title, Map<String, dynamic> contact) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SevaTheme.surfaceStone.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SevaTheme.primaryMaroon.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: SevaTheme.secondaryGold),
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
                      contact['name'] ?? '',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                    ),
                    if (contact['address'] != null && contact['address'].toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact['address'],
                        style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.textMuted),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'Email: ${contact['email'] ?? ''}',
                      style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone, color: Colors.green),
                onPressed: () => _makeCall(contact['mobile'] ?? ''),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: SevaTheme.primaryMaroon.withOpacity(0.15)),
              const SizedBox(height: 16),
              Text(
                'Access Booked Sevas',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
              ),
              const SizedBox(height: 8),
              Text(
                'Please log in to track your slot bookings and view assigned priests\' details.',
                style: GoogleFonts.outfit(fontSize: 13, color: SevaTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const LoginSignupSheet(),
                  );
                },
                child: const Text('Login / Register'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: SevaTheme.primaryMaroon));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.outfit(fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _fetchBookings();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.volunteer_activism, size: 48, color: SevaTheme.primaryMaroon.withOpacity(0.15)),
              const SizedBox(height: 12),
              Text(
                'No Bookings Yet',
                style: GoogleFonts.outfit(color: SevaTheme.textCharcoal, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                'Start your guided booking funnel to reserve a slot.',
                style: GoogleFonts.outfit(color: SevaTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBookings,
      color: SevaTheme.primaryMaroon,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final b = _bookings[index];
          final isAccepted = b['status'] == 'accepted';
          final isDeclined = b['status'] == 'declined';

          Color statusColor = Colors.orange.shade700;
          String statusText = 'Pending Confirmation';
          if (isAccepted) {
            statusColor = Colors.green.shade700;
            statusText = 'Accepted & Scheduled';
          } else if (isDeclined) {
            statusColor = Colors.red.shade700;
            statusText = 'Declined (Refund Initiated)';
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          b['service_name'],
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b['temple_name'],
                    style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.secondaryGold, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scheduled: ${b['booking_date']} | ${b['slot_time']}',
                        style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textMuted),
                      ),
                      Text(
                        '₹${b['price']}',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
                      ),
                    ],
                  ),
                  Text(
                    'Attendee: ${b['attendee_name']}',
                    style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textMuted),
                  ),

                  // If Accepted, display shared contact details + meeting codes + video button
                  if (isAccepted) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 6),
                    Text(
                      '📞 Associated Contacts (Shared):',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: SevaTheme.textCharcoal),
                    ),
                    if (b['temple_contact'] != null)
                      _buildContactCard('Temple Contact', Map<String, dynamic>.from(b['temple_contact'])),
                    if (b['priest_contact'] != null)
                      _buildContactCard('Priest Contact', Map<String, dynamic>.from(b['priest_contact'])),
                    
                    // Meeting codes section
                    if (b['room_code'] != null && b['room_code'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.video_call_rounded, color: SevaTheme.primaryMaroon, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Meeting Codes',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: SevaTheme.textCharcoal),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SevaTheme.primaryMaroon.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: SevaTheme.primaryMaroon.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share these codes with your attendees:',
                              style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.textMuted),
                            ),
                            const SizedBox(height: 8),
                            // Host room code
                            _buildCodeChip('Host Code', b['room_code'].toString()),
                            // Individual attendee codes
                            if (b['join_codes'] != null) ...
                              (b['join_codes'] is List
                                  ? (b['join_codes'] as List).asMap().entries.map((entry) =>
                                      _buildCodeChip('Attendee ${entry.key + 1}', entry.value.toString()))
                                  : <Widget>[]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Join video button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SevaTheme.primaryMaroon,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _joinVideoCall(context, b),
                          icon: const Icon(Icons.video_call_rounded, color: Colors.white, size: 22),
                          label: Text(
                            'Join Video Session',
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCodeChip(String label, String code) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: SevaTheme.primaryMaroon.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label, style: GoogleFonts.outfit(fontSize: 10, color: SevaTheme.primaryMaroon, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              code,
              style: GoogleFonts.outfit(
                fontSize: 15, fontWeight: FontWeight.bold,
                color: SevaTheme.textCharcoal, letterSpacing: 2,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
            },
            child: const Icon(Icons.copy_rounded, size: 16, color: SevaTheme.primaryMaroon),
          ),
        ],
      ),
    );
  }

  Future<String> _getDynamicSignalingUrl(String derivedFallback) async {
    try {
      final snap = await FirebaseDatabase.instance.ref('Seva-v1/signaling_url').get();
      if (snap.exists && snap.value != null) {
        final url = snap.value.toString().trim();
        if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
          // If the URL ends with a slash, strip it
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

    // Check expiry from Firebase meetings node
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

    final role = auth.currentUser?['role'] ?? 'devotee';
    final isHost = role == 'priest' || role == 'temple';

    // Derive signaling URL: same host as API but on port 8001
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
            isHost: isHost,
            priestName: priestName,
            serviceName: serviceName,
            signalingUrl: dynamicUrl,
            expiresAt: expiresAt,
          ),
        ),
      );
    }
  }
}
