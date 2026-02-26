#!/bin/bash

set -e

KVER="6.14.0-061400"
BUILD="202503241442"
BASE="https://kernel.ubuntu.com/mainline/v6.14/amd64"

echo "======================================"
echo " Installing Mainline Kernel $KVER"
echo "======================================"

echo ""
echo "Step 1: Cleaning Broadcom DKMS if present..."

if dkms status | grep -q "bnxt_en"; then
    sudo dkms remove bnxt_en --all || true
fi

if dkms status | grep -q "bnxt_re"; then
    sudo dkms remove bnxt_re --all || true
fi

sudo rm -rf /var/lib/dkms/bnxt_en 2>/dev/null || true
sudo rm -rf /var/lib/dkms/bnxt_re 2>/dev/null || true

echo "✔ DKMS cleanup done."
echo ""

echo "Step 2: Downloading required packages..."

mkdir -p ~/kernel614
cd ~/kernel614

wget -c $BASE/linux-headers-$KVER\_$KVER.$BUILD\_all.deb
wget -c $BASE/linux-headers-$KVER-generic\_$KVER.$BUILD\_amd64.deb
wget -c $BASE/linux-image-unsigned-$KVER-generic\_$KVER.$BUILD\_amd64.deb
wget -c $BASE/linux-modules-$KVER-generic\_$KVER.$BUILD\_amd64.deb

echo "✔ Download complete."
echo ""

echo "Step 3: Installing kernel..."

sudo dpkg -i *.deb || true

echo ""
echo "Fixing broken packages..."
sudo apt -f install -y
sudo dpkg --configure -a
sudo update-grub

echo ""
echo "Step 4: Verifying installation..."

if dpkg -l | grep -q "linux-image-unsigned-$KVER-generic"; then
    echo "✔ Kernel package installed correctly."
else
    echo "✖ Kernel package missing!"
    exit 1
fi

if [ -f /boot/vmlinuz-$KVER-generic ]; then
    echo "✔ Kernel image present in /boot."
else
    echo "✖ Kernel image not found in /boot!"
    exit 1
fi

echo ""
echo "Installed kernels:"
dpkg -l | grep linux-image | grep ^ii

echo ""
echo "======================================"
echo " Installation Completed Successfully"
echo "======================================"
echo ""
echo "You can reboot now."
echo "After reboot verify with:"
echo "  uname -r"
echo ""
