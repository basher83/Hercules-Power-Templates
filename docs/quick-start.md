# Quick Start Guide

## Installation (2 minutes)

```bash
# Extract and install
tar -xzf proxmox-template-scripts.tar.gz
cd proxmox-template-scripts
sudo ./install.sh
```

## Create Your First Template (5 minutes)

```bash
# 1. Wait for or manually download an image
sudo image-update ubuntu-22 --remove

# 2. Create a template
sudo build-template -i 9022 -n ubuntu22 --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img

# 3. Verify template was created
qm list | grep template
```

## Common Commands

```bash
# Check timer status
systemctl list-timers | grep image-update

# Manual image download
image-update ubuntu-22 --remove

# Create template with custom settings
build-template --cpu-cores 2 --memory 2048 -i 9024 -n ubuntu24 --img /path/to/image.img

# View logs
journalctl -u image-update@ubuntu-22.service -f
```

## Template IDs Convention

- Ubuntu 20.04: 9020
- Ubuntu 22.04: 9022
- Ubuntu 24.04: 9024
- Debian 12: 9120
