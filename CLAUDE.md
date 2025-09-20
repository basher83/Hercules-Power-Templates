# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

This is a Proxmox VE automation project that provides scripts for downloading
cloud images and creating VM templates. The project consists of two main tools:

- `image-update`: Downloads latest cloud images from Ubuntu, Debian, CentOS, and
  Fedora
- `build-template`: Creates Proxmox VM templates from downloaded cloud images

## Commands

### Development & Quality Checks

```bash
# Run all linting checks (shellcheck + prettier)
mise run lint

# Check shell scripts only
mise run lint:shellcheck

# Check formatting only
mise run lint:prettier

# Auto-fix formatting issues
mise run fix

# Run pre-commit hooks manually
mise run pre-commit

# Install pre-commit hooks
mise run pre-commit:install
```

### Testing Scripts Locally

```bash
# Test image-update script
./bin/image-update ubuntu-22 --storage /tmp

# Test build-template script (dry run)
./bin/build-template --help
```

## Architecture & Code Structure

### Script Organization

The project maintains two copies of each main script:

- **`bin/`**: Production-ready executables deployed to `/usr/local/bin/`
- **`scripts/`**: Development copies for linting and testing

When modifying scripts, update the `scripts/` version first, test thoroughly,
then copy to `bin/`.

### Systemd Integration

The scripts are designed to run as systemd services:

- **Service templates**: `systemd/image-update@.service` (parameterized by
  distribution)
- **Timer templates**: `systemd/image-update@.timer` (monthly schedule with
  randomization)

### Script Features

Both main scripts follow production standards:

- Strict error handling with `set -euo pipefail`
- Comprehensive logging to `/var/log/` with timestamps
- Checksum verification for downloaded images
- Atomic operations with temporary files
- Network retry logic with exponential backoff
- Cleanup of old images (with `--remove` flag)

### Cloud-Init Configuration

Templates use `snippets/vendor-data.yaml` for cloud-init configuration:

- Installs qemu-guest-agent
- Updates packages
- Configures for Proxmox integration

## Development Guidelines

### Shell Script Standards

- Always use `set -euo pipefail` for error handling
- Include error traps with line number reporting
- Use shellcheck-compliant bash syntax
- Follow existing logging patterns (log_info, log_warn, log_error)
- Validate all user inputs and file operations
- Use atomic operations for file modifications

### Code Style

- Shell scripts: 2-space indentation
- YAML/JSON: 2-space indentation
- Markdown: 80-character line width
- Use prettier for formatting (configured in `.prettierrc.json`)

### Pre-commit Workflow

The repository uses pre-commit hooks for quality control:

- ShellCheck for shell script linting
- Prettier for formatting
- File validation (shebangs, permissions, trailing whitespace)
- Secret scanning with Infisical

### Testing Changes

Before committing script changes:

1. Run `mise run lint` to check for issues
2. Test scripts with sample data in `/tmp`
3. Verify systemd service compatibility
4. Check logs in journal and file outputs
