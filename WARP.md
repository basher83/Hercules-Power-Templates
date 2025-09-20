# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this
repository.

## Overview

Hercules-Power-Templates is a Proxmox VE template automation system that
provides two main components:

- **`image-update`**: Automatically downloads latest cloud images on a monthly
  schedule via systemd timers
- **`build-template`**: Creates Proxmox templates from downloaded cloud images
  with configurable networking and hardware specs

This is an enhanced fork of
[proxmox-template-scripts](https://github.com/trfore/proxmox-template-scripts)
with production-ready improvements including comprehensive logging, retry logic,
and dual-network support.

## Development Tools & Linting

The project uses mise for tool management. Key tools available:

- **shellcheck** (0.11.0): Bash script linting
- **prettier** (3.6.2): Code formatting
- **pre-commit** (4.3.0): Git hooks (though config not yet present)

### Linting Commands

```bash
# Run all linting tasks via mise
mise run lint

# Run individual linting tasks
mise run lint:shellcheck  # Shell script linting
mise run lint:prettier    # Code formatting check
mise run lint:pre-commit  # All pre-commit hooks

# Manual linting (without mise)
shellcheck scripts/*.sh
prettier --check .
pre-commit run --all-files
```

## Core Architecture

### Script Architecture

- **`bin/image-update`**: Enhanced cloud image downloader with production
  features:
  - Lock file management to prevent concurrent runs
  - Comprehensive logging with rotation
  - Network retry logic with exponential backoff
  - Dry-run mode for testing
  - Status file generation for monitoring
- **`bin/build-template`**: Proxmox template creator supporting:
  - Dual network interfaces with VLAN support
  - Static IP and DHCP configuration
  - Custom CPU, memory, and storage settings
  - UEFI/BIOS selection
  - Cloud-init integration

### Systemd Integration

- **Templates**: `image-update@.service` and `image-update@.timer` for automated
  updates
- **Scheduling**: Monthly execution on 1st at 01:00 with 3-hour randomization
- **Service naming**: Pattern `image-update@distro-version.timer` (e.g.,
  `ubuntu-22`, `debian-12`)

### Supported Distributions

- **Ubuntu**: 20.04, 22.04, 24.04 LTS
- **Debian**: 12 (Bookworm)
- **CentOS**: Stream 9
- **Fedora**: 40, 41

## Common Development Commands

### Testing Scripts Locally

```bash
# Test image download (dry-run mode)
./bin/image-update ubuntu-22 --dry-run

# Test template creation (dry-run mode)
./bin/build-template --dry-run -i 9000 -n test-template --img /tmp/test.img

# Test with custom storage path
./bin/image-update debian-12 --storage /tmp --dry-run
```

### Manual Operations

```bash
# Download specific image
./bin/image-update ubuntu-22 --remove --storage /var/lib/vz/template/iso

# Create basic template
./bin/build-template -i 9022 -n ubuntu22 --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img

# Create dual-network template
./bin/build-template \
  --net-bridge vmbr0 --net-ip 192.168.1.100/24 --net-gw 192.168.1.1 \
  --net2-bridge vmbr1 --net2-ip 10.0.0.100/24 \
  -i 9002 -n ubuntu-dual-net \
  --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img
```

### Installation & Deployment

```bash
# Automated installation (on Proxmox host)
sudo ./scripts/install.sh

# Manual systemd timer management
sudo systemctl enable image-update@ubuntu-22.timer
sudo systemctl start image-update@ubuntu-22.timer
sudo systemctl list-timers | grep image-update
```

### Debugging & Monitoring

```bash
# View service logs
journalctl -u image-update@ubuntu-22.service -f

# Check timer status
systemctl status image-update@ubuntu-22.timer

# Manual timer execution for testing
sudo systemctl start image-update@ubuntu-22.service

# Check script logs (enhanced logging feature)
ls -la /var/log/image-update-*
ls -la /var/log/proxmox-template-build-*
```

## File Structure Context

```
├── bin/                          # Executable scripts
│   ├── image-update             # Enhanced cloud image downloader
│   └── build-template           # Proxmox template creator
├── systemd/                     # Systemd service files
│   ├── image-update@.service    # Service template
│   ├── image-update@.timer      # Timer template
│   └── image-update-enhanced@.service  # Enhanced service version
├── snippets/                    # Cloud-init configurations
│   └── vendor-data.yaml         # Default cloud-init setup (qemu-guest-agent)
├── scripts/                     # Installation scripts
│   └── install.sh               # Automated installer for Proxmox hosts
└── docs/                        # Documentation
    ├── quick-start.md           # Quick setup guide
    └── compliance-checklist-20250107.md
```

## Testing Approach

The project includes dry-run capabilities for safe testing:

- **Image downloads**: Use `--dry-run` flag to simulate without downloading
- **Template creation**: Use `--dry-run` to validate commands without VM
  creation
- **Timer testing**: Use `systemctl start` to manually trigger services

## Cloud-init Integration

Templates use `/var/lib/vz/snippets/vendor-data.yaml` for:

- Installing qemu-guest-agent
- Updating all packages
- System reboot after setup

Custom cloud-init files can be specified with `--vendor-file` parameter.

## Template ID Conventions

Standard template ID ranges:

- Ubuntu 20.04: 9020
- Ubuntu 22.04: 9022
- Ubuntu 24.04: 9024
- Debian 12: 9120

## Network Configuration

The build-template script supports sophisticated networking:

- Primary interface: `--net-bridge`, `--net-ip`, `--net-gw`, `--net-vlan`
- Secondary interface: `--net2-bridge`, `--net2-ip`, `--net2-gw`, `--net2-vlan`
- Both static IP and DHCP configuration supported per interface

## Error Handling & Reliability

Enhanced error handling includes:

- Strict bash error handling (`set -euo pipefail`)
- Comprehensive logging with timestamps
- Lock files preventing concurrent execution
- Retry logic for network operations
- Cleanup traps for resource management
- Status file generation for monitoring integration
