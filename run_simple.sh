#!/bin/bash

# ThumbnailGen - Simple Launcher for Linux/macOS
# Make this file executable: chmod +x run_simple.sh

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
echo "    ThumbnailGen - Simple Launcher"
echo "========================================"
echo -e "${NC}"
echo "This will start the thumbnail service in your browser."
echo ""
echo "Requirements:"
echo "- Docker must be installed and running"
echo "- Internet connection for first run"
echo ""

# Check if Docker is installed
echo -e "${YELLOW}Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ ERROR: Docker is not installed!${NC}"
    echo ""
    echo "Please install Docker first:"
    echo ""
    echo "Ubuntu/Debian:"
    echo "  sudo apt-get update && sudo apt-get install docker.io"
    echo "  sudo systemctl start docker"
    echo "  sudo usermod -aG docker \$USER"
    echo ""
    echo "macOS:"
    echo "  Download Docker Desktop from https://www.docker.com/products/docker-desktop/"
    echo ""
    echo "After installation, log out and log back in, then run this script again."
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ ERROR: Docker is not running!${NC}"
    echo ""
    echo "Please start Docker and try again:"
    echo ""
    echo "Ubuntu/Debian:"
    echo "  sudo systemctl start docker"
    echo ""
    echo "macOS:"
    echo "  Start Docker Desktop application"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Docker is running!${NC}"
echo ""

# Check if image exists, if not build it
echo -e "${YELLOW}Checking if ThumbnailGen is ready...${NC}"
if ! docker images thumbnailgen --format "table {{.Repository}}" | grep -q thumbnailgen; then
    echo -e "${YELLOW}Building ThumbnailGen (this may take a few minutes on first run)...${NC}"
    if ! docker build -t thumbnailgen .; then
        echo ""
        echo -e "${RED}❌ Failed to build ThumbnailGen${NC}"
        echo "Please check your internet connection and try again."
        echo ""
        exit 1
    fi
    echo -e "${GREEN}✅ Build complete!${NC}"
else
    echo -e "${GREEN}✅ ThumbnailGen is ready!${NC}"
fi

echo ""
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
docker run -p 8080:8080 thumbnailgen

echo ""
echo "Service stopped." 