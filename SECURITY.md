# Security Policy and Features

## Security Status

cbox has undergone comprehensive security auditing and implements multiple security controls to protect your system while providing a functional development environment.

## Security Features

### Container Isolation
- Runs Claude Code in an isolated Docker container
- Limits file system access to explicitly mounted directories
- Uses non-root user inside container via gosu

### Path Protection
- Blocks access to critical system directories (/etc, /usr, /bin, /sbin, /boot, /sys, /proc)
- Validates all directory paths before mounting
- Prevents directory traversal attacks

### Resource Limits
- Memory limited to 2GB (configurable via CBOX_MEMORY)
- CPU limited to 2 cores (configurable via CBOX_CPUS)
- Prevents resource exhaustion attacks

### Read-Only Mounts
- Git configuration mounted as read-only
- SSH known_hosts mounted as read-only
- Prevents modification of sensitive host files

### Authentication Security
- Claude authentication tokens stay on host
- SSH agent forwarding (no key copying)
- Git credentials properly isolated

## Security Considerations

### Complete Shared Resources Documentation

**IMPORTANT**: For a comprehensive list of ALL shared resources between your host and the container, including:
- 7 persistent volume mounts
- 6 tmpfs RAM-based mounts  
- 6 environment variables
- Docker security capabilities
- Network access details

Please see the [Complete Shared Resources Documentation](README.md#complete-shared-resources-documentation) section in the README.

### Network Access
- Container has **FULL, UNRESTRICTED** network access (no egress firewall)
- Can connect to ANY external service or website
- Can access local network and host services
- Can download/upload data without restrictions
- Suitable for development, **NOT** for production isolation

### Mounted Directories and Files
The container has access to these host resources:
- **Working directory**: Full read/write access to your project (read-only in paranoid mode)
- **~/.claude/**: Full access to Claude agents and settings
- **~/.claude.json**: Contains your Claude API authentication token
- **~/.gitconfig**: Read-only access to Git configuration
- **~/.config/gh**: Read-only access to GitHub CLI config (standard/restricted modes only)
- **~/.ssh/known_hosts**: Read-only access to SSH known hosts
- **~/.git-credentials**: Read-only access to Git credentials (if exists)
- **SSH Agent Socket**: Can use your SSH keys for Git operations (not in paranoid mode)

### GitHub Authentication Security
cbox securely handles GitHub authentication tokens:
- **Token Validation**: All tokens are validated against GitHub's official token formats
- **Injection Prevention**: Tokens are checked for shell metacharacters and properly escaped
- **Mode Enforcement**: Tokens are NEVER forwarded in paranoid mode
- **Secure Logging**: Token presence is logged with SHA256 hash (first 8 chars only)
- **Atomic Operations**: Directory mounting uses atomic stat operations to prevent TOCTOU attacks

**Critical**: Only use with trusted repositories and projects.

### Memory Overhead
The tmpfs mounts consume up to 1.4 GB of RAM:
- `/tmp`: 512 MB
- `/home/host/.cache`: 512 MB  
- `/home/host/.npm`: 256 MB
- `/run`: 64 MB
- `/var/tmp`: 64 MB
- `/home/host/bin`: 64 MB

### Permission Model
- Uses `--dangerously-skip-permissions` flag for Claude Code
- Gives Claude broad access within the container
- Container runs with specific Linux capabilities (CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID)
- Files created maintain host user ownership via UID/GID mapping

## Vulnerability Reporting

If you discover a security vulnerability in cbox, please:

1. **Do not** create a public GitHub issue
2. Email security details to the maintainer
3. Include steps to reproduce the issue
4. Allow time for a fix before public disclosure

## Security Audit History

This project has undergone multiple security audits:

1. **Initial Security Audit**: Identified and fixed critical vulnerabilities including:
   - Path traversal prevention
   - System directory protection
   - Resource limit implementation
   - Proper error handling

2. **Re-audit Verification**: Confirmed all identified vulnerabilities were properly remediated

3. **Secret Scanning**: Comprehensive scan of git history confirmed:
   - No API keys or secrets in repository
   - No credentials in commit history
   - Proper secret management practices

## Best Practices for Users

1. **Only use cbox with trusted code** - The container has network access
2. **Keep Docker updated** - Security patches are important
3. **Review mounted directories** - Understand what's being shared
4. **Use SSH agent forwarding** - Don't copy keys into containers
5. **Authenticate on host first** - Run `claude login` outside cbox
6. **Monitor resource usage** - Adjust limits as needed

## Secret Scanning

The project includes git pre-commit hooks for preventing accidental secret commits:

- **Gitleaks**: Fast secret detection
- **TruffleHog**: Comprehensive scanning with verification
- See [SECRET_SCANNING.md](docs/SECRET_SCANNING.md) for setup instructions

## Security Tools Integration

Development tools are managed via Hermit package manager:
- Consistent tool versions across environments
- Isolated from system packages
- See `bin/` directory for Hermit-managed tools

## Known Limitations

1. **No network isolation** - Container can access any network resource
2. **Claude permissions** - Uses dangerous skip permissions flag
3. **Host directory access** - Mounted directories are fully accessible
4. **No secrets management** - Users must manage their own secrets

## Security Updates

Security updates are released as patch versions. Update regularly:

```bash
curl -fsSL https://raw.githubusercontent.com/bradleydwyer/cbox/main/install.sh | bash
```

## Compliance

This tool is designed for development use and should not be used in production environments or for processing sensitive data requiring regulatory compliance.

## Contact

For security concerns, contact the maintainer via GitHub: [@bradleydwyer](https://github.com/bradleydwyer)