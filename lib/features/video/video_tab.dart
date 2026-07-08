import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme.dart';
import 'video_call_screen.dart';

/// Video tab — allows users to enter a room code manually or join from a booking.
/// Shown as the last tab in the devotee tab bar.
class VideoTab extends StatefulWidget {
  const VideoTab({super.key});

  @override
  State<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends State<VideoTab> {
  final _codeController = TextEditingController();
  bool _isJoining = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
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

  Future<void> _joinWithCode(BuildContext context) async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a meeting code.');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final client = Provider.of<ApiClient>(context, listen: false);

    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      // Look up the meeting in Firebase
      final snap = await FirebaseDatabase.instance.ref('Seva-v1/meetings').get();
      Map<String, dynamic>? meeting;

      if (snap.exists && snap.value != null) {
        void check(dynamic v) {
          if (v is Map) {
            final m = Map<String, dynamic>.from(v);
            // Check if this code matches the room code OR any of the join codes
            if (m['room_code']?.toString().toUpperCase() == code) {
              meeting = m;
            } else {
              final joinCodes = m['join_codes'];
              if (joinCodes is List) {
                if (joinCodes.any((c) => c?.toString().toUpperCase() == code)) {
                  meeting = m;
                }
              } else if (joinCodes is Map) {
                if (joinCodes.values.any((c) => c?.toString().toUpperCase() == code)) {
                  meeting = m;
                }
              }
            }
          }
        }
        if (snap.value is Map) {
          (snap.value as Map).values.forEach(check);
        } else if (snap.value is List) {
          (snap.value as List).forEach(check);
        }
      }

      if (meeting == null) {
        setState(() {
          _error = 'Meeting not found. Please check the code and try again.';
          _isJoining = false;
        });
        return;
      }

      // Check expiry
      final expiresAtStr = meeting!['expires_at'] as String?;
      DateTime? expiresAt;
      if (expiresAtStr != null) {
        expiresAt = DateTime.tryParse(expiresAtStr);
      }
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        setState(() {
          _error = 'This meeting link has expired.';
          _isJoining = false;
        });
        return;
      }

      // Determine if current user is the host
      final userId = auth.currentUser?['id'];
      final priestId = meeting!['priest_id'];
      final isHost = userId != null && (userId == priestId || auth.currentUser?['role'] == 'temple');

      // Get signaling URL from ApiClient base URL  
      final signalingBase = client.baseUrl.replaceAll('/api', '').replaceAll(':8000', ':8001');
      final dynamicUrl = await _getDynamicSignalingUrl(signalingBase);

      setState(() => _isJoining = false);

      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              roomCode: meeting!['room_code'] ?? code,
              displayName: auth.currentUser?['full_name'] ?? 'Participant',
              isHost: isHost,
              priestName: meeting!['priest_name'] ?? 'Priest',
              serviceName: meeting!['service_name'] ?? 'Seva',
              signalingUrl: dynamicUrl,
              expiresAt: expiresAt,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString().replaceAll("Exception: ", "")}';
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [SevaTheme.primaryMaroon, Color(0xFF6B1010)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.video_call_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seva Video Connect',
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Join a seva session with your priest',
                        style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Code entry card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Meeting Code',
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the code shared with you after your booking was accepted.',
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'XXXXXXXX',
                        hintStyle: GoogleFonts.outfit(
                          color: Colors.white24,
                          fontSize: 22,
                          letterSpacing: 6,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF21262D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: SevaTheme.secondaryGold, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        prefixIcon: const Icon(Icons.vpn_key_outlined, color: SevaTheme.secondaryGold),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!,
                          style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 12)),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SevaTheme.primaryMaroon,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isJoining ? null : () => _joinWithCode(context),
                        icon: _isJoining
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.video_call_rounded, color: Colors.white),
                        label: Text(
                          _isJoining ? 'Connecting...' : 'Join Meeting',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Info cards
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: SevaTheme.secondaryGold.withOpacity( 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SevaTheme.secondaryGold.withOpacity( 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: SevaTheme.secondaryGold, size: 18),
                        const SizedBox(width: 8),
                        Text('How it works',
                            style: GoogleFonts.outfit(
                                color: SevaTheme.secondaryGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoRow('1.', 'Book a seva service from the Temples tab'),
                    _infoRow('2.', 'Once your booking is accepted, you\'ll receive meeting code(s) — one per attendee'),
                    _infoRow('3.', 'Find your codes in the Bookings tab, or enter the code here'),
                    _infoRow('4.', 'The priest will start the session; you\'ll see a waiting screen until they join'),
                    _infoRow('5.', 'Meeting links expire 30 minutes after the scheduled end time'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Recent bookings quick-join (if logged in and has accepted bookings with codes)
              if (auth.isLoggedIn) _buildQuickJoin(context, auth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(num,
              style: GoogleFonts.outfit(color: SevaTheme.secondaryGold, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildQuickJoin(BuildContext context, AuthProvider auth) {
    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref('Seva-v1/bookings').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.snapshot.value;
        if (data == null) return const SizedBox.shrink();

        final userId = auth.currentUser?['id'];
        final role = auth.currentUser?['role'] ?? 'devotee';
        final List<Map<String, dynamic>> myBookingsWithCodes = [];

        void check(dynamic v) {
          if (v is Map) {
            final b = Map<String, dynamic>.from(v);
            final hasCode = b['room_code'] != null && b['room_code'].toString().isNotEmpty;
            if (!hasCode) return;
            if (role == 'devotee' && b['user_id'] == userId) {
              myBookingsWithCodes.add(b);
            } else if ((role == 'priest' || role == 'temple') && b['priest_id'] == userId) {
              myBookingsWithCodes.add(b);
            }
          }
        }

        if (data is Map) {
          data.values.forEach(check);
        } else if (data is List) {
          data.forEach(check);
        }

        if (myBookingsWithCodes.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Join',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...myBookingsWithCodes.take(3).map((b) {
              final codes = b['join_codes'];
              String codesDisplay = b['room_code']?.toString() ?? '';
              if (codes is List && codes.isNotEmpty) {
                codesDisplay = codes.take(2).join(', ');
                if (codes.length > 2) codesDisplay += '…';
              }
              return Card(
                color: const Color(0xFF161B22),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white12),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: SevaTheme.primaryMaroon.withOpacity( 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.video_call_rounded, color: SevaTheme.primaryMaroon, size: 22),
                  ),
                  title: Text(
                    b['service_name']?.toString() ?? 'Seva Session',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Codes: $codesDisplay\n${b['booking_date'] ?? ''} | ${b['slot_time'] ?? ''}',
                    style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SevaTheme.primaryMaroon,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      _codeController.text = b['room_code']?.toString() ?? '';
                      await _joinWithCode(context);
                    },
                    child: Text('Join', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12)),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
