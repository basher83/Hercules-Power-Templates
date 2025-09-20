#!/bin/bash
#
# Hercules-Power-Templates Remote Installer
#
# This script downloads and installs the Proxmox template automation tools
# directly from a release archive without requiring git on the Proxmox host.
#
# Usage:
#   curl -fsSL https://github.com/basher83/Hercules-Power-Templates/releases/latest/download/install.sh | bash
#   wget -qO- https://github.com/basher83/Hercules-Power-Templates/releases/latest/download/install.sh | bash
#
# Or download and review first:
#   wget https://github.com/basher83/Hercules-Power-Templates/releases/latest/download/install.sh
#   less install.sh
#   bash install.sh

set -euo pipefail

# Configuration
REPO_OWNER="${REPO_OWNER:-basher83}"
REPO_NAME="${REPO_NAME:-Hercules-Power-Templates}"
INSTALL_VERSION="${INSTALL_VERSION:-latest}"
GITHUB_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
TEMP_DIR=$(mktemp -d -t hercules-install-XXXXXX)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}[ERROR]${NC} Installation failed. Please check the errors above."
    fi
}
trap cleanup EXIT

# Functions
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Banner
echo "========================================="
echo "Hercules-Power-Templates Remote Installer"
echo "========================================="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This installer must be run as root (use sudo)"
fi

# Check if running on Proxmox VE
if ! command -v pveversion &> /dev/null; then
    warning "Proxmox VE not detected. This package is designed for Proxmox VE hosts."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Check for required tools
for tool in curl tar; do
    if ! command -v $tool &> /dev/null; then
        error "$tool is required but not installed. Please install it first."
    fi
done

info "Downloading Hercules-Power-Templates..."

# Determine download URL
if [[ "${INSTALL_VERSION}" == "latest" ]]; then
    DOWNLOAD_URL="${GITHUB_URL}/releases/latest/download/hercules-power-templates.tar.gz"
else
    DOWNLOAD_URL="${GITHUB_URL}/releases/download/${INSTALL_VERSION}/hercules-power-templates.tar.gz"
fi

# Download the release archive
cd "${TEMP_DIR}"
if ! curl -fsSL "${DOWNLOAD_URL}" -o hercules-power-templates.tar.gz; then
    error "Failed to download release archive from ${DOWNLOAD_URL}"
fi

info "Extracting archive..."
tar -xzf hercules-power-templates.tar.gz

# Check if extraction was successful
if [[ ! -d "hercules-power-templates" ]]; then
    error "Archive extraction failed. Invalid archive structure."
fi

cd hercules-power-templates

info "Installing Hercules-Power-Templates..."

# Create required directories
info "Creating required directories..."
mkdir -p /var/lib/vz/template/iso
mkdir -p /var/lib/vz/snippets
mkdir -p /usr/local/bin
mkdir -p /etc/systemd/system
success "Directories created"

# Install scripts
info "Installing scripts..."
if [[ -f bin/image-update ]] && [[ -f bin/build-template ]]; then
    cp bin/image-update /usr/local/bin/
    cp bin/build-template /usr/local/bin/
    chmod +x /usr/local/bin/image-update /usr/local/bin/build-template
    success "Scripts installed to /usr/local/bin/"
else
    error "Required scripts not found in archive"
fi

# Install systemd units
info "Installing systemd units..."
if [[ -f systemd/image-update@.service ]] && [[ -f systemd/image-update@.timer ]]; then
    cp systemd/image-update@.service /etc/systemd/system/
    cp systemd/image-update@.timer /etc/systemd/system/
    systemctl daemon-reload
    success "Systemd units installed"
else
    error "Systemd unit files not found in archive"
fi

# Install cloud-init configuration
info "Installing cloud-init configuration..."
if [[ -f snippets/vendor-data.yaml ]]; then
    if [[ -f /var/lib/vz/snippets/vendor-data.yaml ]]; then
        warning "vendor-data.yaml already exists, backing up..."
        cp /var/lib/vz/snippets/vendor-data.yaml /var/lib/vz/snippets/vendor-data.yaml.backup.$(date +%Y%m%d-%H%M%S)
    fi
    cp snippets/vendor-data.yaml /var/lib/vz/snippets/
    success "Cloud-init configuration installed"
else
    warning "vendor-data.yaml not found in archive, skipping..."
fi

# Configure timers (optional)
info "Configuring image update timers..."
echo
echo "Would you like to enable automatic monthly image updates?"
echo "Available distributions:"
echo "  1) Ubuntu 20.04 LTS (ubuntu-20)"
echo "  2) Ubuntu 22.04 LTS (ubuntu-22)"
echo "  3) Ubuntu 24.04 LTS (ubuntu-24)"
echo "  4) Debian 12 (debian-12)"
echo "  5) All of the above"
echo "  6) None (configure manually later)"
echo

read -p "Select option [1-6]: " -n 1 -r
echo

enable_timer() {
    local distro=$1
    info "Enabling timer for ${distro}..."
    systemctl enable image-update@${distro}.timer
    systemctl start image-update@${distro}.timer
    success "Timer enabled for ${distro}"
}

case $REPLY in
    1) enable_timer "ubuntu-20" ;;
    2) enable_timer "ubuntu-22" ;;
    3) enable_timer "ubuntu-24" ;;
    4) enable_timer "debian-12" ;;
    5)
        enable_timer "ubuntu-20"
        enable_timer "ubuntu-22"
        enable_timer "ubuntu-24"
        enable_timer "debian-12"
        ;;
    6) info "Skipping timer configuration. You can enable them later with:"
       echo "  systemctl enable --now image-update@<distro>.timer"
       ;;
    *) warning "Invalid option. Skipping timer configuration." ;;
esac

echo
success "Installation completed successfully!"
echo
info "Installed components:"
echo "  - Scripts: /usr/local/bin/image-update, /usr/local/bin/build-template"
echo "  - Services: /etc/systemd/system/image-update@.service"
echo "  - Timers: /etc/systemd/system/image-update@.timer"
echo "  - Config: /var/lib/vz/snippets/vendor-data.yaml"
echo
info "Quick start commands:"
echo "  image-update ubuntu-22          # Download Ubuntu 22.04 image"
echo "  build-template -h                # Show template builder help"
echo "  systemctl list-timers | grep image-update  # Check timer status"
echo
info "For detailed documentation, visit:"
echo "  ${GITHUB_URL}"
echo
