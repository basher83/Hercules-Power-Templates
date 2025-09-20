# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### Documentation & Attribution

- **Enhancement blocks**: Comprehensive documentation blocks added to all scripts to respect original author's work
  - Added enhancement blocks to `image-update` and `build-template` scripts
  - Documents all improvements with clear attribution to original proxmox-template-scripts by Taylor Fore
  - Includes proper links to coding standards documentation (https://raw.githubusercontent.com/basher83/automation-scripts/refs/heads/main/CODING_STANDARDS.md)
  - Documents dual network interface support (`--net2`) functionality with detailed feature descriptions

## [1.0.0] - 2025-09-20

### Added

#### Project Infrastructure & Tooling

- **Pre-commit hooks**: Comprehensive pre-commit configuration with multiple quality checks
  - Trailing whitespace and end-of-file fixing
  - YAML validation and merge conflict detection
  - Executable file validation (shebangs and permissions)
  - Prettier formatting for Markdown, YAML, and JSON
  - ShellCheck linting for shell scripts
- **Shell script linting**: ShellCheck configuration with project-specific exclusions
  - Custom `.shellcheckrc` with infrastructure-appropriate rules
  - Linting coverage for both `bin/` executables and `scripts/` development copies
  - Exclusions for common patterns (SC1091, SC2155, SC2329, SC2248, SC2046, SC2086)
- **Code formatting**: Prettier configuration optimized for infrastructure projects
  - Infrastructure-specific file type handling
  - Consistent 2-space indentation for YAML/JSON
  - Special formatting rules for documentation files
  - 80-character line width for readability
- **Editor configuration**: Enhanced `.editorconfig` for consistent development
  - File-type specific indentation and line length settings
  - Unified configuration for shell scripts, YAML, JSON, and Markdown
  - Proper line ending and charset settings
- **Secret scanning**: Comprehensive Infisical secret scanning setup
  - Infisical Git hook for automatic scanning (installed via `infisical scan install --pre-commit-hook`)
  - Custom configuration with infrastructure-specific allowlists (.infisical-scan.toml)
  - Baseline scan establishment for existing repository state (.infisical-baseline.json)
  - Documentation for managing false positives and scanner configuration
- **Development tools**: mise-based tool management
  - Automated installation of linting and formatting tools
  - Version-pinned tools (shellcheck 0.11.0, prettier 3.6.2, pre-commit 4.3.0)
  - **Linting tasks** (read-only checks): `mise run lint`, `mise run lint:shellcheck`, `mise run lint:prettier`
  - **Fix tasks** (auto-repair): `mise run fix`, `mise run fix:prettier`
  - **Pre-commit workflow**: `mise run pre-commit`, `mise run pre-commit:install`
  - Clear separation between checking, fixing, and git workflow automation
- **Documentation**: Comprehensive development and usage documentation
  - WARP.md for AI assistant context and development guidance
  - Secret scanning documentation with usage examples
  - Architecture overview and common development commands

#### Core Project Files

- **Proxmox automation scripts**: Enhanced cloud image and template management
  - `bin/image-update`: Production-ready cloud image downloader with retry logic
  - `bin/build-template`: Proxmox template creator with dual-network support
  - `scripts/install.sh`: Automated installation for Proxmox hosts
- **Systemd integration**: Automated scheduling and service management
  - `systemd/image-update@.service`: Parameterized service template
  - `systemd/image-update@.timer`: Monthly scheduling with randomization
  - Support for multiple distributions (Ubuntu 20/22/24, Debian 12)
- **Cloud-init configuration**: Pre-configured VM setup automation
  - `snippets/vendor-data.yaml`: qemu-guest-agent installation and updates
  - Customizable cloud-init integration

### Changed

- **Documentation**: Updated all references from old package name to repository structure
  - README.md now references `Hercules-Power-Templates` instead of `proxmox-template-scripts`
  - Installation instructions updated to use `./scripts/install.sh` path
  - Package structure diagram updated to reflect actual directory layout

### Fixed

- **Systemd service configuration**: Fixed incorrect script path in `image-update@.service`
  - Changed ExecStart from non-existent `/usr/local/bin/image-update.enhanced` to `/usr/local/bin/image-update`
  - Removed duplicate `image-update-enhanced@.service` file
- **Dry-run mode**: Made `build-template --dry-run` truly non-mutating
  - Added `run()` wrapper function to handle dry-run checks consistently
  - All `qm` commands (disk import, set, resize, template) now respect dry-run mode
  - Cloud-init configuration commands properly wrapped for dry-run support
- **Checksum verification**: Fixed checksum mismatches for non-Ubuntu distributions
  - Preserve original file extensions (.img for Ubuntu, .qcow2 for Debian/CentOS/Fedora)
  - Updated `check_shasum()` to verify files with their actual extensions
  - Documentation updated with correct file extension examples
- **SSH key injection**: Implemented `--ssh-keys` functionality in build-template
  - Now properly applies SSH public keys via Proxmox cloud-init integration
  - Supports single key files or authorized_keys with multiple keys
  - Added documentation and examples for SSH key usage
- **Custom cloud-init username**: Added `--ci-user` flag to build-template
  - Allows setting custom username for cloud-init default user
  - Integrates with Proxmox's `--ciuser` parameter
  - Useful for standardizing usernames across templates (e.g., 'admin', 'ansible')
  - Added documentation and examples for username customization

### Removed

- **Duplicate files**: Cleaned up redundant service configurations
  - Removed `systemd/image-update-enhanced@.service` (duplicate of standard service)
  - Removed stale references to enhanced service from documentation

### Security

- **Secret scanning**: Implemented Infisical-based secret detection
  - Pre-commit hook prevents accidental secret commits
  - Baseline scan established for existing repository state
  - Custom allowlist rules for infrastructure-specific false positives
  - Comprehensive documentation for team usage and management
- **Systemd service hardening**: Added comprehensive security constraints to `image-update@.service`
  - File system protection with `ProtectSystem=strict` and limited `ReadWritePaths`
  - Process isolation with `NoNewPrivileges`, `RestrictSUIDSGID`, and `RestrictNamespaces`
  - Kernel protection with `ProtectKernelTunables`, `ProtectKernelLogs`, and `ProtectClock`
  - Capability restrictions removing all capabilities
  - Private temporary directories with `PrivateTmp=yes`
  - Restrictive file permissions with `UMask=0077`
  - Documentation in `docs/systemd-security.md`
