#!/usr/bin/env bash
set -e

echo "=============================================="
echo "     MongoDB + Golang + Benchmark Installer    "
echo "   Supports: CentOS 9 / RHEL 9 / Ubuntu 24.04  "
echo "=============================================="

# -------- Detect OS --------
source /etc/os-release
DISTRO=$ID
VERSION=$VERSION_ID
CODENAME=${VERSION_CODENAME:-noble}

echo "➡️ Detected: $DISTRO ($VERSION)"

# -----------------------------------------------------
#   SECTION 1 — INSTALL DEPENDENCIES
# -----------------------------------------------------

install_ubuntu_deps() {
    echo "🔹 Updating apt..."
    sudo apt update -y

    echo "🔹 Installing dependencies..."
    sudo apt install -y wget curl gnupg git make gcc g++ tar
}

install_centos_deps() {
    echo "🔹 Installing dependencies..."
    sudo dnf install -y wget curl git make gcc gcc-c++ tar
}

# -----------------------------------------------------
#   SECTION 2 — INSTALL MONGODB
# -----------------------------------------------------

install_mongodb_ubuntu() {
    echo "🔹 Installing MongoDB 7.0 for Ubuntu 24.04..."

    # MongoDB does NOT support Ubuntu 24.04 yet — use jammy repo
    CODENAME=jammy

    curl -fsSL https://pgp.mongodb.com/server-7.0.asc \
        | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu $CODENAME/mongodb-org/7.0 multiverse" \
        | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

    sudo apt update -y
    sudo apt install -y mongodb-org
}

install_mongodb_centos() {
    echo "🔹 Installing MongoDB 7.0 for CentOS 9..."

    sudo tee /etc/yum.repos.d/mongodb-org-7.0.repo >/dev/null <<EOF
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF

    sudo dnf install -y mongodb-org
}

# -----------------------------------------------------
#   SECTION 3 — ENABLE MONGODB SERVICE
# -----------------------------------------------------

enable_mongodb() {
    echo "🔹 Enabling + Starting MongoDB..."
    sudo systemctl enable mongod
    sudo systemctl start mongod
    sudo systemctl status mongod --no-pager || true

    mongosh --version || { echo "❌ MongoDB installation failed"; exit 1; }
    echo "✔ MongoDB installed!"
}

# -----------------------------------------------------
#   SECTION 4 — INSTALL GOLANG
# -----------------------------------------------------

install_golang_ubuntu() {
    sudo apt install -y golang
}

install_golang_centos() {
    sudo dnf install -y golang
}

# -----------------------------------------------------
#   SECTION 5 — CLONE & BUILD BENCHMARK TOOL
# -----------------------------------------------------

install_benchmark() {
    echo "🚀 Cloning benchmark repo..."
    git clone https://github.com/idealo/mongodb-benchmarking.git || true

    cd mongodb-benchmarking

    echo "🔹 Running make build..."
    make build

    cd ..
    echo "✔ Benchmark built successfully!"
}

# -----------------------------------------------------
#   MAIN LOGIC
# -----------------------------------------------------

case "$DISTRO" in
    ubuntu)
        if [[ "$VERSION" != "24.04" ]]; then
            echo "❌ This script only supports Ubuntu 24.04"
            exit 1
        fi
        install_ubuntu_deps
        install_mongodb_ubuntu
        enable_mongodb
        install_golang_ubuntu
        install_benchmark
        ;;
    centos|rhel|rocky|almalinux)
        install_centos_deps
        install_mongodb_centos
        enable_mongodb
        install_golang_centos
        install_benchmark
        ;;
    *)
        echo "❌ Unsupported OS: $DISTRO"
        echo "   Supported: Ubuntu 24.04, CentOS/RHEL/Rocky 9"
        exit 1
        ;;
esac

echo "=============================================="
echo "✔ Installation Completed Successfully!"
echo "----------------------------------------------"
echo " MongoDB running on port 27017"
echo " Benchmark: ./mongodb-benchmarking/mongo-bench"
echo " Golang: $(go version)"
echo "=============================================="
