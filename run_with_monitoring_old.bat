@echo off
title ThumbnailGen - Full Monitoring Stack
color 0D

echo.
echo ========================================
echo    ThumbnailGen - Full Monitoring Stack
echo ========================================
echo.
echo This will start ThumbnailGen with Prometheus + Grafana monitoring.
echo.
echo Services that will be started:
echo - ThumbnailGen (port 8080)
echo - Prometheus (port 9090)
echo - Grafana (port 3000)
echo.

REM Check if Docker is running
echo Checking Docker...
echo (Assuming Docker is running - please ensure Docker Desktop is started!)
echo.

REM Check if Docker Compose is available
echo Checking Docker Compose...
docker compose version >nul 2>&1
if %errorlevel% neq 0 (
    docker-compose --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo.
        echo ❌ ERROR: Docker Compose is not available!
        echo.
        echo This script requires Docker Compose to run the full monitoring stack.
        echo Please use run_simple.bat for the basic service only.
        echo.
        pause
        exit /b 1
    )
)

echo ✅ Docker Compose found!
echo.

REM Check if docker-compose.yml exists
if not exist "docker-compose.yml" (
    echo.
    echo ❌ ERROR: docker-compose.yml not found!
    echo.
    echo This script requires the docker-compose.yml file to run the monitoring stack.
    echo Please ensure you're running this from the ThumbnailGen directory.
    echo.
    pause
    exit /b 1
)

echo ✅ Docker Compose file found!
echo.

REM Check if monitoring directory exists
if not exist "monitoring" (
    echo.
    echo ❌ ERROR: monitoring directory not found!
    echo.
    echo This script requires the monitoring configuration files.
    echo Please ensure you're running this from the ThumbnailGen directory.
    echo.
    pause
    exit /b 1
)

echo ✅ Monitoring configuration found!
echo.

echo 🚀 Starting ThumbnailGen with full monitoring stack...
echo.
echo This may take a few minutes on first run as it downloads:
echo - Prometheus (metrics collection)
echo - Grafana (dashboard visualization)
echo - ThumbnailGen (your application)
echo.

REM Start the full stack
docker compose up -d

if %errorlevel% neq 0 (
    echo.
    echo ❌ ERROR: Failed to start the monitoring stack!
    echo.
    echo Please check the error messages above and try again.
    echo Common issues:
    echo - Port 8080, 9090, or 3000 already in use
    echo - Insufficient disk space
    echo - Docker not running properly
    echo.
    pause
    exit /b 1
)

echo.
echo ✅ All services started successfully!
echo.

REM Wait a moment for services to fully start
echo Waiting for services to initialize...
timeout /t 5 /nobreak >nul

echo.
echo ========================================
echo    🎉 Monitoring Stack is Ready!
echo ========================================
echo.
echo 📊 ThumbnailGen Web Interface: http://localhost:8080
echo 📈 Prometheus Metrics:         http://localhost:9090
echo 📊 Grafana Dashboard:          http://localhost:3000
echo.
echo 🔐 Grafana Login:
echo    Username: admin
echo    Password: admin
echo.
echo 💡 Tips:
echo    - Upload images at http://localhost:8080 to see metrics
echo    - View performance in Grafana at http://localhost:3000
echo    - Check raw metrics in Prometheus at http://localhost:9090
echo.
echo 🛑 To stop all services, run: docker compose down
echo.

REM Open the main interfaces
echo Opening web interfaces...
start http://localhost:8080
timeout /t 2 /nobreak >nul
start http://localhost:3000

echo.
echo Your browser should now open to the ThumbnailGen interface.
echo The Grafana dashboard will show real-time performance metrics!
echo.
echo Press any key to continue (services will keep running)...
pause >nul 