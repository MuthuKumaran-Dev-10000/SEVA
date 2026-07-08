@echo off
title Seva Signaling Server + ngrok

echo ============================================
echo  Seva - WebRTC Signaling Server Startup
echo ============================================
echo.

REM Check if ngrok is available
where ngrok >nul 2>nul
if errorlevel 1 (
    echo [!] ngrok not found. Please install it first:
    echo     1. Go to https://ngrok.com/download
    echo     2. Download for Windows, extract ngrok.exe
    echo     3. Place ngrok.exe in this folder (server/) or add to PATH
    echo     4. Run this script again.
    echo.
    echo     Alternatively, for same-WiFi usage only, skip ngrok and just
    echo     set the server URL in the app to: http://YOUR_PC_IP:8001
    echo.
    pause
    exit /b 1
)

REM Configure ngrok authtoken (only needs to be done once)
echo [1/4] Configuring ngrok authtoken...
ngrok config add-authtoken 2pF939obwt1d0r6IKZUzk6Ultbm_3DXJmtSHm1aZJxjK2FXHx

REM Check if node_modules exists, if not install dependencies
if not exist "node_modules" (
    echo [2/4] Installing Node.js dependencies...
    npm install
    echo.
)

echo [3/4] Starting Signaling Server on port 8001...
start "Seva Signaling" cmd /k "node signaling.js"

timeout /t 2 /nobreak > nul

echo [4/4] Starting ngrok tunnel...
echo.
echo =====================================================
echo  IMPORTANT: When ngrok opens, COPY the HTTPS URL
echo  (looks like: https://abc123.ngrok-free.app)
echo  Then paste it into the Seva app's Server Config
echo  dialog (the WiFi icon in the AppBar).
echo  Use the SAME URL for BOTH port 8000 and 8001.
echo =====================================================
echo.
ngrok start --config ngrok.yml seva-signaling

pause
