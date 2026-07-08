import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Represents a remote participant in the video call
class RemoteParticipant {
  final String socketId;
  String name;
  bool isHost;
  bool audioMuted;
  bool videoOff;
  RTCPeerConnection? peerConnection;
  RTCVideoRenderer? renderer;

  RemoteParticipant({
    required this.socketId,
    required this.name,
    required this.isHost,
    this.audioMuted = false,
    this.videoOff = false,
    this.peerConnection = null,
    this.renderer = null,
  });
}

/// Callback types
typedef OnParticipantsChanged = void Function(List<RemoteParticipant>);
typedef OnHostStatusChanged = void Function(bool hostJoined, String? hostName);
typedef OnChatMessage = void Function(String sender, String message, String time);
typedef OnCallEnded = void Function(String reason);
typedef OnLocalStreamReady = void Function(MediaStream stream);

/// Manages the WebRTC mesh connection and Socket.IO signaling for Seva video calls
class VideoService {
  final String signalingUrl;
  final String roomCode;
  final String displayName;
  final bool isHost;

  IO.Socket? _socket;
  MediaStream? _localStream;
  
  final Map<String, RemoteParticipant> _participants = {};
  
  // Callbacks
  OnParticipantsChanged? onParticipantsChanged;
  OnHostStatusChanged? onHostStatusChanged;
  OnChatMessage? onChatMessage;
  OnCallEnded? onCallEnded;
  OnLocalStreamReady? onLocalStreamReady;

  bool _audioMuted = false;
  bool _videoOff = false;
  bool _disposed = false;
  bool _hostJoined = false;
  String? _hostName;

  bool get audioMuted => _audioMuted;
  bool get videoOff => _videoOff;
  bool get hostJoined => _hostJoined;
  String? get hostName => _hostName;
  MediaStream? get localStream => _localStream;
  List<RemoteParticipant> get participants => _participants.values.toList();

