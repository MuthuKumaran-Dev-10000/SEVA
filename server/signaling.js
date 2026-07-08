/**
 * Seva WebRTC Signaling Server
 * Multi-participant mesh WebRTC signaling via Socket.IO
 * Port: 8001
 *
 * Room architecture:
 *  - A "room" = one booking session identified by a roomCode
 *  - Host (priest/temple admin) starts the broadcast
 *  - Participants join using unique join codes pre-generated per attendee
 *  - All peers connect in a full-mesh: each peer sends offer to every existing peer
 */

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const httpServer = http.createServer(app);

const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// ─── Room State ──────────────────────────────────────────────────────────────
// rooms[roomCode] = {
//   participants: { socketId: { name, isHost, joinedAt } },
//   hostJoined: false,
//   hostName: null,
//   chat: [ { sender, message, time } ]
// }
const rooms = {};

// ─── Helpers ─────────────────────────────────────────────────────────────────
function getOrCreateRoom(roomCode) {
  if (!rooms[roomCode]) {
    rooms[roomCode] = {
      participants: {},
      hostJoined: false,
      hostName: null,
      chat: [],
    };
  }
  return rooms[roomCode];
}

function getRoomParticipantList(room) {
  return Object.entries(room.participants).map(([sid, p]) => ({
    socketId: sid,
    name: p.name,
    isHost: p.isHost,
  }));
}

// ─── Connection Handler ───────────────────────────────────────────────────────
io.on('connection', (socket) => {
  console.log(`[+] Socket connected: ${socket.id}`);

  /**
   * join-room
   * Payload: { roomCode, name, isHost, joinCode }
   */
  socket.on('join-room', ({ roomCode, name, isHost, joinCode }) => {
    console.log(`[JOIN] ${name} (${isHost ? 'HOST' : 'participant'}) → room: ${roomCode}`);

    const room = getOrCreateRoom(roomCode);

    // Track the socket → room mapping for disconnect cleanup
    socket._roomCode = roomCode;

    // Register participant
    room.participants[socket.id] = {
      name: name || 'Participant',
      isHost: !!isHost,
      joinedAt: Date.now(),
    };

    if (isHost) {
      room.hostJoined = true;
      room.hostName = name;
    }

    socket.join(roomCode);

    // 1. Send the new joiner the current room state (existing participants + chat)
    socket.emit('room-state', {
      participants: getRoomParticipantList(room),
      hostJoined: room.hostJoined,
      hostName: room.hostName,
      chat: room.chat,
    });

    // 2. Announce new peer to EVERYONE else in the room
    socket.to(roomCode).emit('peer-joined', {
      socketId: socket.id,
      name: room.participants[socket.id].name,
      isHost: room.participants[socket.id].isHost,
    });

    // 3. If host just joined, broadcast host-joined to all waiting participants
    if (isHost) {
      socket.to(roomCode).emit('host-joined', { name, socketId: socket.id });
    }
  });

  /**
   * WebRTC Signaling — Targeted (mesh)
   * Each offer/answer/ice-candidate is directed to a specific peer socket
   */
  socket.on('offer', ({ targetId, sdp, roomCode }) => {
    io.to(targetId).emit('offer', {
      fromId: socket.id,
      fromName: rooms[roomCode]?.participants[socket.id]?.name ?? 'Peer',
      sdp,
      roomCode,
    });
  });

  socket.on('answer', ({ targetId, sdp, roomCode }) => {
    io.to(targetId).emit('answer', {
      fromId: socket.id,
      sdp,
      roomCode,
    });
  });

  socket.on('ice-candidate', ({ targetId, candidate, roomCode }) => {
    io.to(targetId).emit('ice-candidate', {
      fromId: socket.id,
      candidate,
      roomCode,
    });
  });

  /**
   * Chat messages — broadcast to whole room
   */
  socket.on('chat-message', ({ roomCode, sender, message }) => {
    const entry = { sender, message, time: new Date().toISOString() };
    if (rooms[roomCode]) {
      rooms[roomCode].chat.push(entry);
      // Keep only last 200 messages
      if (rooms[roomCode].chat.length > 200) rooms[roomCode].chat.shift();
    }
    io.to(roomCode).emit('chat-message', entry);
  });

  /**
   * Toggle events — mic/camera state changes (forwarded to room)
   */
  socket.on('media-state', ({ roomCode, audioMuted, videoOff }) => {
    socket.to(roomCode).emit('peer-media-state', {
      socketId: socket.id,
      audioMuted,
      videoOff,
    });
  });

  /**
   * Disconnect handler
   */
  socket.on('disconnect', () => {
    const roomCode = socket._roomCode;
    if (!roomCode || !rooms[roomCode]) return;

    const room = rooms[roomCode];
    const leaving = room.participants[socket.id];

    if (!leaving) return;

    console.log(`[-] ${leaving.name} left room ${roomCode}`);
    delete room.participants[socket.id];

    // Notify remaining participants
    io.to(roomCode).emit('peer-left', {
      socketId: socket.id,
      name: leaving.name,
    });

    // If host left, update host state and notify
    if (leaving.isHost) {
      room.hostJoined = false;
      io.to(roomCode).emit('host-left', {
        name: leaving.name,
      });
    }

    // Clean up empty rooms
    if (Object.keys(room.participants).length === 0) {
      delete rooms[roomCode];
      console.log(`[ROOM] Room ${roomCode} closed (empty)`);
    }
  });
});

// ─── Health check ──────────────────────────────────────────────────────────── 
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    rooms: Object.keys(rooms).length,
    uptime: process.uptime(),
  });
});

app.get('/room/:code', (req, res) => {
  const room = rooms[req.params.code];
  if (!room) return res.json({ exists: false, participants: [] });
  res.json({
    exists: true,
    hostJoined: room.hostJoined,
    hostName: room.hostName,
    participants: getRoomParticipantList(room),
  });
});

// ─── Start Server ─────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 8001;
httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`\n✅ Seva Signaling Server running on 0.0.0.0:${PORT}`);
  console.log(`   Health check: http://localhost:${PORT}/health`);
  console.log(`   Room info:    http://localhost:${PORT}/room/:code\n`);
});
