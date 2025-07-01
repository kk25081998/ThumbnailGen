#!/bin/bash

# ThumbnailGen - Docker Installer for Linux/macOS
# Make this file executable: chmod +x install_docker.sh

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
echo "    ThumbnailGen - Docker Installer"
echo "========================================"
echo -e "${NC}"
echo "This will help you install Docker for your system."
echo ""

# Check if Docker is already installed
echo -e "${YELLOW}Checking if Docker is already installed...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✅ Docker is already installed!${NC}"
    echo ""
    echo "To start ThumbnailGen, run: ./run_simple.sh"
    echo ""
    exit 0
fi

echo -e "${YELLOW}Docker is not installed. Let's install it!${NC}"
echo ""

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        echo -e "${CYAN}Detected Ubuntu/Debian system${NC}"
        echo ""
        echo "Installing Docker..."
        echo ""
        
        # Update package list
        sudo apt-get update
        
        # Install prerequisites
        sudo apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # Start Docker service
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        
        echo ""
        echo -e "${GREEN}✅ Docker installed successfully!${NC}"
        echo ""
        echo "⚠️  IMPORTANT: You need to log out and log back in for the docker group changes to take effect."
        echo ""
        echo "After logging back in, run: ./run_simple.sh"
        echo ""
        
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        echo -e "${CYAN}Detected CentOS/RHEL system${NC}"
        echo ""
        echo "Installing Docker..."
        echo ""
        
        # Install Docker
        sudo yum install -y docker
        
        # Start Docker service
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        
        echo ""
        echo -e "${GREEN}✅ Docker installed successfully!${NC}"
        echo ""
        echo "⚠️  IMPORTANT: You need to log out and log back in for the docker group changes to take effect."
        echo ""
        echo "After logging back in, run: ./run_simple.sh"
        echo ""
        
    else
        echo -e "${RED}❌ Unsupported Linux distribution${NC}"
        echo ""
        echo "Please install Docker manually:"
        echo "https://docs.docker.com/engine/install/"
        echo ""
        exit 1
    fi
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo -e "${CYAN}Detected macOS system${NC}"
    echo ""
    echo "For macOS, you need to install Docker Desktop manually."
    echo ""
    echo "Please:"
    echo "1. Visit https://www.docker.com/products/docker-desktop/"
    echo "2. Download Docker Desktop for Mac"
    echo "3. Install the downloaded .dmg file"
    echo "4. Start Docker Desktop"
    echo "5. Run: ./run_simple.sh"
    echo ""
    
    # Open Docker download page
    if command -v open &> /dev/null; then
        echo "Opening Docker download page..."
        open https://www.docker.com/products/docker-desktop/
    fi
    
else
    echo -e "${RED}❌ Unsupported operating system${NC}"
    echo ""
    echo "Please install Docker manually:"
    echo "https://docs.docker.com/engine/install/"
    echo ""
    exit 1
fi 