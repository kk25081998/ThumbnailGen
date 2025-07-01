#!/bin/bash

# ThumbnailGen - Cleanup Tool for Linux/macOS
# Make this file executable: chmod +x cleanup.sh

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
echo "    ThumbnailGen - Cleanup Tool"
echo "========================================"
echo -e "${NC}"
echo "This will clean up Docker containers and images to free up disk space."
echo ""

# Check if Docker is running
echo -e "${YELLOW}Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ ERROR: Docker is not installed!${NC}"
    echo "Please install Docker first using: ./install_docker.sh"
    echo ""
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}❌ ERROR: Docker is not running!${NC}"
    echo "Please start Docker and try again."
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Docker is running!${NC}"
echo ""

echo -e "${YELLOW}⚠️  WARNING: This will remove:${NC}"
echo "   - All stopped ThumbnailGen containers"
echo "   - ThumbnailGen Docker images"
echo "   - Unused Docker images and containers"
echo ""

read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "${CYAN}🧹 Starting cleanup...${NC}"

# Stop and remove ThumbnailGen containers
echo "Stopping ThumbnailGen containers..."
docker ps -a --filter "ancestor=thumbnailgen" --format "{{.ID}}" | xargs -r docker stop
docker ps -a --filter "ancestor=thumbnailgen" --format "{{.ID}}" | xargs -r docker rm

# Remove ThumbnailGen images
echo "Removing ThumbnailGen images..."
docker rmi thumbnailgen 2>/dev/null || true

# Clean up unused Docker resources
echo "Cleaning up unused Docker resources..."
docker system prune -f

echo ""
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo ""
echo "To run ThumbnailGen again, use: ./run_simple.sh"
echo "" 