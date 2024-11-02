#!/bin/bash
set -e

# Determine system architecture
determine_architecture() {
  case "$(uname -m)" in
    'i386' | 'i686') echo '386' ;;
    'x86_64') echo 'amd64' ;;
    'armv5tel') echo 'armv5' ;;
    'armv6l') echo 'armv6' ;;
    'armv7' | 'armv7l') echo 'armv7' ;;
    'aarch64') echo 'arm64' ;;
    'mips64el') echo 'mips64le_softfloat' ;;
    'mips64') echo 'mips64_softfloat' ;;
    'mipsel') echo 'mipsle_softfloat' ;;
    'mips') echo 'mips_softfloat' ;;
    's390x') echo 's390x' ;;
    *) echo "error: The architecture is not supported."; exit 1 ;;
  esac
}

# Ensure root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Please run it as root."
    exit 1
fi

# Install necessary packages
apt update
apt install -y wireguard-dkms wireguard-tools resolvconf

# Check if wg-quick and resolvconf are installed
for cmd in wg-quick resolvconf; do
  if ! command -v $cmd &> /dev/null; then
    echo "Error: $cmd is required but not installed."
    exit 1
  fi
done

# Download and set up wgcf
arch=$(determine_architecture)
wget -O "/usr/bin/wgcf" "https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_${arch}" || { echo "Failed to download wgcf."; exit 1; }
chmod +x /usr/bin/wgcf

# Remove potential conflicting files
rm -f wgcf-account.toml /etc/wireguard/warp.conf

# Register and configure wgcf
wgcf register || { echo "Failed to register wgcf."; exit 1; }
read -rp "Do you want to use your own key? (Y/n): " response
if [[ $response =~ ^[Yy]$ ]]; then
    read -rp "ENTER YOUR LICENSE: " LICENSE_KEY
    sed -i "s/license_key = '.*'/license_key = '$LICENSE_KEY'/" wgcf-account.toml
    wgcf update || { echo "Failed to update wgcf with your license key."; exit 1; }
fi

wgcf generate || { echo "Failed to generate wgcf profile."; exit 1; }

# Configure WireGuard
sed -i '/\[Peer\]/i Table = off' wgcf-profile.conf
mv wgcf-profile.conf /etc/wireguard/warp.conf

# Enable WireGuard
systemctl enable --now wg-quick@warp || { echo "Failed to enable WireGuard warp."; exit 1; }

echo "Wireguard warp is up and running"
