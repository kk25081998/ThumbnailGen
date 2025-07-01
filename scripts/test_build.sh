#!/bin/bash

# Test script for ThumbnailGen build verification

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "CMakeLists.txt" ]; then
    log_error "CMakeLists.txt not found. Please run this script from the project root."
    exit 1
fi

log_info "Starting ThumbnailGen build test..."

# Clean previous build
if [ -d "build" ]; then
    log_info "Cleaning previous build..."
    rm -rf build
fi

# Create build directory
log_info "Creating build directory..."
mkdir build
cd build

# Configure with CMake
log_info "Configuring with CMake..."
if cmake ..; then
    log_success "CMake configuration successful"
else
    log_error "CMake configuration failed"
    exit 1
fi

# Build the project
log_info "Building project..."
if make -j$(nproc); then
    log_success "Build successful"
else
    log_error "Build failed"
    exit 1
fi

# Check if executable was created
if [ -f "thumbnail_service" ]; then
    log_success "Executable created: thumbnail_service"
else
    log_error "Executable not found"
    exit 1
fi

# Test basic functionality
log_info "Testing basic functionality..."

# Start service in background
log_info "Starting service for testing..."
./thumbnail_service --port 8081 --threads 1 &
SERVICE_PID=$!

# Wait for service to start
sleep 3

# Test if service is responding
if curl -s -f "http://localhost:8081/metrics" > /dev/null; then
    log_success "Service is responding to metrics endpoint"
else
    log_error "Service is not responding"
    kill $SERVICE_PID 2>/dev/null || true
    exit 1
fi

# Test web interface
if curl -s -f "http://localhost:8081/" > /dev/null; then
    log_success "Web interface is accessible"
else
    log_error "Web interface is not accessible"
    kill $SERVICE_PID 2>/dev/null || true
    exit 1
fi

# Stop service
log_info "Stopping test service..."
kill $SERVICE_PID 2>/dev/null || true
wait $SERVICE_PID 2>/dev/null || true

# Go back to project root
cd ..

log_success "Build test completed successfully!"
log_info "You can now run the service with:"
log_info "  cd build && ./thumbnail_service --port 8080"
log_info "Or use Docker:"
log_info "  docker build -t thumbnailgen ."
log_info "  docker run -p 8080:8080 thumbnailgen" 