# Quick Start Guide

## Installation (2 minutes)

On your Proxmox host, simply run:

```bash
# Quick install with curl
curl -fsSL https://github.com/basher83/Hercules-Power-Templates/releases/latest/download/install.sh | sudo bash

# Or with wget
wget -qO- https://github.com/basher83/Hercules-Power-Templates/releases/latest/download/install.sh | sudo bash
```

No git required! The installer downloads everything needed.

## Create Your First Template (5 minutes)

```bash
# 1. Wait for or manually download an image
sudo image-update ubuntu-22 --remove

# 2. Create a template (Ubuntu uses .img)
sudo build-template -i 9022 -n ubuntu22 --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img

# OR for Debian (uses .qcow2)
sudo image-update debian-12 --remove
sudo build-template -i 9120 -n debian12 --img /var/lib/vz/template/iso/debian-12-generic-amd64.qcow2

# 3. Verify template was created
qm list | grep template
```

## Common Commands

```bash
# Check timer status
systemctl list-timers | grep image-update

# Manual image download
image-update ubuntu-22 --remove
image-update debian-12 --remove

# Create Ubuntu template with custom settings (.img)
build-template --cpu-cores 2 --memory 2048 -i 9024 -n ubuntu24 --img /var/lib/vz/template/iso/ubuntu-24.04-server-cloudimg-amd64.img

# Create Debian template with custom settings (.qcow2)
build-template --cpu-cores 2 --memory 2048 -i 9120 -n debian12 --img /var/lib/vz/template/iso/debian-12-generic-amd64.qcow2

# Create template with SSH keys for secure access
build-template --ssh-keys ~/.ssh/id_rsa.pub -i 9023 -n ubuntu22-ssh --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img

# Create template with custom username
build-template --ci-user admin --ssh-keys ~/.ssh/id_rsa.pub -i 9026 -n admin-template --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img

# View logs
journalctl -u image-update@ubuntu-22.service -f
```

## Template IDs Convention

- Ubuntu 20.04: 9020
- Ubuntu 22.04: 9022
- Ubuntu 24.04: 9024
- Debian 12: 9120
