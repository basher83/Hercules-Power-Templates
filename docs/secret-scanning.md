# Secret Scanning with Infisical

This repository is configured with Infisical secret scanning to prevent
accidental commits of sensitive information.

## Setup

The secret scanning is automatically configured with:

- **Infisical CLI** pre-commit hook that scans staged changes
- **Custom configuration** in `.infisical-scan.toml` tailored for infrastructure
  projects
- **False positive filtering** for common infrastructure patterns

## How it works

1. **Pre-commit scanning**: Every time you commit, Infisical scans your staged
   changes for secrets
2. **Blocked commits**: If secrets are detected, the commit is blocked with
   details
3. **Custom rules**: Configured to ignore common false positives like template
   variables, localhost, example domains

## Configuration

The scanning behavior is controlled by `.infisical-scan.toml`:

- **Baseline**: `.infisical-baseline.json` contains acceptable findings from
  initial repository scan
- **Allowlist**: Regex patterns for acceptable content (templates, examples,
  docs)
- **Exclusions**: Paths to ignore (.git, node_modules)
- **Performance**: File size limits and scanning optimization

## Managing the scanner

### Temporarily disable scanning

If you need to bypass the scanner for a specific commit:

```bash
git config hooks.infisical-scan false
git commit -m "your commit message"
git config hooks.infisical-scan true  # Re-enable
```

### Run manual scans

```bash
# Scan entire repository
infisical scan

# Scan with verbose output
infisical scan --verbose

# Scan only staged changes
infisical scan git-changes --staged
```

### Update configuration

Edit `.infisical-scan.toml` to adjust scanning rules, add new allowlist
patterns, or modify exclusions as needed.

### Regenerate baseline

If you need to update the baseline after reviewing the repository:

```bash
# Generate new baseline (review findings first!)
infisical scan --report-format json --report-path .infisical-baseline.json

# Commit the updated baseline
git add .infisical-baseline.json
git commit -m "update: regenerate Infisical baseline"
```

or modify exclusions as needed.

## Common false positives

The configuration already handles:

- Template variables: `{{variable}}`
- Environment variables: `${VAR}`
- Example domains: `example.com`
- Localhost addresses
- Documentation URLs
- System paths: `/var/lib/vz/`, `/etc/systemd/`

If you encounter new false positives, add them to the `allowlist.regexes`
section in `.infisical-scan.toml`.
