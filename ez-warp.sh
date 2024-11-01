#!/bin/bash
set -e

#necessary functions 
architecture() {
  case "$(uname -m)" in
    'i386' | 'i686') arch='386' ;;
    'x86_64') arch='amd64' ;;
    'armv5tel') arch='armv5' ;;
    'armv6l') arch='armv6' ;;
    'armv7' | 'armv7l') arch='armv7' ;;
    'aarch64') arch='arm64' ;;
    'mips64el') arch='mips64le_softfloat' ;;
    'mips64') arch='mips64_softfloat' ;;
    'mipsel') arch='mipsle_softfloat' ;;
    'mips') arch='mips_softfloat' ;;
    's390x') arch='s390x' ;;
    *) echo "error: The architecture is not supported."; exit 1 ;;
  esac
  echo "$arch"
}

#check user status
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Please run it as root."
    exit 1
fi

#installing necessary packages
apt update
ubuntu_version=$(lsb_release -r | awk '{print $2}')
if [[ "$ubuntu_version" == "24.04" ]]; then
  apt install -y wireguard
elif [[ "$ubuntu_version" == "22.04" || "$ubuntu_version" == "20.04" ]]; then
  apt install -y wireguard-dkms wireguard-tools resolvconf
fi

#checking packages
if ! command -v wg-quick &> /dev/null
then
    echo "something went wrong with wireguard package installation"
    exit 1
fi
if ! command -v resolvconf &> /dev/null
then
    echo "something went wrong with resolvconf package installation"
    exit 1
fi

clear
#downloading assets
arch=$(architecture)
wget -O "/usr/bin/wgcf" "https://github.com/ViRb3/wgcf/releases/download/v2.2.22/wgcf_2.2.22_linux_${arch}" || { echo "Failed to download wgcf. Please check the URL or your internet connection."; exit 1; }
chmod +x /usr/bin/wgcf

clear
# removing files that might cause problems
rm -rf wgcf-account.toml &> /dev/null || true
rm -rf /etc/wireguard/warp.conf &> /dev/null || true

# main dish
wgcf register || { echo "Failed to register wgcf."; exit 1; }
read -rp "Do you want to use your own key? (Y/n): " response
if [[ $response =~ ^[Yy]$ ]]; then
    read -rp "ENTER YOUR LICENSE: " LICENSE_KEY
    sed -i "s/license_key = '.*'/license_key = '$LICENSE_KEY'/" wgcf-account.toml
    wgcf update || { echo "Failed to update wgcf with your license key."; exit 1; }
fi

wgcf generate || { echo "Failed to generate wgcf profile."; exit 1; }

sed -i '/\[Peer\]/i Table = off' wgcf-profile.conf
mv wgcf-profile.conf /etc/wireguard/warp.conf

systemctl disable --now wg-quick@warp &> /dev/null || true
systemctl enable --now wg-quick@warp || { echo "Failed to enable WireGuard warp."; exit 1; }

echo "Wireguard warp is up and running"
