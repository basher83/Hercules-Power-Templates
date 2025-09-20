#!/bin/bash
#
# Prepare a release archive for Hercules-Power-Templates
#
# This script creates a release archive that can be downloaded and installed
# on Proxmox hosts without requiring git.
#
# Usage:
#   ./scripts/prepare-release.sh [version]
#
# Example:
#   ./scripts/prepare-release.sh v1.0.0
#   ./scripts/prepare-release.sh  # Uses git describe

set -euo pipefail

# Configuration
RELEASE_DIR="release"
ARCHIVE_NAME="hercules-power-templates"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }

# Determine version
if [[ $# -eq 1 ]]; then
    VERSION="$1"
else
    # Try to get version from git
    if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
        VERSION=$(git describe --tags --always --dirty)
    else
        VERSION="dev"
    fi
fi

info "Preparing release ${VERSION}..."

# Clean up any existing release directory
if [[ -d "${RELEASE_DIR}" ]]; then
    warning "Removing existing release directory..."
    rm -rf "${RELEASE_DIR}"
fi

# Create release directory structure
info "Creating release directory structure..."
mkdir -p "${RELEASE_DIR}/${ARCHIVE_NAME}"
cd "${RELEASE_DIR}/${ARCHIVE_NAME}"

# Create directories
mkdir -p bin
mkdir -p systemd
mkdir -p snippets
mkdir -p docs

# Copy essential files
info "Copying essential files..."

# Scripts (from bin/, not scripts/)
cp ../../bin/image-update bin/
cp ../../bin/build-template bin/

# Systemd units
cp ../../systemd/image-update@.service systemd/
cp ../../systemd/image-update@.timer systemd/

# Cloud-init config
cp ../../snippets/vendor-data.yaml snippets/

# Documentation
cp ../../README.md .
cp ../../LICENSE .
cp ../../CHANGELOG.md .

# Quick start guide
cp ../../docs/quick-start.md docs/

# Create version file
echo "${VERSION}" > VERSION

# Create minimal install script for local use
cat > install-local.sh << 'EOF'
#!/bin/bash
# Local installation script (when archive is already extracted)
# For remote installation, use install-remote.sh instead

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo "Installing Hercules-Power-Templates from local archive..."

# Install scripts
cp bin/* /usr/local/bin/
chmod +x /usr/local/bin/image-update /usr/local/bin/build-template

# Install systemd units
cp systemd/* /etc/systemd/system/
systemctl daemon-reload

# Install cloud-init config
mkdir -p /var/lib/vz/snippets
if [[ -f /var/lib/vz/snippets/vendor-data.yaml ]]; then
    cp /var/lib/vz/snippets/vendor-data.yaml /var/lib/vz/snippets/vendor-data.yaml.backup.$(date +%Y%m%d-%H%M%S)
fi
cp snippets/vendor-data.yaml /var/lib/vz/snippets/

echo "Installation complete!"
echo "Run 'systemctl enable --now image-update@ubuntu-22.timer' to enable automatic updates"
EOF
chmod +x install-local.sh

# Go back to release directory
cd ..

# Create the archive
info "Creating release archive..."
tar -czf "${ARCHIVE_NAME}.tar.gz" "${ARCHIVE_NAME}"

# Create checksum
info "Generating checksum..."
sha256sum "${ARCHIVE_NAME}.tar.gz" > "${ARCHIVE_NAME}.tar.gz.sha256"

# Copy the remote installer to release directory
cp ../scripts/install-remote.sh install.sh

# Create SHA256 for installer too
sha256sum install.sh > install.sh.sha256

# Display results
success "Release ${VERSION} prepared successfully!"
echo
info "Release artifacts created in '${RELEASE_DIR}/':"
echo "  - ${ARCHIVE_NAME}.tar.gz       # Main release archive"
echo "  - ${ARCHIVE_NAME}.tar.gz.sha256 # Archive checksum"
echo "  - install.sh                    # Remote installer script"
echo "  - install.sh.sha256             # Installer checksum"
echo
info "To create a GitHub release:"
echo "  1. Create and push a git tag: git tag ${VERSION} && git push origin ${VERSION}"
echo "  2. Go to ${GITHUB_URL:-https://github.com/YOUR-ORG/Hercules-Power-Templates}/releases"
echo "  3. Create a new release from tag ${VERSION}"
echo "  4. Upload these files:"
echo "     - ${RELEASE_DIR}/${ARCHIVE_NAME}.tar.gz"
echo "     - ${RELEASE_DIR}/${ARCHIVE_NAME}.tar.gz.sha256"
echo "     - ${RELEASE_DIR}/install.sh"
echo "     - ${RELEASE_DIR}/install.sh.sha256"
echo
info "Users can then install with:"
echo "  curl -fsSL https://github.com/YOUR-ORG/Hercules-Power-Templates/releases/latest/download/install.sh | bash"
echo "  # or"
echo "  wget -qO- https://github.com/YOUR-ORG/Hercules-Power-Templates/releases/latest/download/install.sh | bash"
