#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            OS_VERSION=$VERSION_ID
        else
            OS="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi
    echo -e "${GREEN}Detected OS: $OS${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Install Python3 and pip
install_python() {
    echo -e "${YELLOW}Checking Python installation...${NC}"
    
    if command_exists python3; then
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        echo -e "${GREEN}Python $PYTHON_VERSION is already installed${NC}"
    else
        echo -e "${YELLOW}Installing Python3...${NC}"
        case "$OS" in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y python3 python3-pip
                ;;
            fedora|rhel|centos)
                sudo dnf install -y python3 python3-pip || sudo yum install -y python3 python3-pip
                ;;
            arch)
                sudo pacman -S --noconfirm python python-pip
                ;;
            macos)
                if command_exists brew; then
                    brew install python3
                else
                    echo -e "${RED}Please install Homebrew first: https://brew.sh${NC}"
                    exit 1
                fi
                ;;
            *)
                echo -e "${RED}Unsupported OS. Please install Python3 manually.${NC}"
                exit 1
                ;;
        esac
    fi

    # Ensure pip is available
    if ! command_exists pip3; then
        echo -e "${YELLOW}Installing pip3...${NC}"
        python3 -m ensurepip --upgrade || python3 -m pip install --upgrade pip
    fi
}

# Install numactl
install_numactl() {
    echo -e "${YELLOW}Checking numactl installation...${NC}"
    
    if command_exists numactl; then
        echo -e "${GREEN}numactl is already installed${NC}"
    else
        echo -e "${YELLOW}Installing numactl...${NC}"
        case "$OS" in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y numactl
                ;;
            fedora|rhel|centos)
                sudo dnf install -y numactl || sudo yum install -y numactl
                ;;
            arch)
                sudo pacman -S --noconfirm numactl
                ;;
            macos)
                echo -e "${YELLOW}numactl is not available on macOS (NUMA not supported)${NC}"
                echo -e "${YELLOW}Skipping numactl installation...${NC}"
                ;;
            *)
                echo -e "${RED}Unsupported OS. Please install numactl manually.${NC}"
                exit 1
                ;;
        esac
    fi
}

# Install Python dependencies
install_python_deps() {
    echo -e "${YELLOW}Installing Python dependencies...${NC}"
    
    # Install packages globally with --break-system-packages flag
    # Skip pip upgrade to avoid debian package conflicts
    pip3 install fastapi "uvicorn[standard]" websockets --break-system-packages
    
    echo -e "${GREEN}Python dependencies installed successfully${NC}"
}

# Check/setup MLC binary
setup_mlc() {
    echo -e "${YELLOW}Checking MLC binary...${NC}"
    
    if [ -f "mlc_internal" ]; then
        echo -e "${GREEN}MLC binary found${NC}"
        chmod +x mlc_internal
    else
        echo -e "${RED}MLC binary (mlc_internal) not found${NC}"
        echo -e "${YELLOW}Please download Intel MLC from:${NC}"
        echo -e "${YELLOW}https://www.intel.com/content/www/us/en/download/736633/intel-memory-latency-checker-intel-mlc.html${NC}"
        echo -e "${YELLOW}Extract and place the 'mlc' binary as 'mlc_internal' in this directory${NC}"
    fi
}

# Make scripts executable
make_executable() {
    echo -e "${YELLOW}Making scripts executable...${NC}"
    chmod +x mlc.sh 2>/dev/null || true
    chmod +x setup.sh 2>/dev/null || true
    echo -e "${GREEN}Scripts are now executable${NC}"
}

# Create start script
create_start_script() {
    echo -e "${YELLOW}Creating start script...${NC}"
    
    cat > start.sh << 'EOF'
#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting MLC Dashboard Server...${NC}"
echo -e "${YELLOW}Dashboard will be available at:${NC}"
echo -e "${GREEN}  http://localhost:8000${NC}"
echo -e "${GREEN}  http://$(hostname -I | awk '{print $1}'):8000${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo ""

# Start server
uvicorn server:app --host 0.0.0.0 --port 8000 --reload
EOF
    
    chmod +x start.sh
    echo -e "${GREEN}Created start.sh script${NC}"
}

# Main setup function
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  MLC Dashboard Setup Script${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    detect_os
    echo ""
    
    install_python
    echo ""
    
    install_numactl
    echo ""
    
    install_python_deps
    echo ""
    
    setup_mlc
    echo ""
    
    make_executable
    echo ""
    
    create_start_script
    echo ""
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}To start the dashboard, run:${NC}"
    echo -e "${GREEN}  ./start.sh${NC}"
    echo ""
    echo -e "${YELLOW}Or manually:${NC}"
    echo -e "${GREEN}  uvicorn server:app --host 0.0.0.0 --port 8000 --reload${NC}"
    echo ""
    
    if [ ! -f "mlc_internal" ]; then
        echo -e "${RED}WARNING: MLC binary not found!${NC}"
        echo -e "${YELLOW}Download and place it in this directory before running.${NC}"
        echo ""
    fi
}

# Run main function
main
