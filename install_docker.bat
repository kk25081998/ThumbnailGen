@echo off
title ThumbnailGen - Docker Installer
color 0E

echo.
echo ========================================
echo    ThumbnailGen - Docker Installer
echo ========================================
echo.
echo This will help you install Docker Desktop for Windows.
echo.

REM Check if Docker is already installed
echo Checking if Docker is already installed...
docker --version >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Docker is already installed!
    echo.
    echo To start ThumbnailGen, run: run_simple.bat
    echo.
    pause
    exit /b 0
)

echo Docker is not installed. Let's install it!
echo.

REM Check Windows version
echo Checking Windows version...
ver | findstr /i "10\.0\|11\.0" >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ ERROR: This installer requires Windows 10 or Windows 11.
    echo.
    echo Please upgrade to Windows 10/11 or install Docker manually.
    echo.
    pause
    exit /b 1
)

echo ✅ Windows version is compatible.
echo.

REM Check if WSL2 is available
echo Checking WSL2 availability...
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ⚠️  WSL2 is not installed. This is required for Docker Desktop.
    echo.
    echo Installing WSL2...
    echo This may take a few minutes...
    echo.
    
    REM Enable WSL feature
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    
    echo.
    echo WSL2 features enabled. Please restart your computer and run this installer again.
    echo.
    pause
    exit /b 0
)

echo ✅ WSL2 is available.
echo.

echo 🚀 Opening Docker Desktop download page...
echo.
echo Please:
echo 1. Download Docker Desktop for Windows
echo 2. Run the installer
echo 3. Follow the installation wizard
echo 4. Restart your computer when prompted
echo 5. Start Docker Desktop
echo 6. Run run_simple.bat to start ThumbnailGen
echo.

REM Open Docker download page
start https://www.docker.com/products/docker-desktop/

echo Download page opened in your browser.
echo.
echo After installation, run: run_simple.bat
echo.
pause 