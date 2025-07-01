@echo off
title ThumbnailGen - Cleanup Tool
color 0C

echo.
echo ========================================
echo    ThumbnailGen - Cleanup Tool
echo ========================================
echo.
echo This will clean up Docker containers and images to free up disk space.
echo.

REM Check if Docker is running
echo Checking Docker...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ ERROR: Docker is not running!
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)

echo ✅ Docker is running!
echo.

echo ⚠️  WARNING: This will remove:
echo    - All stopped ThumbnailGen containers
echo    - ThumbnailGen Docker images
echo    - Unused Docker images and containers
echo.

set /p confirm="Are you sure you want to continue? (y/N): "
if /i not "%confirm%"=="y" (
    echo Cleanup cancelled.
    pause
    exit /b 0
)

echo.
echo 🧹 Starting cleanup...

REM Stop and remove ThumbnailGen containers
echo Stopping ThumbnailGen containers...
docker ps -a --filter "ancestor=thumbnailgen" --format "{{.ID}}" | for /f "tokens=*" %%i in ('more') do (
    docker stop %%i >nul 2>&1
    docker rm %%i >nul 2>&1
)

REM Remove ThumbnailGen images
echo Removing ThumbnailGen images...
docker rmi thumbnailgen >nul 2>&1

REM Clean up unused Docker resources
echo Cleaning up unused Docker resources...
docker system prune -f

echo.
echo ✅ Cleanup complete!
echo.
echo To run ThumbnailGen again, use: run_simple.bat
echo.
pause 