# 🪟 Windows Setup Guide for ThumbnailGen

This guide will help you get ThumbnailGen running on Windows with minimal effort.

## 🎯 **Recommended: Docker Approach (Easiest)**

### Step 1: Install Docker Desktop

1. **Download Docker Desktop**: Go to https://www.docker.com/products/docker-desktop/
2. **Install**: Run the installer and follow the prompts
3. **Restart**: Restart your computer when prompted
4. **Start Docker**: Launch Docker Desktop from the Start menu

### Step 2: Run ThumbnailGen

Once Docker is running, you have several options:

**Option A: Double-click the batch file**

```
Double-click: run_windows.bat
```

**Option B: Use PowerShell (Recommended)**

```powershell
# Right-click in the project folder → "Open PowerShell window here"
.\run_windows.ps1
```

**Option C: Manual commands**

```powershell
docker build -t thumbnailgen .
docker run -p 8080:8080 thumbnailgen
```

### Step 3: Access the Web Interface

Open your browser and go to: **http://localhost:8080**

## 🔧 **Alternative: Build from Source**

If you prefer to build from source, you'll need to install development tools:

### Option A: Visual Studio Build Tools

1. **Download Visual Studio Build Tools 2022**:

   - Go to: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022
   - Download "Build Tools for Visual Studio 2022"

2. **Install with C++ components**:

   - Run the installer
   - Select "C++ build tools" workload
   - Install

3. **Install vcpkg** (package manager):

   ```powershell
   git clone https://github.com/Microsoft/vcpkg.git
   cd vcpkg
   .\bootstrap-vcpkg.bat
   .\vcpkg integrate install
   ```

4. **Install dependencies**:

   ```powershell
   .\vcpkg install boost-beast boost-system boost-filesystem vips
   ```

5. **Build the project**:
   ```powershell
   mkdir build
   cd build
   cmake .. -DCMAKE_TOOLCHAIN_FILE=C:/vcpkg/scripts/buildsystems/vcpkg.cmake
   cmake --build . --config Release
   ```

### Option B: MSYS2/MinGW

1. **Download MSYS2**: https://www.msys2.org/
2. **Install MSYS2** and open MSYS2 terminal
3. **Install packages**:
   ```bash
   pacman -S mingw-w64-x86_64-cmake
   pacman -S mingw-w64-x86_64-gcc
   pacman -S mingw-w64-x86_64-boost
   pacman -S mingw-w64-x86_64-vips
   ```
4. **Build the project**:
   ```bash
   mkdir build
   cd build
   cmake .. -G "MinGW Makefiles"
   make
   ```

## 🚀 **Quick Start Commands**

### Basic Service Only

```powershell
# Method 1: Batch file
run_windows.bat

# Method 2: PowerShell
.\run_windows.ps1

# Method 3: Manual
docker build -t thumbnailgen .
docker run -p 8080:8080 thumbnailgen
```

### Full Monitoring Stack

```powershell
# Method 1: Batch file
run_with_monitoring.bat

# Method 2: Manual
docker-compose up -d
```

## 📊 **Accessing Services**

Once running, you can access:

- **ThumbnailGen Web UI**: http://localhost:8080
- **Prometheus Metrics**: http://localhost:9090 (if using monitoring stack)
- **Grafana Dashboard**: http://localhost:3000 (if using monitoring stack)
  - Username: `admin`
  - Password: `admin`

## 🔍 **Troubleshooting**

### Docker Issues

**"Docker is not recognized"**

- Make sure Docker Desktop is installed and running
- Restart your computer after installation
- Check that Docker Desktop is started from the system tray

**"Port 8080 is already in use"**

```powershell
# Use a different port
docker run -p 8081:8080 thumbnailgen
# Then access: http://localhost:8081
```

**"Build failed"**

- Ensure you have enough disk space (at least 2GB free)
- Check your internet connection (Docker needs to download base images)
- Try running as Administrator if you encounter permission issues

### Build Issues

**"CMake not found"**

- Install Visual Studio Build Tools or MSYS2
- Add CMake to your PATH

**"Compiler not found"**

- Install Visual Studio Build Tools with C++ components
- Or install MSYS2 with MinGW

**"Library not found"**

- Use vcpkg to install dependencies: `.\vcpkg install boost-beast vips`
- Or use MSYS2: `pacman -S mingw-w64-x86_64-boost mingw-w64-x86_64-vips`

## 🎯 **Performance Tips**

1. **Use Docker**: It's the easiest and most reliable method
2. **Allocate Resources**: Give Docker at least 4GB RAM and 2 CPU cores
3. **SSD Storage**: Use SSD for better Docker performance
4. **Windows Subsystem for Linux**: Consider WSL2 for better Docker performance

## 📞 **Getting Help**

If you encounter issues:

1. **Check the logs**: Look for error messages in the terminal
2. **Verify Docker**: Run `docker --version` to confirm installation
3. **Check ports**: Ensure port 8080 is not used by another application
4. **Restart services**: Stop and restart Docker Desktop if needed

## 🎉 **Success Indicators**

You'll know it's working when:

- ✅ Docker builds the image successfully
- ✅ Service starts without errors
- ✅ You can access http://localhost:8080 in your browser
- ✅ You see the drag-and-drop interface
- ✅ You can upload an image and get a thumbnail back

---

**Need help?** Check the main README.md for more detailed information or create an issue in the project repository.
