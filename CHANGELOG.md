# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
  - Executable shell script copies in `scripts/` directory for linting
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
  - Pre-commit hook integration for automatic scanning
  - Custom configuration with infrastructure-specific allowlists
  - Baseline scan establishment for existing repository state
  - Documentation for managing false positives and scanner configuration
- **Development tools**: mise-based tool management
  - Automated installation of linting and formatting tools
  - Version-pinned tools (shellcheck 0.11.0, prettier 3.6.2, pre-commit 4.3.0)
  - Custom linting tasks: `mise run lint`, `mise run lint:shellcheck`, `mise run lint:prettier`, `mise run lint:pre-commit`
  - Convenient task runners for all quality checks
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

### Fixed

### Removed

### Security

- **Secret scanning**: Implemented Infisical-based secret detection
  - Pre-commit hook prevents accidental secret commits
  - Baseline scan established for existing repository state
  - Custom allowlist rules for infrastructure-specific false positives
  - Comprehensive documentation for team usage and management
