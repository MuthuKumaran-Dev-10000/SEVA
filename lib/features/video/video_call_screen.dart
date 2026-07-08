import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import 'video_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomCode;
  final String displayName;
  final bool isHost;
  final String priestName;
  final String serviceName;
  final String signalingUrl;
  final DateTime? expiresAt;

  const VideoCallScreen({
    super.key,
    required this.roomCode,
    required this.displayName,
    required this.isHost,
    required this.priestName,
    required this.serviceName,
    required this.signalingUrl,
    this.expiresAt,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> with WidgetsBindingObserver {
  // Local renderer
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  VideoService? _videoService;

  // UI state
  List<RemoteParticipant> _participants = [];
  bool _hostJoined = false;
  bool _audioMuted = false;
  bool _videoOff = false;
  bool _showChat = false;
  bool _isInitializing = true;
  String? _initError;

  // Chat state
  final List<Map<String, String>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // Expiry timer
  Timer? _expiryTimer;
  Duration _timeUntilExpiry = Duration.zero;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preventScreenCapture();
    _initVideoCall();
    _startExpiryTimer();
  }

  void _preventScreenCapture() {
    // Prevent screenshots and screen recording on Android
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Note: FLAG_SECURE is set in MainActivity.kt for Android
  }

  Future<void> _initVideoCall() async {
    // Check expiry first
    if (widget.expiresAt != null && DateTime.now().isAfter(widget.expiresAt!)) {
      setState(() {
        _isExpired = true;
        _isInitializing = false;
      });
      return;
    }

    try {
      await _localRenderer.initialize();

      _videoService = VideoService(
        signalingUrl: widget.signalingUrl,
        roomCode: widget.roomCode,
        displayName: widget.displayName,
        isHost: widget.isHost,
      );

      _videoService!.onLocalStreamReady = (stream) {
        if (mounted) {
          setState(() {
            _localRenderer.srcObject = stream;
          });
        }
      };

      _videoService!.onParticipantsChanged = (participants) {
        if (mounted) {
          setState(() {
            _participants = participants;
          });
        }
      };

      _videoService!.onHostStatusChanged = (hostJoined, hostName) {
        if (mounted) {
          setState(() {
            _hostJoined = hostJoined;
          });
        }
      };

      _videoService!.onChatMessage = (sender, message, time) {
        if (mounted) {
          setState(() {
            _chatMessages.add({'sender': sender, 'message': message, 'time': time});
          });
          _scrollChatToBottom();
        }
      };

      _videoService!.onCallEnded = (reason) {
        if (mounted) {
          _showCallEndedDialog(reason);
        }
      };

      await _videoService!.initialize();

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'Could not join meeting: ${e.toString().replaceAll("Exception: ", "")}';
          _isInitializing = false;
        });
      }
    }
  }

  void _startExpiryTimer() {
    if (widget.expiresAt == null) return;
    _expiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (now.isAfter(widget.expiresAt!)) {
        setState(() {
          _isExpired = true;
          _timeUntilExpiry = Duration.zero;
        });
        _expiryTimer?.cancel();
        _handleLeave();
      } else {
        setState(() {
          _timeUntilExpiry = widget.expiresAt!.difference(now);
        });
      }
    });
  }

  void _scrollChatToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleAudio() {
    _videoService?.toggleAudio();
    setState(() => _audioMuted = !_audioMuted);
  }

  void _toggleVideo() {
    _videoService?.toggleVideo();
    setState(() => _videoOff = !_videoOff);
  }

  void _sendChat() {
    final msg = _chatController.text.trim();
    if (msg.isEmpty) return;
    _videoService?.sendChatMessage(msg);
    _chatController.clear();
  }

  Future<void> _handleLeave() async {
    await _videoService?.dispose();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showCallEndedDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            Text('Meeting Update',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(reason, style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              _handleLeave();
            },
            child: Text('Leave Meeting', style: GoogleFonts.outfit(color: SevaTheme.secondaryGold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SevaTheme.primaryMaroon),
            onPressed: () => Navigator.of(context).pop(), // stay and wait
            child: Text('Stay', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    _localRenderer.dispose();
    _videoService?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isExpired) return _buildExpiredScreen();
    if (_isInitializing) return _buildLoadingScreen();
    if (_initError != null) return _buildErrorScreen();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) await _handleLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: Stack(
          children: [
            // Main video grid
            Column(
              children: [
                // Top bar
                _buildTopBar(),
                // Video area
                Expanded(
                  child: Stack(
                    children: [
                      _buildVideoGrid(),
                      // Chat panel
                      if (_showChat) _buildChatPanel(),
                      // Waiting overlay when host not joined
                      if (!widget.isHost && !_hostJoined) _buildWaitingOverlay(),
                    ],
                  ),
                ),
                // Control bar
                _buildControlBar(),
              ],
            ),
            // Screen record warning (web)
            if (_showScreenRecordWarning) _buildScreenRecordWarning(),
          ],
        ),
      ),
    );
  }

  bool get _showScreenRecordWarning => false; // Set to true if screen share detected

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF161B22),
      child: Row(
        children: [
          // Service name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.serviceName,
                  style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white,
                  ),
                ),
                Text(
                  'Room: ${widget.roomCode}',
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
          // Timer / expiry
          if (widget.expiresAt != null && _timeUntilExpiry > Duration.zero)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _timeUntilExpiry.inMinutes < 10 ? Colors.red.withOpacity( 0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _timeUntilExpiry.inMinutes < 10 ? Colors.redAccent : Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 13,
                      color: _timeUntilExpiry.inMinutes < 10 ? Colors.redAccent : Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(_timeUntilExpiry),
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: _timeUntilExpiry.inMinutes < 10 ? Colors.redAccent : Colors.white54),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          // Participant count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  '${_participants.length + 1}', // +1 for self
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    if (_participants.isEmpty) {
      // Show local user full screen if alone
      return _buildVideoTile(
        renderer: _localRenderer,
        name: '${widget.displayName} (You)',
        isHost: widget.isHost,
        audioMuted: _audioMuted,
        videoOff: _videoOff,
        isMirror: true,
      );
    }

    // Sort remote participants: Priest first, then others
    final sortedRemote = List<RemoteParticipant>.from(_participants);
    sortedRemote.sort((a, b) {
      if (a.isHost && !b.isHost) return -1;
      if (!a.isHost && b.isHost) return 1;
      return a.socketId.compareTo(b.socketId);
    });

    return Stack(
      children: [
        // Fullscreen Remote Participants in PageView
        PageView.builder(
          itemCount: sortedRemote.length,
          itemBuilder: (context, index) {
            final p = sortedRemote[index];
            if (p.renderer == null) return const SizedBox.shrink();
            return _buildVideoTile(
              renderer: p.renderer!,
              name: p.name,
              isHost: p.isHost,
              audioMuted: p.audioMuted,
              videoOff: p.videoOff,
              isMirror: false,
            );
          },
        ),

        // PIP Overlay for Local User (Floating in bottom-right corner)
        Positioned(
          right: 16,
          bottom: 16,
          child: Container(
            width: 110,
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFF1C2128),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  if (!_videoOff)
                    RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  else
                    Center(
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: SevaTheme.primaryMaroon.withOpacity(0.5),
                        child: Text(
                          widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : '?',
                          style: GoogleFonts.outfit(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  // Small labels in PIP
                  Positioned(
                    bottom: 4,
                    left: 4,
                    right: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'You',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_audioMuted)
                          const Icon(Icons.mic_off, size: 10, color: Colors.redAccent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Page Indicator / Swiping tip
        if (sortedRemote.length > 1)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Swipe to view participants • ${_participants.length} online',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoTile({
    required RTCVideoRenderer renderer,
    required String name,
    required bool isHost,
    required bool audioMuted,
    required bool videoOff,
    required bool isMirror,
  }) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2128),
        borderRadius: BorderRadius.circular(12),
        border: isHost
            ? Border.all(color: SevaTheme.secondaryGold, width: 2)
            : Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            // Video or Camera Off screen
            if (!videoOff)
              RTCVideoView(
                renderer,
                mirror: isMirror,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: SevaTheme.primaryMaroon.withOpacity(0.2),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: SevaTheme.secondaryGold, width: 1.5),
                        ),
                        width: 90,
                        height: 90,
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.outfit(fontSize: 36, color: SevaTheme.secondaryGold, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_off, size: 14, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Camera is off',
                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Top-right overlays for mic & video status
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  if (audioMuted)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_off, size: 14, color: Colors.white),
                    ),
                  if (videoOff) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.videocam_off, size: 14, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),

            // Bottom name bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Row(
                  children: [
                    if (isHost)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: SevaTheme.secondaryGold,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRIEST',
                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingOverlay() {
    return Container(
      color: Colors.black.withOpacity( 0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated waiting indicator
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: SevaTheme.primaryMaroon.withOpacity( 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: SevaTheme.secondaryGold, width: 2),
              ),
              child: const Icon(Icons.temple_hindu, color: SevaTheme.secondaryGold, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              '🙏 ${widget.priestName} is on the way...',
              style: GoogleFonts.outfit(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Please wait for the priest to start the session.\nYou can contact them using the Bookings tab.',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: SevaTheme.secondaryGold,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 300,
      child: Container(
        color: const Color(0xFF161B22),
        child: Column(
          children: [
            // Chat header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Text('In-call messages',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => setState(() => _showChat = false),
                  ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _chatMessages.length,
                itemBuilder: (ctx, i) {
                  final m = _chatMessages[i];
                  final isSelf = m['sender'] == widget.displayName;
                  return Align(
                    alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 220),
                      decoration: BoxDecoration(
                        color: isSelf ? SevaTheme.primaryMaroon : const Color(0xFF21262D),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: Radius.circular(isSelf ? 12 : 0),
                          bottomRight: Radius.circular(isSelf ? 0 : 12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isSelf)
                            Text(m['sender'] ?? '',
                                style: GoogleFonts.outfit(fontSize: 10, color: SevaTheme.secondaryGold, fontWeight: FontWeight.bold)),
                          Text(m['message'] ?? '',
                              style: GoogleFonts.outfit(fontSize: 13, color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Chat input
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Send a message...',
                        hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF21262D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendChat(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: SevaTheme.secondaryGold),
                    onPressed: _sendChat,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: const Color(0xFF161B22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mic
          _buildControlBtn(
            icon: _audioMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _audioMuted ? 'Unmute' : 'Mute',
            color: _audioMuted ? Colors.red : Colors.white,
            bgColor: _audioMuted ? Colors.red.withOpacity( 0.2) : Colors.white12,
            onTap: _toggleAudio,
          ),
          const SizedBox(width: 16),
          // Camera
          _buildControlBtn(
            icon: _videoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            label: _videoOff ? 'Start Video' : 'Stop Video',
            color: _videoOff ? Colors.red : Colors.white,
            bgColor: _videoOff ? Colors.red.withOpacity( 0.2) : Colors.white12,
            onTap: _toggleVideo,
          ),
          const SizedBox(width: 16),
          // Chat
          _buildControlBtn(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chat',
            color: _showChat ? SevaTheme.secondaryGold : Colors.white,
            bgColor: _showChat ? SevaTheme.secondaryGold.withOpacity( 0.2) : Colors.white12,
            badge: _chatMessages.isNotEmpty ? '${_chatMessages.length}' : null,
            onTap: () => setState(() => _showChat = !_showChat),
          ),
          const SizedBox(width: 16),
          // Screen share (disabled on web/flutter web)
          _buildControlBtn(
            icon: Icons.screen_share_outlined,
            label: 'Share',
            color: Colors.white38,
            bgColor: Colors.white10,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Screen sharing is not supported in this version for security reasons.',
                      style: GoogleFonts.outfit(fontSize: 12)),
                  backgroundColor: SevaTheme.primaryMaroon,
                ),
              );
            },
          ),
          const SizedBox(width: 32),
          // End call
          GestureDetector(
            onTap: () async {
              final leave = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A2E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('Leave Meeting?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Text('Are you sure you want to leave the meeting?',
                      style: GoogleFonts.outfit(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Stay', style: GoogleFonts.outfit(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Leave', style: GoogleFonts.outfit(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (leave == true) _handleLeave();
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              if (badge != null)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: SevaTheme.primaryMaroon, shape: BoxShape.circle),
                    child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: SevaTheme.secondaryGold),
            const SizedBox(height: 24),
            Text('Connecting to meeting...', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Room: ${widget.roomCode}', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.signal_wifi_connected_no_internet_4_rounded,
                  color: Colors.redAccent, size: 64),
              const SizedBox(height: 24),
              Text('Could Not Join Meeting',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(_initError ?? 'An unknown error occurred.',
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: SevaTheme.primaryMaroon, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                label: Text('Go Back', style: GoogleFonts.outfit(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_off_rounded, color: Colors.amber, size: 72),
              const SizedBox(height: 24),
              Text('Meeting Link Expired',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'This meeting link has expired 30 minutes after the scheduled end time. Please book a new seva session.',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: SevaTheme.primaryMaroon),
                onPressed: () => Navigator.pop(context),
                child: Text('Back to Bookings', style: GoogleFonts.outfit(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenRecordWarning() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Screen recording is not permitted in this session.',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
