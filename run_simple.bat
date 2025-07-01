@echo off
title ThumbnailGen - Simple Launcher
color 0A

echo.
echo ========================================
echo    ThumbnailGen - Simple Launcher
echo ========================================
echo.
echo This will start the thumbnail service in your browser.
echo.
echo Requirements:
echo - Docker Desktop must be installed and running
echo - Internet connection for first run
echo.

REM Check if Docker is running
echo Checking Docker...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ❌ ERROR: Docker is not running!
    echo.
    echo Please:
    echo 1. Install Docker Desktop from https://www.docker.com/products/docker-desktop/
    echo 2. Start Docker Desktop
    echo 3. Wait for Docker to fully start (green icon in system tray)
    echo 4. Run this file again
    echo.
    pause
    exit /b 1
)

echo ✅ Docker is running!
echo.

REM Check if image exists, if not build it
echo Checking if ThumbnailGen is ready...
docker images thumbnailgen --format "table {{.Repository}}" | findstr thumbnailgen >nul 2>&1
if %errorlevel% neq 0 (
    echo Building ThumbnailGen (this may take a few minutes on first run)...
    docker build -t thumbnailgen .
    if %errorlevel% neq 0 (
        echo.
        echo ❌ Failed to build ThumbnailGen
        echo Please check your internet connection and try again.
        echo.
        pause
        exit /b 1
    )
    echo ✅ Build complete!
) else (
    echo ✅ ThumbnailGen is ready!
)

echo.
echo 🚀 Starting ThumbnailGen...
echo.
echo The service will be available at: http://localhost:8080
echo Your browser should open automatically in a few seconds.
echo.
echo To stop the service, press Ctrl+C in this window.
echo.

REM Start the service and open browser
start http://localhost:8080
timeout /t 3 /nobreak >nul
docker run -p 8080:8080 thumbnailgen

echo.
echo Service stopped.
pause 