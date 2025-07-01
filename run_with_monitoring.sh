#!/bin/bash

# ThumbnailGen - Full Monitoring Stack for Mac/Linux
# Make this file executable: chmod +x run_with_monitoring.sh

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
echo "    ThumbnailGen - Full Monitoring Stack"
echo "========================================"
echo -e "${NC}"
echo "This will start ThumbnailGen with Prometheus + Grafana monitoring."
echo ""
echo "Services that will be started:"
echo "- ThumbnailGen (port 8080)"
echo "- Prometheus (port 9090)"
echo "- Grafana (port 3000)"
echo ""

# Check if Docker is running
echo -e "${YELLOW}Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ ERROR: Docker is not installed!${NC}"
    echo ""
    echo "Please install Docker first using: ./install_docker.sh"
    echo ""
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}❌ ERROR: Docker is not running!${NC}"
    echo ""
    echo "Please start Docker and try again:"
    echo ""
    echo "macOS:"
    echo "  Start Docker Desktop application"
    echo ""
    echo "Linux:"
    echo "  sudo systemctl start docker"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Docker is running!${NC}"
echo ""

# Check if Docker Compose is available
echo -e "${YELLOW}Checking Docker Compose...${NC}"
if ! docker compose version &> /dev/null; then
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ ERROR: Docker Compose is not available!${NC}"
        echo ""
        echo "This script requires Docker Compose to run the full monitoring stack."
        echo "Please use ./run_simple.sh for the basic service only."
        echo ""
        exit 1
    fi
fi

echo -e "${GREEN}✅ Docker Compose found!${NC}"
echo ""

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ ERROR: docker-compose.yml not found!${NC}"
    echo ""
    echo "This script requires the docker-compose.yml file to run the monitoring stack."
    echo "Please ensure you're running this from the ThumbnailGen directory."
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Docker Compose file found!${NC}"
echo ""

# Check if monitoring directory exists
if [ ! -d "monitoring" ]; then
    echo -e "${RED}❌ ERROR: monitoring directory not found!${NC}"
    echo ""
    echo "This script requires the monitoring configuration files."
    echo "Please ensure you're running this from the ThumbnailGen directory."
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Monitoring configuration found!${NC}"
echo ""

echo -e "${CYAN}🚀 Starting ThumbnailGen with full monitoring stack...${NC}"
echo ""
echo "This may take a few minutes on first run as it downloads:"
echo "- Prometheus (metrics collection)"
echo "- Grafana (dashboard visualization)"
echo "- ThumbnailGen (your application)"
echo ""

# Start the full stack
if ! docker compose up -d; then
    echo ""
    echo -e "${RED}❌ ERROR: Failed to start the monitoring stack!${NC}"
    echo ""
    echo "Please check the error messages above and try again."
    echo "Common issues:"
    echo "- Port 8080, 9090, or 3000 already in use"
    echo "- Insufficient disk space"
    echo "- Docker not running properly"
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}✅ All services started successfully!${NC}"
echo ""

# Wait a moment for services to fully start
echo -e "${YELLOW}Waiting for services to initialize...${NC}"
sleep 5

echo ""
echo -e "${CYAN}========================================"
echo "    🎉 Monitoring Stack is Ready!"
echo "========================================"
echo -e "${NC}"
echo "📊 ThumbnailGen Web Interface: http://localhost:8080"
echo "📈 Prometheus Metrics:         http://localhost:9090"
echo "📊 Grafana Dashboard:          http://localhost:3000"
echo ""
echo "🔐 Grafana Login:"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "💡 Tips:"
echo "   - Upload images at http://localhost:8080 to see metrics"
echo "   - View performance in Grafana at http://localhost:3000"
echo "   - Check raw metrics in Prometheus at http://localhost:9090"
echo ""
echo "🛑 To stop all services, run: docker compose down"
echo ""

# Open the main interfaces
echo -e "${YELLOW}Opening web interfaces...${NC}"
if command -v xdg-open &> /dev/null; then
    # Linux
    (sleep 2 && xdg-open http://localhost:8080) &
    (sleep 4 && xdg-open http://localhost:3000) &
elif command -v open &> /dev/null; then
    # macOS
    (sleep 2 && open http://localhost:8080) &
    (sleep 4 && open http://localhost:3000) &
fi

echo ""
echo "Your browser should now open to the ThumbnailGen interface."
echo "The Grafana dashboard will show real-time performance metrics!"
echo ""
echo "Press Ctrl+C to stop the services (or let them run in background)"
echo ""

# Keep the script running to show logs
docker compose logs -f 