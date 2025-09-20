# Hercules-Power-Templates

A comprehensive set of scripts for automatically downloading cloud images and
creating Proxmox VE templates.

This repository is inspired by
[proxmox-template-scripts](https://github.com/trfore/proxmox-template-scripts)
by Taylor Fore. All credit goes to them. I mearly extended the scripts to
support more features for my use cases ie multiple NICS.

Also, Packer is too slow for my sanity to remain in tact.

## Overview

This package provides two main components:

1. **`image-update`** - Automatically downloads the latest cloud images on a
   monthly schedule
2. **`build-template`** - Creates Proxmox templates from downloaded cloud images

## Features

- **Automated Image Updates**: Monthly downloads of Ubuntu 20.04, 22.04, 24.04
  LTS and Debian 12 cloud images
- **Template Creation**: Easy CLI tool to create Proxmox templates with
  customizable settings
- **Cloud-Init Support**: Pre-configured with qemu-guest-agent installation
- **Systemd Timers**: Reliable scheduling with randomized delays and persistence
- **Storage Management**: Automatic cleanup of old images (with --remove flag)

## Supported Distributions

- **Ubuntu**: 20.04 LTS, 22.04 LTS, 24.04 LTS
- **Debian**: 12 (Bookworm)
- **CentOS**: Supported by image-update script
- **Fedora**: Supported by image-update script

## Package Contents

```text
Hercules-Power-Templates/
├── bin/
│   ├── image-update          # Cloud image download script
│   └── build-template        # Template creation script
├── scripts/
│   ├── install.sh            # Automated installation script
│   ├── image-update.sh       # Development copy for linting
│   └── build-template.sh     # Development copy for linting
├── systemd/
│   ├── image-update@.service # Systemd service template
│   └── image-update@.timer   # Systemd timer template
├── snippets/
│   └── vendor-data.yaml      # Cloud-init configuration
├── docs/
└── README.md                 # This file
```

## Installation

### Quick Install (Recommended)

On your Proxmox host, run:

```bash
# Using curl
curl -fsSL https://github.com/YOUR-ORG/Hercules-Power-Templates/releases/latest/download/install.sh | sudo bash

# Or using wget
wget -qO- https://github.com/YOUR-ORG/Hercules-Power-Templates/releases/latest/download/install.sh | sudo bash
```

### Verified Installation

For security-conscious users who want to review the script first:

```bash
# Download and review the installer
wget https://github.com/YOUR-ORG/Hercules-Power-Templates/releases/latest/download/install.sh
less install.sh

# Run the installer
sudo bash install.sh
```

### Development Installation

For development or customization:

1. Clone the repository (requires git):

   ```bash
   git clone https://github.com/YOUR-ORG/Hercules-Power-Templates.git
   cd Hercules-Power-Templates
   ```

2. Run the installation script:
   ```bash
   sudo ./scripts/install.sh
   ```

### Manual Installation

If you prefer to install manually or the automated installer doesn't work

1. Copy scripts to system directories:

   ```bash
   cp bin/* /usr/local/bin/
   chmod +x /usr/local/bin/image-update /usr/local/bin/build-template
   ```

2. Install systemd units:

   ```bash
   cp systemd/* /etc/systemd/system/
   systemctl daemon-reload
   ```

3. Copy cloud-init configuration:

   ```bash
   cp snippets/vendor-data.yaml /var/lib/vz/snippets/
   ```

4. Enable and start timers:
   ```bash
   systemctl enable --now image-update@ubuntu-20.timer
   systemctl enable --now image-update@ubuntu-22.timer
   systemctl enable --now image-update@ubuntu-24.timer
   systemctl enable --now image-update@debian-12.timer
   ```

## Usage

### Image Updates

The image-update timers run automatically on the 1st of each month with
randomized delays (0-3 hours) to prevent bandwidth spikes.

**Check timer status:**

```bash
systemctl list-timers | grep image-update
```

**Manual image update:**

```bash
# Download latest Ubuntu 22.04 image
image-update ubuntu-22

# Download and remove old images
image-update ubuntu-22 --remove

# Custom storage location
image-update ubuntu-22 --storage /custom/path
```

### Template Creation

**Basic template creation:**

```bash
# Ubuntu (uses .img extension)
build-template -i 9022 -n ubuntu22 --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img

# Debian (uses .qcow2 extension)
build-template -i 9120 -n debian12 --img /var/lib/vz/template/iso/debian-12-generic-amd64.qcow2
```

**Advanced template with custom specs:**

```bash
# Ubuntu 24.04 with custom resources
build-template \
  --cpu-cores 2 \
  --memory 2048 \
  --storage local-lvm \
  --net-bridge vmbr0 \
  -i 9024 -n ubuntu24-template \
  --img /var/lib/vz/template/iso/ubuntu-24.04-server-cloudimg-amd64.img

# Debian 12 with custom resources
build-template \
  --cpu-cores 2 \
  --memory 4096 \
  --storage local-lvm \
  --net-bridge vmbr0 \
  -i 9120 -n debian12-template \
  --img /var/lib/vz/template/iso/debian-12-generic-amd64.qcow2
```

**Dual network template:**

```bash
build-template \
  --net-bridge vmbr0 --net-ip 192.168.1.100/24 --net-gw 192.168.1.1 \
  --net2-bridge vmbr1 --net2-ip 10.0.0.100/24 \
  -i 9002 -n ubuntu-dual-net \
  --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img
```

**Template with SSH keys:**

```bash
# Create template with SSH public key authentication
build-template \
  --cpu-cores 2 --memory 2048 \
  --ssh-keys ~/.ssh/id_rsa.pub \
  -i 9023 -n ubuntu22-ssh \
  --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img

# Using multiple SSH keys from authorized_keys file
build-template \
  --ssh-keys /home/admin/.ssh/authorized_keys \
  -i 9025 -n secure-template \
  --img /var/lib/vz/template/iso/debian-12-generic-amd64.qcow2
```

**Template with custom cloud-init username:**

```bash
# Create template with custom username (default is usually 'ubuntu' or 'debian')
build-template \
  --ci-user admin \
  --ssh-keys ~/.ssh/id_rsa.pub \
  -i 9026 -n custom-user-template \
  --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img

# Set a specific username for automation
build-template \
  --ci-user ansible \
  --cpu-cores 2 --memory 2048 \
  -i 9027 -n ansible-ready \
  --img /var/lib/vz/template/iso/debian-12-generic-amd64.qcow2
```

## Configuration

### Timer Schedule

The default schedule is monthly on the 1st at 01:00 with up to 3 hours
randomization:

```ini
OnCalendar=*-*-01 01:00:00
RandomizedDelaySec=3h
```

To modify the schedule, edit `/etc/systemd/system/image-update@.timer` and
reload:

```bash
systemctl daemon-reload
systemctl restart image-update@ubuntu-22.timer
```

### Cloud-Init Configuration

The `vendor-data.yaml` file configures cloud-init to:

- Install qemu-guest-agent
- Update all packages
- Reboot after setup

Modify `/var/lib/vz/snippets/vendor-data.yaml` to customize behavior.

### Storage Locations

- **Images**: `/var/lib/vz/template/iso/`
- **Cloud-init**: `/var/lib/vz/snippets/`
- **Templates**: Created in specified Proxmox storage (default: local-lvm)

## Template Management

### Recommended Template IDs

| Distribution | Template ID | Name Suggestion |
| ------------ | ----------- | --------------- |
| Ubuntu 20.04 | 9020        | ubuntu-2004     |
| Ubuntu 22.04 | 9022        | ubuntu-2204     |
| Ubuntu 24.04 | 9024        | ubuntu-2404     |
| Debian 12    | 9120        | debian-12       |

### Template Lifecycle

1. **Download**: Images auto-downloaded monthly
2. **Create**: Use build-template to create VM templates
3. **Update**: Periodically recreate templates with updated images
4. **Deploy**: Clone templates to create VMs

## Cluster Replication

### Option 1: Image Sync (Recommended)

Add rsync to sync images between clusters:

```bash
# Add to crontab or systemd timer
rsync -avz /var/lib/vz/template/iso/ root@cluster2:/var/lib/vz/template/iso/
```

### Option 2: Independent Setup

Deploy this package on each cluster with staggered timing to avoid bandwidth
conflicts.

## Monitoring

### Check Image Updates

```bash
# View recent downloads (notice different extensions)
ls -la /var/lib/vz/template/iso/
# Ubuntu files: *.img
# Debian/CentOS/Fedora files: *.qcow2

# Check last update times
systemctl list-timers | grep image-update

# View service logs
journalctl -u image-update@ubuntu-22.service
journalctl -u image-update@debian-12.service
```

### Check Templates

```bash
# List templates
qm list | grep template

# Template info
qm config 9022
```

## Troubleshooting

### Common Issues

**Permission denied:**

```bash
chown root:root /usr/local/bin/{image-update,build-template}
chmod +x /usr/local/bin/{image-update,build-template}
```

**Systemd units not found:**

```bash
systemctl daemon-reload
systemctl reset-failed
```

**Image download fails:**

- Check internet connectivity
- Verify /var/lib/vz/template/iso/ exists and is writable
- Check logs: `journalctl -u image-update@ubuntu-22.service`

**Template creation fails:**

- Ensure VM ID is not in use: `qm list`
- Check storage availability: `pvesm status`
- Verify image exists and is readable

### Log Locations

- **Service logs**: `journalctl -u image-update@<distro>.service`
- **Timer logs**: `journalctl -u image-update@<distro>.timer`
- **Proxmox logs**: `/var/log/pveproxy/access.log`

## Security Considerations

- Scripts run as root (required for Proxmox operations)
- Images downloaded over HTTPS with checksum verification
- Cloud-init configs should be reviewed before deployment
- Consider network isolation for template creation

## Contributing

Based on
[proxmox-template-scripts](https://github.com/trfore/proxmox-template-scripts)
by Taylor Fore.

## License

Licensed under the Apache License, Version 2.0.

## Support

For issues with:

- **Image downloads**: Check network connectivity and storage space
- **Template creation**: Verify Proxmox configuration and VM ID availability
- **Systemd timers**: Check service status and logs
