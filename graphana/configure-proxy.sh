#!/bin/bash

# Configure Docker Proxy Settings
# Use this if you're behind a corporate proxy/firewall

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "======================================"
echo "Docker Proxy Configuration"
echo "======================================"
echo ""

# Check if proxy is needed
read -p "Do you need to configure a proxy? (y/n): " need_proxy

if [ "$need_proxy" != "y" ]; then
    print_info "No proxy configuration needed"
    exit 0
fi

# Get proxy details
read -p "Enter HTTP proxy (e.g., http://proxy.example.com:8080): " http_proxy
read -p "Enter HTTPS proxy (leave blank if same as HTTP): " https_proxy
read -p "Enter NO_PROXY (e.g., localhost,127.0.0.1): " no_proxy

if [ -z "$https_proxy" ]; then
    https_proxy="$http_proxy"
fi

if [ -z "$no_proxy" ]; then
    no_proxy="localhost,127.0.0.1"
fi

# Create Docker systemd directory
print_info "Creating Docker systemd configuration..."
sudo mkdir -p /etc/systemd/system/docker.service.d

# Create proxy configuration
print_info "Writing proxy configuration..."
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null <<EOF
[Service]
Environment="HTTP_PROXY=$http_proxy"
Environment="HTTPS_PROXY=$https_proxy"
Environment="NO_PROXY=$no_proxy"
EOF

# Reload systemd and restart Docker
print_info "Reloading systemd daemon..."
sudo systemctl daemon-reload

print_info "Restarting Docker service..."
sudo systemctl restart docker

# Verify configuration
print_info "Verifying configuration..."
sudo systemctl show --property=Environment docker

echo ""
print_info "Proxy configuration complete!"
print_info "You can now run ./setup.sh to install Grafana and Prometheus"
