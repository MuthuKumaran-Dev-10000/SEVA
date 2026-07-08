@echo off
title Seva - ngrok Tunnel

echo ============================================
echo  Seva ngrok Tunnel (port 8001)
echo ============================================
echo.
echo When the URL appears below, COPY the https:// URL
echo and paste it into the Seva app (WiFi icon in AppBar).
echo.
echo Example: https://abc123.ngrok-free.app
echo.
echo ============================================
echo.

ngrok http 8001
pause
