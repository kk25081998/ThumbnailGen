@echo off
echo ========================================
echo    ThumbnailGen - Windows Launcher
echo ========================================
echo.

REM Check if Docker is installed
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker is not installed or not running.
    echo.
    echo Please install Docker Desktop from:
    echo https://www.docker.com/products/docker-desktop/
    echo.
    echo After installation, restart your computer and try again.
    pause
    exit /b 1
)

echo Docker found! Building ThumbnailGen...
echo.

REM Build the Docker image
echo Building Docker image...
docker build -t thumbnailgen .
if %errorlevel% neq 0 (
    echo ERROR: Failed to build Docker image.
    pause
    exit /b 1
)

echo.
echo Build successful! Starting ThumbnailGen...
echo.
echo The service will be available at: http://localhost:8080
echo Press Ctrl+C to stop the service
echo.

REM Run the service
docker run -p 8080:8080 thumbnailgen

pause 