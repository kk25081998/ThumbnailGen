#!/bin/bash

# ThumbnailGen - Local Build Script for Linux/macOS
# Make this file executable: chmod +x build_local.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
echo "========================================"
echo "    ThumbnailGen - Local Build"
echo "========================================"
echo -e "${NC}"
echo "This will build and run ThumbnailGen locally (without Docker)."
echo ""

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        echo -e "${CYAN}Detected Ubuntu/Debian system${NC}"
        echo ""
        echo "Installing dependencies..."
        echo ""
        
        # Update and install dependencies
        sudo apt-get update
        sudo apt-get install -y \
            build-essential \
            cmake \
            libboost-all-dev \
            libvips-dev \
            libjpeg-turbo8-dev \
            pkg-config \
            curl
        
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        echo -e "${CYAN}Detected CentOS/RHEL system${NC}"
        echo ""
        echo "Installing dependencies..."
        echo ""
        
        # Install dependencies
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y \
            cmake3 \
            boost-devel \
            vips-devel \
            pkgconfig \
            curl
        
        # Create symlink for cmake
        if [ ! -f /usr/bin/cmake ]; then
            sudo ln -s /usr/bin/cmake3 /usr/bin/cmake
        fi
        
    else
        echo -e "${RED}❌ Unsupported Linux distribution${NC}"
        echo "Please install dependencies manually:"
        echo "- build-essential (or Development Tools)"
        echo "- cmake"
        echo "- libboost-all-dev (or boost-devel)"
        echo "- libvips-dev (or vips-devel)"
        echo "- pkg-config"
        echo ""
        exit 1
    fi
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo -e "${CYAN}Detected macOS system${NC}"
    echo ""
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}❌ Homebrew is not installed!${NC}"
        echo ""
        echo "Please install Homebrew first:"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo ""
        echo "Then run this script again."
        echo ""
        exit 1
    fi
    
    echo "Installing dependencies with Homebrew..."
    echo ""
    
    # Install dependencies
    brew install \
        cmake \
        boost \
        vips \
        pkg-config
    
else
    echo -e "${RED}❌ Unsupported operating system${NC}"
    echo "Please use Docker instead: ./run_simple.sh"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Dependencies installed!${NC}"
echo ""

# Check if build directory exists, create if not
if [ ! -d "build" ]; then
    echo "Creating build directory..."
    mkdir build
fi

# Build the project
echo -e "${YELLOW}Building ThumbnailGen...${NC}"
cd build

if ! cmake ..; then
    echo -e "${RED}❌ CMake configuration failed!${NC}"
    echo "Please check the error messages above."
    exit 1
fi

if ! make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4); then
    echo -e "${RED}❌ Build failed!${NC}"
    echo "Please check the error messages above."
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"
echo ""

# Run the service
echo -e "${CYAN}🚀 Starting ThumbnailGen...${NC}"
echo ""
echo "The service will be available at: http://localhost:8080"
echo "Your browser should open automatically in a few seconds."
echo ""
echo "To stop the service, press Ctrl+C in this terminal."
echo ""

# Start the service and open browser
if command -v xdg-open &> /dev/null; then
    # Linux
    (sleep 3 && xdg-open http://localhost:8080) &
elif command -v open &> /dev/null; then
    # macOS
    (sleep 3 && open http://localhost:8080) &
fi

# Run the service
./thumbnail_service --port 8080 --threads 4

echo ""
echo "Service stopped." 