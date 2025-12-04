#!/bin/bash

### <<< CONFIG >>> ###
IFACE="ens6np0"
BASE_NETWORK="192.168.200."   # Everything before last octet
CIDR="/24"
GATEWAY=""     # Optional: e.g., 192.168.200.254 or leave blank
DNS="8.8.8.8 1.1.1.1"
##########################

# Ask user for last number (1–254)
read -p "Enter last octet of IP (1-254): " LASTOCTET

# Validate input
if ! [[ "$LASTOCTET" =~ ^[0-9]+$ ]] || [ "$LASTOCTET" -lt 1 ] || [ "$LASTOCTET" -gt 254 ]; then
    echo "Invalid number. Must be 1–254."
    exit 1
fi

IPADDR="${BASE_NETWORK}${LASTOCTET}${CIDR}"

############################################
### Ubuntu (Netplan) setup
############################################
set_ubuntu() {
    echo "[+] Ubuntu detected – configuring Netplan..."
    FILE="/etc/netplan/01-static-ip.yaml"

    sudo bash -c "cat > $FILE" <<EOF
network:
  version: 2
  ethernets:
    $IFACE:
      dhcp4: no
      addresses:
        - $IPADDR
EOF

    if [[ -n "$GATEWAY" ]]; then
        sudo bash -c "cat >> $FILE" <<EOF
      gateway4: $GATEWAY
      nameservers:
        addresses: [$DNS]
EOF
    fi

    sudo netplan apply
    echo "[+] Static IP $IPADDR applied on $IFACE via Netplan."
}

############################################
### CentOS 9 (NetworkManager) setup
############################################
set_centos9() {
    echo "[+] CentOS 9 detected – configuring NetworkManager..."

    sudo nmcli connection modify "$IFACE" ipv4.addresses "$IPADDR"
    sudo nmcli connection modify "$IFACE" ipv4.method manual

    if [[ -n "$GATEWAY" ]]; then
        sudo nmcli connection modify "$IFACE" ipv4.gateway "$GATEWAY"
        sudo nmcli connection modify "$IFACE" ipv4.dns "$DNS"
    fi

    sudo nmcli connection up "$IFACE"

    echo "[+] Static IP $IPADDR applied on $IFACE via NetworkManager."
}

############################################
### Auto detect OS
############################################

if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    set_ubuntu
elif grep -qi "centos" /etc/os-release && grep -qi "9" /etc/os-release; then
    set_centos9
else
    echo "Unsupported OS. This script works on Ubuntu and CentOS 9."
fi

