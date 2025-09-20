# Contributing to Hercules-Power-Templates

Thank you for your interest in contributing to Hercules-Power-Templates! This
document provides guidelines and instructions for contributors.

## Development Setup

### Prerequisites

- Proxmox VE host for testing (or a test VM)
- Development machine with:
  - Bash 4.0+
  - Git
  - mise (for linting tools)
  - ShellCheck (via mise)
  - Prettier (via mise)

### Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/Hercules-Power-Templates.git
   cd Hercules-Power-Templates
   ```
3. Install development tools:
   ```bash
   mise install
   ```

## Development Workflow

### Script Development

1. **Edit scripts in `scripts/` directory** - These are the development versions
2. **Run linting**:
   ```bash
   mise run lint
   ```
3. **Test with dry-run**:
   ```bash
   ./scripts/image-update.sh ubuntu-22 --dry-run
   ./scripts/build-template.sh --dry-run -i 9000 -n test --img test.img
   ```
4. **Copy to `bin/` for production**:
   ```bash
   cp scripts/image-update.sh bin/image-update
   cp scripts/build-template.sh bin/build-template
   ```

### Code Style

- Shell scripts: 2-space indentation
- Use `set -euo pipefail` in all scripts
- Follow ShellCheck recommendations
- Add comprehensive logging
- Include error handling

### Testing

Before submitting changes:

1. **Lint all code**:

   ```bash
   mise run lint
   mise run lint:shellcheck
   mise run lint:prettier
   ```

2. **Fix formatting issues**:

   ```bash
   mise run fix
   ```

3. **Test on a Proxmox host**:
   - Use `--dry-run` first
   - Test actual functionality
   - Verify systemd service compatibility

### Commit Guidelines

- Use conventional commits: `fix:`, `feat:`, `docs:`, `chore:`
- Keep commits focused and atomic
- Write clear commit messages
- Reference issues when applicable

Example:

```
feat: add support for Rocky Linux images

- Added Rocky Linux to supported distributions
- Updated documentation with Rocky examples
- Tested on Proxmox VE 8.0

Closes #42
```

## Creating Releases

### Prerequisites for Release

1. All tests passing
2. Documentation updated
3. CHANGELOG.md updated
4. Version bumped (if using semantic versioning)

### Release Process

1. **Prepare the release**:

   ```bash
   ./scripts/prepare-release.sh v1.2.3
   ```

   This creates:
   - `release/hercules-power-templates.tar.gz` - Main archive
   - `release/install.sh` - Remote installer
   - SHA256 checksums for both

2. **Test the release locally**:

   ```bash
   # Extract and test
   cd release
   tar -xzf hercules-power-templates.tar.gz
   cd hercules-power-templates
   sudo ./install-local.sh
   ```

3. **Create GitHub Release**:
   - Push your changes: `git push origin main`
   - Create and push tag: `git tag v1.2.3 && git push origin v1.2.3`
   - Go to GitHub releases page
   - Click "Create a new release"
   - Select your tag
   - Upload these files from `release/`:
     - `hercules-power-templates.tar.gz`
     - `hercules-power-templates.tar.gz.sha256`
     - `install.sh`
     - `install.sh.sha256`
   - Add release notes from CHANGELOG.md

4. **Update installer URLs**: After creating your first release, update the URLs
   in:
   - `install-remote.sh` - Replace `YOUR-ORG` with your GitHub organization
   - Documentation files - Update installation URLs

### Release Checklist

- [ ] Version updated in relevant files
- [ ] CHANGELOG.md updated with release notes
- [ ] Documentation reflects new features
- [ ] Scripts tested on Proxmox VE
- [ ] Linting passes (`mise run lint`)
- [ ] Release archive created (`./scripts/prepare-release.sh`)
- [ ] Release tested locally
- [ ] GitHub release created with artifacts
- [ ] Installation URLs updated (first release only)

## Adding New Features

### Adding a New Distribution

1. Update `bin/image-update`:
   - Add distribution to case statement
   - Define URLs and checksums
   - Test download and verification

2. Update documentation:
   - README.md supported distributions
   - scripts/README.md distribution table
   - Examples using new distribution

3. Test the full workflow:
   - Download image
   - Create template
   - Deploy VM from template

### Adding New Options

1. Update the script with new option
2. Add to help text
3. Update scripts/README.md with option documentation
4. Add examples to documentation
5. Test with existing options for compatibility

## Documentation

### Documentation Structure

- `README.md` - User-facing documentation
- `CONTRIBUTING.md` - This file, for contributors
- `CHANGELOG.md` - Version history
- `docs/` - Detailed guides
- `scripts/README.md` - Script reference

### Writing Documentation

- Use clear, concise language
- Include examples for all features
- Test all example commands
- Keep formatting consistent
- Update all affected docs when making changes

## Getting Help

- Open an issue for bugs
- Start a discussion for features
- Check existing issues before creating new ones
- Provide detailed information in bug reports

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Provide constructive feedback
- Focus on what's best for the project
- Accept feedback gracefully

## Security

If you discover a security vulnerability:

1. **DO NOT** open a public issue
2. Email security concerns to [security@your-org.com]
3. Include detailed information
4. Allow time for patching before disclosure

## License

By contributing, you agree that your contributions will be licensed under the
Apache License 2.0.
