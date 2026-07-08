@echo off
title Seva - Starting Signaling Server

echo ============================================
echo  Seva WebRTC Signaling Server
echo ============================================
echo.

REM Check if node_modules exists
if not exist "node_modules" (
    echo Installing Node.js dependencies...
    call npm install
    echo.
)

echo Starting signaling server on port 8001...
node signaling.js
pause
