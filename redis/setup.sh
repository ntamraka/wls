#!/usr/bin/env bash

set -e

echo "=============================================="
echo "   Redis 6.2.7 + Memtier Benchmark Installer   "
echo "        Supports: Ubuntu / Debian / CentOS     "
echo "=============================================="

# --- Detect OS ----------------------------------------------------------

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "❌ Unable to detect OS."
    exit 1
fi

echo "➡️  Detected OS: $DISTRO"

# --- Install Dependencies ------------------------------------------------

install_dependencies_ubuntu() {
    echo "📦 Installing packages for Ubuntu/Debian..."

    apt update -y
    apt install -y build-essential autoconf automake gcc g++ \
        make libpcre3-dev zlib1g-dev libevent-dev libssl-dev \
        libmemcached-dev wget git
}

install_dependencies_centos() {
    echo "📦 Installing packages for CentOS/RHEL..."

    yum install -y epel-release
    yum groupinstall -y "Development Tools"
    yum install -y autoconf automake make gcc-c++ \
        pcre-devel zlib-devel libmemcached-devel libevent-devel openssl-devel \
        wget git
}

case "$DISTRO" in
    ubuntu|debian)
        install_dependencies_ubuntu
        ;;
    centos|rhel|rocky|almalinux)
        install_dependencies_centos
        ;;
    *)
        echo "❌ Unsupported OS: $DISTRO"
        exit 1
        ;;
esac


# --- Build Redis 6.2.7 ---------------------------------------------------

echo "📥 Downloading Redis 6.2.7..."
wget -q https://github.com/redis/redis/archive/6.2.7.tar.gz
tar -xf 6.2.7.tar.gz

echo "🔧 Building Redis..."
cd redis-6.2.7/src
make -j$(nproc)
cd ../..

echo "✔ Redis 6.2.7 build complete."


# --- Build memtier_benchmark --------------------------------------------

echo "📥 Cloning memtier_benchmark..."
git clone https://github.com/RedisLabs/memtier_benchmark.git

echo "🔧 Building memtier_benchmark..."
cd memtier_benchmark
autoreconf -ivf
./configure
make -j$(nproc)
make install
cd ..

echo "✔ memtier_benchmark installation complete."

echo "=============================================="
echo " Installation Completed Successfully! 🎉"
echo " Redis built in: redis-6.2.7/"
echo " memtier installed: /usr/local/bin/memtier_benchmark"
echo "=============================================="