  // STUN/TURN servers — uses Google STUN + optional TURN for NAT traversal
  static final Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      // Free Metered.ca TURN for fallback
      {
        'urls': 'turn:a.relay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:a.relay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  VideoService({
    required this.signalingUrl,
    required this.roomCode,
    required this.displayName,
    required this.isHost,
  });

  /// Initialize local media (camera + mic), then connect to signaling server
  Future<void> initialize() async {
    await _initLocalStream();
    _connectSocket();
  }

  Future<void> _initLocalStream() async {
    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'min': '1280', 'ideal': '1920', 'max': '1920'},
          'height': {'min': '720', 'ideal': '1080', 'max': '1080'},
        },
      };
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      onLocalStreamReady?.call(_localStream!);
    } catch (e) {
      debugPrint('[VideoService] Failed to get local media: $e');
      // Try audio-only fallback or generic lower resolution
      try {
        final fallbackConstraints = {
          'audio': true,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 640},
            'height': {'ideal': 480},
          }
        };
        _localStream = await navigator.mediaDevices.getUserMedia(fallbackConstraints);
        onLocalStreamReady?.call(_localStream!);
      } catch (_) {
        try {
          _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
          onLocalStreamReady?.call(_localStream!);
          _videoOff = true;
        } catch (_) {}
      }
    }
  }

  void _connectSocket() {
    _socket = IO.io(signalingUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.onConnect((_) {
      debugPrint('[VideoService] Socket connected: ${_socket!.id}');
      // Join the room after connecting
      _socket!.emit('join-room', {
        'roomCode': roomCode,
        'name': displayName,
        'isHost': isHost,
        'joinCode': roomCode, // code validation done in Flutter before navigating
      });
    });

    _socket!.on('room-state', _onRoomState);
    _socket!.on('peer-joined', _onPeerJoined);
    _socket!.on('peer-left', _onPeerLeft);
    _socket!.on('host-joined', _onHostJoined);
    _socket!.on('host-left', _onHostLeft);
    _socket!.on('offer', _onOffer);
    _socket!.on('answer', _onAnswer);
    _socket!.on('ice-candidate', _onIceCandidate);
    _socket!.on('chat-message', _onChatMessage);
    _socket!.on('peer-media-state', _onPeerMediaState);
    _socket!.onDisconnect((_) => debugPrint('[VideoService] Socket disconnected'));
    _socket!.onConnectError((e) => debugPrint('[VideoService] Connect error: $e'));

    _socket!.connect();
  }

  // ─── Room State Handler (called when joining) ────────────────────────────
  void _onRoomState(dynamic data) async {
    final state = Map<String, dynamic>.from(data);
    final participants = (state['participants'] as List?) ?? [];
    _hostJoined = state['hostJoined'] ?? false;
    _hostName = state['hostName'];
    
    onHostStatusChanged?.call(_hostJoined, _hostName);

    // Create peer connections to all existing participants
    for (final p in participants) {
      final pMap = Map<String, dynamic>.from(p);
      final sid = pMap['socketId'] as String;
      if (sid == _socket!.id) continue; // skip self
      await _createPeerConnection(sid, pMap['name'] as String, pMap['isHost'] == true, initiator: true);
    }

    // Replay chat history
    final chat = (state['chat'] as List?) ?? [];
    for (final msg in chat) {
      final m = Map<String, dynamic>.from(msg);
      onChatMessage?.call(m['sender'] ?? '', m['message'] ?? '', m['time'] ?? '');
    }
  }

  // ─── New Peer Joined ─────────────────────────────────────────────────────
  void _onPeerJoined(dynamic data) async {
    final d = Map<String, dynamic>.from(data);
    final sid = d['socketId'] as String;
    final name = d['name'] as String;
    final isH = d['isHost'] == true;

    debugPrint('[VideoService] Peer joined: $name ($sid)');
    // The new joiner will send us an offer; we just create the connection without initiating
    await _createPeerConnection(sid, name, isH, initiator: false);
  }

  // ─── Peer Left ───────────────────────────────────────────────────────────
  void _onPeerLeft(dynamic data) async {
    final d = Map<String, dynamic>.from(data);
    final sid = d['socketId'] as String;
    await _removePeer(sid);
    onParticipantsChanged?.call(participants);
  }

  // ─── Host Events ─────────────────────────────────────────────────────────
  void _onHostJoined(dynamic data) {
    final d = Map<String, dynamic>.from(data);
    _hostJoined = true;
    _hostName = d['name'];
    onHostStatusChanged?.call(true, _hostName);
  }

  void _onHostLeft(dynamic data) {
    final d = Map<String, dynamic>.from(data);
    _hostJoined = false;
    onHostStatusChanged?.call(false, d['name']);
    onCallEnded?.call('${d['name'] ?? 'The priest'} has left the meeting.');
  }

  // ─── Offer/Answer/ICE ────────────────────────────────────────────────────
  void _onOffer(dynamic data) async {
    final d = Map<String, dynamic>.from(data);
    final fromId = d['fromId'] as String;
    final fromName = d['fromName'] as String? ?? 'Peer';
    final sdpMap = Map<String, dynamic>.from(d['sdp']);

    // Ensure we have a peer connection for this socket
    if (!_participants.containsKey(fromId)) {
      await _createPeerConnection(fromId, fromName, false, initiator: false);
    }

    final pc = _participants[fromId]!.peerConnection!;
    await pc.setRemoteDescription(RTCSessionDescription(sdpMap['sdp'], sdpMap['type']));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    _socket!.emit('answer', {
      'targetId': fromId,
      'sdp': {'sdp': answer.sdp, 'type': answer.type},
      'roomCode': roomCode,
    });
  }

  void _onAnswer(dynamic data) async {
    final d = Map<String, dynamic>.from(data);
    final fromId = d['fromId'] as String;
    final sdpMap = Map<String, dynamic>.from(d['sdp']);

    final pc = _participants[fromId]?.peerConnection;
    if (pc != null) {
      await pc.setRemoteDescription(RTCSessionDescription(sdpMap['sdp'], sdpMap['type']));
    }
  }

  void _onIceCandidate(dynamic data) async {
    final d = Map<String, dynamic>.from(data);
    final fromId = d['fromId'] as String;
    final cand = d['candidate'];

    final pc = _participants[fromId]?.peerConnection;
    if (pc != null && cand != null) {
      final candMap = Map<String, dynamic>.from(cand);
      await pc.addCandidate(RTCIceCandidate(
        candMap['candidate'],
        candMap['sdpMid'],
        candMap['sdpMLineIndex'],
      ));
    }
  }

  void _onChatMessage(dynamic data) {
    final d = Map<String, dynamic>.from(data);
    onChatMessage?.call(d['sender'] ?? '', d['message'] ?? '', d['time'] ?? '');
  }

  void _onPeerMediaState(dynamic data) {
    final d = Map<String, dynamic>.from(data);
    final sid = d['socketId'] as String;
    if (_participants.containsKey(sid)) {
      _participants[sid]!.audioMuted = d['audioMuted'] ?? false;
      _participants[sid]!.videoOff = d['videoOff'] ?? false;
      onParticipantsChanged?.call(participants);
    }
  }

  // ─── Peer Connection Management ───────────────────────────────────────────
  Future<void> _createPeerConnection(String socketId, String name, bool isHostPeer, {required bool initiator}) async {
    if (_participants.containsKey(socketId)) return;

    final pc = await createPeerConnection(_rtcConfig);
    final renderer = RTCVideoRenderer();
    await renderer.initialize();

    final participant = RemoteParticipant(
      socketId: socketId,
      name: name,
      isHost: isHostPeer,
      peerConnection: pc,
      renderer: renderer,
    );
    _participants[socketId] = participant;

    // Add local tracks
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    // Handle incoming remote track
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        renderer.srcObject = event.streams[0];
        onParticipantsChanged?.call(participants);
      }
    };

    // ICE candidate
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _socket!.emit('ice-candidate', {
          'targetId': socketId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          'roomCode': roomCode,
        });
      }
    };

    pc.onConnectionState = (state) {
      debugPrint('[VideoService] Peer $socketId connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _removePeer(socketId);
        onParticipantsChanged?.call(participants);
      }
    };

    onParticipantsChanged?.call(participants);

    // Initiator sends the offer
    if (initiator) {
      final offer = await pc.createOffer({'offerToReceiveAudio': true, 'offerToReceiveVideo': true});
      await pc.setLocalDescription(offer);
      _socket!.emit('offer', {
        'targetId': socketId,
        'sdp': {'sdp': offer.sdp, 'type': offer.type},
        'roomCode': roomCode,
      });
    }
  }

  Future<void> _removePeer(String socketId) async {
    final p = _participants.remove(socketId);
    if (p != null) {
      await p.peerConnection?.close();
      await p.renderer?.dispose();
    }
  }

  // ─── Controls ─────────────────────────────────────────────────────────────
  void toggleAudio() {
    if (_localStream == null) return;
    _audioMuted = !_audioMuted;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !_audioMuted;
    }
    _socket?.emit('media-state', {
      'roomCode': roomCode,
      'audioMuted': _audioMuted,
      'videoOff': _videoOff,
    });
  }

  void toggleVideo() {
    if (_localStream == null) return;
    _videoOff = !_videoOff;
    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = !_videoOff;
    }
    _socket?.emit('media-state', {
      'roomCode': roomCode,
      'audioMuted': _audioMuted,
      'videoOff': _videoOff,
    });
  }

  void sendChatMessage(String message) {
    _socket?.emit('chat-message', {
      'roomCode': roomCode,
      'sender': displayName,
      'message': message,
    });
  }

  Future<void> _disposeLocalStream() async {
    if (_localStream != null) {
      try {
        for (final track in _localStream!.getTracks()) {
          await track.stop();
        }
      } catch (e) {
        debugPrint('Error stopping tracks: $e');
      }
      await _localStream!.dispose();
      _localStream = null;
    }
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _socket?.emit('leave', {'roomCode': roomCode, 'name': displayName});
    _socket?.disconnect();
    _socket?.dispose();

    for (final p in _participants.values) {
      await p.peerConnection?.close();
      await p.renderer?.dispose();
    }
    _participants.clear();

    await _disposeLocalStream();
  }
}
