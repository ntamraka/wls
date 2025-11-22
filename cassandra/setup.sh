#!/usr/bin/env bash

set -e

echo "=============================================="
echo "   Apache Cassandra 4.1.0 Setup Script"
echo "   Java 11 + JAVA_HOME Auto-Config"
echo "   Supports: Ubuntu / Debian / CentOS / RHEL"
echo "=============================================="

# ---- Detect OS ----------------------------------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "❌ Unable to detect OS"
    exit 1
fi

echo "➡️  Detected OS: $DISTRO"

# ---- Install OpenJDK 11 -------------------------------------------------

install_java_ubuntu() {
    echo "📦 Installing Java 11 (Ubuntu/Debian)..."
    apt update -y
    apt install -y openjdk-11-jdk wget tar
}

install_java_centos() {
    echo "📦 Installing Java 11 (CentOS/RHEL/Rocky/Alma)..."
    yum install -y java-11-openjdk java-11-openjdk-devel wget tar
}

case "$DISTRO" in
    ubuntu|debian)
        install_java_ubuntu
        ;;
    centos|rhel|rocky|almalinux)
        install_java_centos
        ;;
    *)
        echo "❌ Unsupported OS: $DISTRO"
        exit 1
        ;;
esac

# ---- Detect JAVA_HOME ---------------------------------------------------

echo "🔍 Detecting JAVA_HOME..."
JAVA_PATH=$(dirname "$(dirname "$(readlink -f "$(which javac)")")")

if [ -z "$JAVA_PATH" ]; then
    echo "❌ Failed to detect JAVA_HOME"
    exit 1
fi

echo "✅ JAVA_HOME detected: $JAVA_PATH"

# ---- Add JAVA_HOME to ~/.bashrc -----------------------------------------

if ! grep -q "JAVA_HOME" ~/.bashrc; then
    echo "🔧 Adding JAVA_HOME to ~/.bashrc..."
    echo "" >> ~/.bashrc
    echo "export JAVA_HOME=$JAVA_PATH" >> ~/.bashrc
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> ~/.bashrc
fi

# Reload environment
source ~/.bashrc

echo "✔ JAVA_HOME configured."
echo "JAVA_HOME=$JAVA_HOME"


# ---- Download and Extract Cassandra 4.1.0 ----------------------------------

echo "📥 Downloading Apache Cassandra 4.1.0..."
wget -q https://archive.apache.org/dist/cassandra/4.1.0/apache-cassandra-4.1.0-bin.tar.gz

echo "📦 Extracting Cassandra..."
tar -xzf apache-cassandra-4.1.0-bin.tar.gz

echo "✔ Cassandra extracted to ./apache-cassandra-4.1.0"

echo "=============================================="
echo " Installation Completed Successfully 🎉"
echo ""
echo " Cassandra Directory: ./apache-cassandra-4.1.0"
echo " JAVA_HOME: $JAVA_HOME"
echo " To start Cassandra:"
echo "     cd apache-cassandra-4.1.0"
echo "     ./bin/cassandra -R"
echo "=============================================="

