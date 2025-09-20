# Systemd Service Security Hardening

The `image-update@.service` has been hardened with multiple security directives
to ensure safe unattended execution. This document explains each security
measure.

## Security Directives

### File System Protection

- **`UMask=0077`**: Ensures newly created files are only readable by owner (no
  group/world access)
- **`PrivateTmp=yes`**: Provides isolated `/tmp` and `/var/tmp` directories
- **`ProtectSystem=strict`**: Makes entire file system read-only except for
  paths in `ReadWritePaths`
- **`ProtectHome=yes`**: Makes `/home`, `/root`, and `/run/user` inaccessible
- **`ReadWritePaths=/var/lib/vz/template/iso /var/log /var/lock`**: Only these
  paths are writable

### Process Isolation

- **`NoNewPrivileges=yes`**: Prevents privilege escalation via setuid/setgid
  binaries
- **`RestrictSUIDSGID=yes`**: Prevents setuid/setgid bit manipulation
- **`RestrictNamespaces=yes`**: Prevents creating new namespaces
- **`LockPersonality=yes`**: Prevents changing execution domain

### Kernel Protection

- **`DevicePolicy=closed`**: No access to any devices
- **`ProtectKernelTunables=yes`**: Read-only access to `/proc` and `/sys`
- **`ProtectKernelLogs=yes`**: Prevents access to kernel log buffer
- **`ProtectClock=yes`**: Prevents changing system clock

### Capability Restrictions

- **`CapabilityBoundingSet=`**: Removes all capabilities
- **`AmbientCapabilities=`**: Removes all ambient capabilities

### Timeout Configuration

- **`TimeoutStartSec=30min`**: Allows up to 30 minutes for large image downloads

## Impact on Script Operation

The hardening ensures:

1. **Minimal Attack Surface**: Script only has access to necessary directories
2. **No Privilege Escalation**: Cannot gain additional privileges during
   execution
3. **Isolated Execution**: Temporary files are private and cleaned up
   automatically
4. **Protected System**: Cannot modify system files or kernel parameters

## Required Directories

The service requires write access to:

- `/var/lib/vz/template/iso/` - For storing downloaded images
- `/var/log/` - For logging operations
- `/var/lock/` - For lock files preventing concurrent runs

## Testing the Configuration

After installing the service on a Proxmox host:

```bash
# Verify service configuration
systemd-analyze verify /etc/systemd/system/image-update@.service

# Check security score
systemd-analyze security image-update@.service

# Test with a specific distribution
systemctl start image-update@ubuntu-22.service

# Check logs for any permission issues
journalctl -u image-update@ubuntu-22.service
```

## Troubleshooting

If the service fails due to permissions:

1. Check that required directories exist:

   ```bash
   ls -ld /var/lib/vz/template/iso /var/log /var/lock
   ```

2. Verify the script is executable:

   ```bash
   ls -l /usr/local/bin/image-update
   ```

3. Review journal for specific errors:
   ```bash
   journalctl -xe -u image-update@*.service
   ```

## Rolling Back

If security hardening causes issues, you can temporarily reduce restrictions by
commenting out specific directives in the service file and reloading:

```bash
systemctl daemon-reload
systemctl restart image-update@ubuntu-22.service
```

However, it's recommended to keep all security measures enabled for production
use.
