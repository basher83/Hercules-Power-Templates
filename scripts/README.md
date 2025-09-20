# Scripts Directory

This directory contains development versions of the main scripts and the installation script. The scripts here are used for linting and testing before being copied to `bin/` for production use.

## Script Overview

| Script              | Purpose                       | Production Location   |
| ------------------- | ----------------------------- | --------------------- |
| `install.sh`        | Automated installation script | N/A (runs from here)  |
| `image-update.sh`   | Cloud image downloader        | `/bin/image-update`   |
| `build-template.sh` | VM template creator           | `/bin/build-template` |

## Installation Script: `install.sh`

Automated installer for deploying the Proxmox template scripts on a Proxmox VE host.

### Usage

```bash
sudo ./install.sh
```

### What It Does

1. **Checks Prerequisites**
   - Verifies running as root
   - Detects Proxmox VE installation (warns if not found)

2. **Creates Directories**
   - `/var/lib/vz/template/iso/` - For cloud images
   - `/var/lib/vz/snippets/` - For cloud-init configs

3. **Installs Scripts**
   - Copies `bin/image-update` to `/usr/local/bin/`
   - Copies `bin/build-template` to `/usr/local/bin/`
   - Sets executable permissions

4. **Installs Systemd Units**
   - `image-update@.service` - Service template
   - `image-update@.timer` - Timer template
   - Reloads systemd daemon

5. **Installs Cloud-init Config**
   - Copies `vendor-data.yaml` to `/var/lib/vz/snippets/`
   - Backs up existing file if present

6. **Configures Timers**
   - Prompts to enable timers for each distribution
   - Options: Ubuntu 20.04, 22.04, 24.04, Debian 12

### Exit Codes

- `0` - Success
- `1` - Not running as root
- `2` - Installation error

## Image Update Script: `image-update.sh`

Downloads and manages cloud images from various distributions.

### Usage

```bash
image-update [OPTIONS] DISTRO-RELEASE
image-update -d DISTRO -r RELEASE [OPTIONS]
```

### Supported Distributions

| Distribution | Release  | Shorthand | File Type |
| ------------ | -------- | --------- | --------- |
| Ubuntu       | 20.04    | ubuntu-20 | .img      |
| Ubuntu       | 22.04    | ubuntu-22 | .img      |
| Ubuntu       | 24.04    | ubuntu-24 | .img      |
| Debian       | 10       | debian-10 | .qcow2    |
| Debian       | 11       | debian-11 | .qcow2    |
| Debian       | 12       | debian-12 | .qcow2    |
| CentOS       | Stream 9 | centos-9  | .qcow2    |
| Fedora       | 40       | fedora-40 | .qcow2    |
| Fedora       | 41       | fedora-41 | .qcow2    |

### Options

| Option          | Description                                     | Default                    |
| --------------- | ----------------------------------------------- | -------------------------- |
| `-h, --help`    | Display help message                            | -                          |
| `-d, --distro`  | Distribution name (ubuntu/debian/centos/fedora) | Required                   |
| `-r, --release` | Release version                                 | Required                   |
| `-s, --storage` | Storage path for images                         | `/var/lib/vz/template/iso` |
| `-b, --backup`  | Backup existing images                          | false                      |
| `--date`        | Append date to image filename                   | false                      |
| `--remove`      | Remove old images before updating               | false                      |
| `--dry-run`     | Show what would be done without downloading     | false                      |

### Examples

```bash
# Download Ubuntu 22.04 with old image removal
image-update ubuntu-22 --remove

# Download Debian 12 to custom location
image-update debian-12 --storage /custom/path

# Dry-run to test without downloading
image-update ubuntu-24 --dry-run

# Long form with distribution and release
image-update -d ubuntu -r 22 --remove

# Backup existing images before update
image-update debian-12 --backup
```

### Features

- **Checksum Verification**: Validates SHA256 checksums
- **Retry Logic**: Exponential backoff for network failures
- **Lock Files**: Prevents concurrent executions
- **Comprehensive Logging**: Logs to `/var/log/image-update-*.log`
- **Status Files**: Generates JSON status for monitoring
- **Original Extensions**: Preserves .img/.qcow2 extensions

### Environment Variables

- `STORAGE_PATH` - Override default storage location
- `REMOVE_OLD_IMAGE` - Set to true to always remove old images
- `DRY_RUN` - Set to true for dry-run mode

## Template Builder Script: `build-template.sh`

Creates Proxmox VM templates from cloud images with extensive customization options.

### Usage

```bash
build-template -i VM_ID -n VM_NAME --img IMAGE_PATH [OPTIONS]
```

### Required Parameters

| Parameter        | Description            | Example                                                           |
| ---------------- | ---------------------- | ----------------------------------------------------------------- |
| `-i, --id`       | VM ID for the template | `9000`                                                            |
| `-n, --name`     | Name for the template  | `ubuntu22-template`                                               |
| `--img, --image` | Path to cloud image    | `/var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img` |

### Hardware Options

