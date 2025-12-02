#!/bin/bash

# Grafana and Prometheus Setup Script for Workload Benchmark Suite
# Supports CentOS 9 / RHEL 9 / Rocky / AlmaLinux / Ubuntu 24.04

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS"
        exit 1
    fi
    print_info "Detected OS: $OS $VERSION"
}

# Install Docker
install_docker() {
    print_info "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        print_info "Docker is already installed"
        docker --version
        return 0
    fi

    case "$OS" in
        ubuntu)
            sudo apt-get update
            sudo apt-get install -y ca-certificates curl gnupg
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
              sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        centos|rhel|rocky|almalinux)
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac

    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    print_info "Docker installed successfully"
}

# Install Docker Compose (standalone)
install_docker_compose() {
    print_info "Checking Docker Compose..."
    
    if docker compose version &> /dev/null; then
        print_info "Docker Compose (plugin) is already installed"
        docker compose version
        return 0
    fi

    if command -v docker-compose &> /dev/null; then
        print_info "Docker Compose (standalone) is already installed"
        docker-compose --version
        return 0
    fi

    print_info "Installing Docker Compose standalone..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_info "Docker Compose installed successfully"
}

# Create necessary directories
create_directories() {
    print_info "Creating necessary directories..."
    mkdir -p prometheus_data
    mkdir -p grafana_data
    mkdir -p grafana/provisioning/datasources
    mkdir -p grafana/provisioning/dashboards
    mkdir -p grafana/dashboards
    
    # Set correct permissions for Grafana (runs as UID 472)
    sudo chown -R 472:472 grafana_data 2>/dev/null || chown -R $(id -u):$(id -g) grafana_data
    
    # Set correct permissions for Prometheus (runs as UID 65534 - nobody)
    sudo chown -R 65534:65534 prometheus_data 2>/dev/null || chown -R $(id -u):$(id -g) prometheus_data
    
    print_info "Directories created"
}

# Create Grafana datasource configuration
create_grafana_datasource() {
    print_info "Creating Grafana datasource configuration..."
    cat > grafana/provisioning/datasources/prometheus.yml <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF
    print_info "Datasource configuration created"
}

# Create Grafana dashboard provisioning
create_grafana_dashboard_config() {
    print_info "Creating Grafana dashboard configuration..."
    cat > grafana/provisioning/dashboards/dashboard.yml <<EOF
apiVersion: 1

providers:
  - name: 'Workload Benchmarks'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: true
EOF
    print_info "Dashboard configuration created"
}

# Pull images with retry logic
pull_images() {
    print_info "Pulling Docker images (this may take a few minutes)..."
    
    local images=(
        "prom/prometheus:latest"
        "grafana/grafana:latest"
        "prom/node-exporter:latest"
        "oliver006/redis_exporter:latest"
        "percona/mongodb_exporter:0.40"
    )
    
    for image in "${images[@]}"; do
        print_info "Pulling $image..."
        local retries=3
        local count=0
        while [ $count -lt $retries ]; do
            if docker pull "$image" 2>&1; then
                print_info "Successfully pulled $image"
                break
            else
                count=$((count + 1))
                if [ $count -lt $retries ]; then
                    print_warning "Failed to pull $image, retrying ($count/$retries)..."
                    sleep 5
                else
                    print_error "Failed to pull $image after $retries attempts"
                    print_warning "You may need to configure Docker proxy settings or check network connectivity"
                fi
            fi
        done
    done
}

# Start services
start_services() {
    print_info "Starting Grafana and Prometheus services..."
    
    if docker compose version &> /dev/null; then
        docker compose up -d --no-build
    else
        docker-compose up -d --no-build
    fi
    
    print_info "Waiting for services to start..."
    sleep 15
    
    print_info "Checking service status..."
    if docker compose version &> /dev/null; then
        docker compose ps
    else
        docker-compose ps
    fi
}

# Print access information
print_access_info() {
    echo ""
    echo "=========================================="
    print_info "Setup Complete!"
    echo "=========================================="
    echo ""
    print_info "Grafana:"
    echo "  URL: http://localhost:3000"
    echo "  Username: admin"
    echo "  Password: admin"
    echo ""
    print_info "Prometheus:"
    echo "  URL: http://localhost:9090"
    echo ""
    print_info "Exporters:"
    echo "  Node Exporter: http://localhost:9100/metrics"
    echo "  Redis Exporter: http://localhost:9121/metrics"
    echo "  MongoDB Exporter: http://localhost:9216/metrics"
    echo ""
    print_warning "Note: Make sure your Redis, MongoDB, and Cassandra services are running"
    print_warning "You may need to log out and back in for Docker group permissions to take effect"
    echo ""
}

# Main execution
main() {
    print_info "Starting Grafana and Prometheus setup..."
    
    detect_os
    install_docker
    install_docker_compose
    create_directories
    create_grafana_datasource
    create_grafana_dashboard_config
    pull_images
    start_services
    print_access_info
    
    print_info "Setup script completed successfully!"
}

main "$@"
