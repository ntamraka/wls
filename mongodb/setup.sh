#!/usr/bin/env bash
set -e

echo "=============================================="
echo "   Universal Installer: MongoDB + Benchmark   "
echo "   Supports: Ubuntu, Debian, CentOS, RHEL,    "
echo "            Rocky, AlmaLinux                  "
echo "=============================================="

# -------- Detect OS ----------

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
else
    echo "❌ Unable to detect operating system."
    exit 1
fi

echo "➡️ Detected OS: $DISTRO ($VERSION)"


# -------- UTILITY FUNCTIONS  ---------

install_common_packages() {
    echo "🔹 Installing common build tools..."
    case "$DISTRO" in
        ubuntu|debian)
            sudo apt update -y
            sudo apt install -y wget curl git make gcc g++ pkg-config
            ;;
        centos|rhel|rocky|almalinux)
            sudo dnf install -y wget curl git make gcc gcc-c++ pkgconfig
            ;;
    esac
}

install_golang() {
    echo "🔹 Installing Golang..."
    case "$DISTRO" in
        ubuntu|debian)
            sudo apt install -y golang
            ;;
        centos|rhel|rocky|almalinux)
            sudo dnf install -y golang
            ;;
    esac

    echo "✔ Go version: $(go version)"
}

# -------- Install MongoDB (Different for Ubuntu vs RHEL family) ---------

install_mongodb_ubuntu() {
    echo "🔹 Installing MongoDB 7.0 for Ubuntu/Debian..."

    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
        sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu ${VERSION_CODENAME}/mongodb-org/7.0 multiverse" \
        | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

    sudo apt update -y
    sudo apt install -y mongodb-org
}

install_mongodb_rhel() {
    echo "🔹 Installing MongoDB 7.0 for RHEL/CentOS/Rocky/Alma..."

    sudo tee /etc/yum.repos.d/mongodb-org-7.0.repo > /dev/null <<EOF
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/${VERSION%%.*}/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF

    sudo dnf install -y mongodb-org
}

# -------- Install MongoDB Depending on OS ---------

if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    install_mongodb_ubuntu
else
    install_mongodb_rhel
fi

# -------- Enable MongoDB ---------

echo "🔹 Enabling and starting MongoDB..."
sudo systemctl enable mongod
sudo systemctl start mongod

echo "🔹 Checking MongoDB Status..."
sudo systemctl status mongod --no-pager

mongosh --version || { echo "❌ MongoDB installation failed"; exit 1; }
echo "✔ MongoDB Installed Successfully!"


# -------- Install Build Tools + Golang ---------

install_common_packages
install_golang


# -------- Clone & Build Benchmark Repository ---------

echo "🚀 Cloning MongoDB Benchmarking repo..."
git clone https://github.com/idealo/mongodb-benchmarking.git || true

cd mongodb-benchmarking

echo "🔹 Running make build..."
make build

echo "=============================================="
echo "       🎉 Installation Completed Successfully! "
echo "----------------------------------------------"
echo " MongoDB running on port 27017"
echo " Go version: $(go version)"
echo " Benchmark tool compiled: mongodb-benchmarking/"
echo ""
echo " To run benchmark:"
echo "     cd mongodb-benchmarking"
echo "     ./mongo-bench --help"
echo "=============================================="