| Option          | Description              | Default           |
| --------------- | ------------------------ | ----------------- |
| `--bios`        | BIOS type (seabios/ovmf) | `seabios`         |
| `--cpu-cores`   | Number of CPU cores      | `1`               |
| `--cpu-sockets` | Number of CPU sockets    | `1`               |
| `--cpu-type`    | CPU type                 | `host`            |
| `--machine`     | Machine type             | `q35`             |
| `--memory`      | Memory in MB             | `1024`            |
| `--scsihw`      | SCSI controller type     | `virtio-scsi-pci` |
| `--resize`      | Increase boot disk size  | `1G`              |
| `--storage`     | Proxmox storage location | `local-lvm`       |
| `--os`          | Operating system type    | `l26`             |

### Network Options

#### Primary Network Interface

| Option         | Description             | Default  |
| -------------- | ----------------------- | -------- |
| `--net-bridge` | Network bridge          | `vmbr0`  |
| `--net-type`   | Network card type       | `virtio` |
| `--net-vlan`   | VLAN tag                | none     |
| `--net-ip`     | IP address (or 'dhcp')  | `dhcp`   |
| `--net-gw`     | Gateway (for static IP) | none     |

#### Secondary Network Interface (Optional)

| Option          | Description              | Default  |
| --------------- | ------------------------ | -------- |
| `--net2-bridge` | Second network bridge    | none     |
| `--net2-type`   | Second network card type | `virtio` |
| `--net2-vlan`   | Second VLAN tag          | none     |
| `--net2-ip`     | Second IP (or 'dhcp')    | `dhcp`   |
| `--net2-gw`     | Second gateway           | none     |

### Cloud-init Options

| Option          | Description                  | Default              |
| --------------- | ---------------------------- | -------------------- |
| `--vendor-file` | Cloud-init vendor data file  | `vendor-data.yaml`   |
| `--ssh-keys`    | Path to SSH public keys file | none                 |
| `--ci-user`     | Cloud-init username          | distribution default |

### Other Options

| Option      | Description                                 | Default |
| ----------- | ------------------------------------------- | ------- |
| `--dry-run` | Test mode - show commands without executing | false   |

### Examples

#### Basic Template

```bash
build-template -i 9022 -n ubuntu22 \
  --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img
```

#### Advanced Hardware Configuration

```bash
build-template -i 9024 -n ubuntu24-high-spec \
  --cpu-cores 4 --cpu-sockets 2 \
  --memory 8192 \
  --resize 50G \
  --storage local-zfs \
  --img /var/lib/vz/template/iso/ubuntu-24.04-server-cloudimg-amd64.img
```

#### Static IP Configuration

```bash
build-template -i 9120 -n debian12-static \
  --net-bridge vmbr0 \
  --net-ip 192.168.1.100/24 \
  --net-gw 192.168.1.1 \
  --img /var/lib/vz/template/iso/debian-12-generic-amd64.qcow2
```

#### Dual Network Configuration

```bash
build-template -i 9025 -n dual-network \
  --net-bridge vmbr0 --net-ip dhcp \
  --net2-bridge vmbr1 --net2-ip 10.0.0.100/24 \
  --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img
```

#### VLAN Configuration

```bash
build-template -i 9026 -n vlan-template \
  --net-bridge vmbr0 --net-vlan 100 \
  --net2-bridge vmbr1 --net2-vlan 200 \
  --img /var/lib/vz/template/iso/debian-12-generic-amd64.qcow2
```

#### SSH Keys and Custom User

```bash
build-template -i 9027 -n secure-template \
  --ssh-keys ~/.ssh/authorized_keys \
  --ci-user admin \
  --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img
```

#### UEFI Boot

```bash
build-template -i 9028 -n uefi-template \
  --bios ovmf \
  --img /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img
```

#### Dry-Run Mode

```bash
build-template --dry-run -i 9000 -n test-template \
  --cpu-cores 2 --memory 2048 \
  --img /var/lib/vz/template/iso/test.img
```

### Environment Variables

The script supports setting defaults via environment variables:

```bash
export VM_ID=9000
export VM_NAME=my-template
export VM_IMAGE=/path/to/image.img
export VM_CPU_CORES=2
export VM_MEMORY=2048
export VM_STORAGE=local-lvm

# Then run with minimal arguments
build-template
```

### Features

- **Dry-Run Mode**: Test commands without making changes
- **Cloud-init Integration**: Full support for customization
- **Dual Network Support**: Configure up to 2 network interfaces
- **VLAN Support**: Tag networks with VLAN IDs
- **SSH Key Injection**: Add authorized keys via cloud-init
- **Custom Username**: Set cloud-init default username
- **UEFI Support**: Create UEFI-bootable templates
- **Comprehensive Logging**: Logs to `/var/log/proxmox-template-build-*.log`

### Exit Codes

- `0` - Success
- `1` - Invalid arguments or help displayed
- `2` - Script error or permission denied
- `3` - VM ID already exists

## Development Workflow

1. **Edit Scripts**: Make changes in `scripts/` directory
2. **Lint Check**: Run `mise run lint:shellcheck`
3. **Test Locally**: Test with dry-run mode
4. **Copy to Production**: Copy to `bin/` directory
5. **Deploy**: Run `install.sh` on Proxmox host

## Linting

Scripts are checked with ShellCheck via mise:

```bash
# Check all scripts
mise run lint:shellcheck

# Manual check
shellcheck scripts/*.sh bin/image-update bin/build-template
```

## Notes

- Scripts in this directory are for development and testing
- Production scripts are in `bin/` without the `.sh` extension
- The `install.sh` script copies from `bin/` not `scripts/`
- Always test changes with `--dry-run` before production use
