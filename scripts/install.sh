#!/bin/bash
#
# Proxmox Template Scripts - Installation Script
# Automated installer for image-update and build-template tools
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
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

info "Starting Proxmox Template Scripts installation..."

# Create required directories
info "Creating required directories..."
mkdir -p /var/lib/vz/template/iso
mkdir -p /var/lib/vz/snippets
success "Directories created"

# Install scripts
info "Installing scripts..."
cp bin/image-update /usr/local/bin/
cp bin/build-template /usr/local/bin/
chmod +x /usr/local/bin/image-update /usr/local/bin/build-template
success "Scripts installed to /usr/local/bin/"

# Install systemd units
info "Installing systemd units..."
cp systemd/image-update@.service /etc/systemd/system/
cp systemd/image-update@.timer /etc/systemd/system/
systemctl daemon-reload
success "Systemd units installed"

# Install cloud-init configuration
info "Installing cloud-init configuration..."
if [[ -f /var/lib/vz/snippets/vendor-data.yaml ]]; then
    warning "vendor-data.yaml already exists, backing up..."
    cp /var/lib/vz/snippets/vendor-data.yaml /var/lib/vz/snippets/vendor-data.yaml.backup.$(date +%Y%m%d-%H%M%S)
fi
cp snippets/vendor-data.yaml /var/lib/vz/snippets/
success "Cloud-init configuration installed"

# Enable timers
info "Configuring image update timers..."
DISTROS=("ubuntu-20" "ubuntu-22" "ubuntu-24" "debian-12")

for distro in "${DISTROS[@]}"; do
    info "Enabling image-update@${distro}.timer..."
    systemctl enable image-update@${distro}.timer
    systemctl start image-update@${distro}.timer
    success "Timer enabled: image-update@${distro}.timer"
done

# Show timer status
info "Current timer status:"
systemctl list-timers | grep image-update || true

# Installation summary
echo
success "Installation completed successfully!"
echo
info "What was installed:"
echo "  • Scripts: /usr/local/bin/{image-update,build-template}"
echo "  • Systemd: /etc/systemd/system/image-update@.{service,timer}"
echo "  • Cloud-init: /var/lib/vz/snippets/vendor-data.yaml"
echo "  • Timers: 4 automatic image update timers enabled"
echo
info "Next steps:"
echo "  1. Check timer status: systemctl list-timers | grep image-update"
echo "  2. Manual image download: image-update ubuntu-22 --remove"
echo "  3. Create template: build-template -i 9022 -n ubuntu22 --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img"
echo "  4. View logs: journalctl -u image-update@ubuntu-22.service"
echo
info "For detailed usage instructions, see README.md"

# Optional: Test installation
read -p "Would you like to test the installation by downloading an image? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Testing image download (Ubuntu 22.04)..."
    if image-update ubuntu-22; then
        success "Test download completed successfully!"
    else
        warning "Test download failed. Check network connectivity and try manually."
    fi
fi

success "Installation script completed!"
