@echo off
echo ========================================
echo  ThumbnailGen - Full Stack Launcher
echo  (Includes Prometheus + Grafana)
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

REM Check if Docker Compose is available
docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker Compose is not available.
    echo.
    echo This script requires Docker Compose to run the full monitoring stack.
    echo Please use run_windows.bat for the basic service only.
    pause
    exit /b 1
)

echo Docker and Docker Compose found!
echo.
echo Starting ThumbnailGen with full monitoring stack...
echo.

REM Start the full stack
docker-compose up -d

if %errorlevel% neq 0 (
    echo ERROR: Failed to start the monitoring stack.
    pause
    exit /b 1
)

echo.
echo ========================================
echo    Services Started Successfully!
echo ========================================
echo.
echo ThumbnailGen Web Interface: http://localhost:8080
echo Prometheus Metrics:         http://localhost:9090
echo Grafana Dashboard:          http://localhost:3000
echo.
echo Grafana Login:
echo   Username: admin
echo   Password: admin
echo.
echo To stop all services, run: docker-compose down
echo.
pause 