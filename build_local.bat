@echo off
title ThumbnailGen - Local Build
color 0B

echo.
echo ========================================
echo    ThumbnailGen - Local Build
echo ========================================
echo.
echo This will build and run ThumbnailGen locally (without Docker).
echo.
echo NOTE: This requires Visual Studio Build Tools or MinGW-w64.
echo For easier setup, use run_simple.bat instead.
echo.

REM Check if CMake is installed
echo Checking CMake...
cmake --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ❌ ERROR: CMake is not installed!
    echo.
    echo Please install CMake from: https://cmake.org/download/
    echo Or use the Docker version: run_simple.bat
    echo.
    pause
    exit /b 1
)

echo ✅ CMake found!
echo.

REM Check if a C++ compiler is available
echo Checking C++ compiler...
where cl >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Visual Studio compiler found!
    set COMPILER=msvc
) else (
    where g++ >nul 2>&1
    if %errorlevel% equ 0 (
        echo ✅ MinGW-w64 compiler found!
        set COMPILER=mingw
    ) else (
        echo.
        echo ❌ ERROR: No C++ compiler found!
        echo.
        echo Please install either:
        echo - Visual Studio Build Tools (recommended)
        echo - MinGW-w64
        echo.
        echo Or use the Docker version: run_simple.bat
        echo.
        pause
        exit /b 1
    )
)

echo.

REM Check if build directory exists, create if not
if not exist "build" (
    echo Creating build directory...
    mkdir build
)

REM Build the project
echo Building ThumbnailGen...
cd build

if "%COMPILER%"=="msvc" (
    REM Use Visual Studio generator
    cmake .. -G "Visual Studio 16 2019" -A x64
    if %errorlevel% neq 0 (
        echo.
        echo ❌ CMake configuration failed!
        echo Please check the error messages above.
        pause
        exit /b 1
    )
    
    cmake --build . --config Release
    if %errorlevel% neq 0 (
        echo.
        echo ❌ Build failed!
        echo Please check the error messages above.
        pause
        exit /b 1
    )
    
    set EXECUTABLE=Release\thumbnail_service.exe
) else (
    REM Use MinGW generator
    cmake .. -G "MinGW Makefiles"
    if %errorlevel% neq 0 (
        echo.
        echo ❌ CMake configuration failed!
        echo Please check the error messages above.
        pause
        exit /b 1
    )
    
    cmake --build .
    if %errorlevel% neq 0 (
        echo.
        echo ❌ Build failed!
        echo Please check the error messages above.
        pause
        exit /b 1
    )
    
    set EXECUTABLE=thumbnail_service.exe
)

echo.
echo ✅ Build successful!
echo.

REM Check if executable exists
if not exist "%EXECUTABLE%" (
    echo ❌ ERROR: Executable not found at %EXECUTABLE%
    echo Build may have failed. Please check the error messages above.
    pause
    exit /b 1
)

REM Run the service
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
"%EXECUTABLE%" --port 8080 --threads 4

echo.
echo Service stopped.
pause 