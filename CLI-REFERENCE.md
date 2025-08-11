# cbox CLI Reference

Complete command-line interface reference for cbox v1.2.1

## Synopsis

```bash
cbox [OPTIONS] [DIRECTORY] [-- CLAUDE_ARGS...]
```

## Description

cbox runs Claude Code in a Docker sandbox with full network access and SSH agent forwarding. It provides an isolated environment while maintaining access to your host's authentication, Git configuration, and SSH keys.

## Options

### Core Options

#### `-h, --help`
Display help information and exit.

```bash
cbox --help
```

#### `-v, --version`
Display version information and exit.

```bash
cbox --version
# Output: cbox version 1.2.1
```

#### `--verbose`
Enable verbose debug output. Shows detailed information about Docker commands, volume mounts, and container execution.

```bash
cbox --verbose
# Equivalent to: CBOX_VERBOSE=1 cbox
```

#### `--shell`
Open an interactive bash shell in the container instead of running Claude Code. Useful for debugging and manual operations.

```bash
cbox --shell
# Opens: /bin/bash in container
```

#### `--verify`
Verify the installation and exit. Checks for Docker, SSH agent, and Claude authentication without running a container.

```bash
cbox --verify
# Output:
# ✓ cbox v1.2.1 installed successfully
# ✓ Docker is available and running
# ✓ SSH agent is running
# ✓ Claude authentication found
```

#### `-e VAR` or `-e VAR=value`
Pass environment variables to the container. Supports two formats:
- `-e VAR`: Pass variable from host environment (value taken from host)
- `-e VAR=value`: Set specific value directly

**New in v1.2.0**: Explicit control over environment variable passthrough.

```bash
# Pass variables from host environment
export AWS_PROFILE=production
cbox -e AWS_PROFILE -e AWS_REGION

# Set specific values
cbox -e "DEBUG=true" -e "LOG_LEVEL=verbose"

# Mix both formats
cbox -e AWS_PROFILE -e "ANTHROPIC_MODEL=claude-opus-4-1"

# Multiple variables for AWS Bedrock
cbox -e AWS_PROFILE -e AWS_REGION -e CLAUDE_CODE_USE_BEDROCK
```

**Important notes:**
- No automatic passthrough - you must explicitly specify each variable
- Empty or unset variables produce a warning in verbose mode
- Use multiple `-e` flags to pass multiple variables
- Values with spaces should be quoted: `-e "MY_VAR=value with spaces"`

## Arguments

### `DIRECTORY`
Optional. The directory to mount as the working directory in the container. If not specified, uses the current directory.

```bash
cbox                    # Use current directory
cbox ~/projects/myapp   # Use specific directory
cbox /tmp/test         # Use absolute path
```

**Security restrictions:**
- Cannot access system directories (/etc, /sys, /proc, /dev, /boot, /root)
- Cannot access binary directories (/bin, /sbin, /lib, /usr/bin, /usr/sbin)
- Cannot access system service directories (/var/log, /var/run, /var/lock)
- Allowed: /home, /tmp, /var/tmp, and user directories

### `-- CLAUDE_ARGS...`
Optional. Arguments to pass directly to the Claude Code CLI. Must be preceded by `--` to separate from cbox options.

```bash
cbox -- chat                           # Start chat mode
cbox -- chat --model opus              # Use specific model
cbox -- chat "Fix the bug in main.py"  # Direct command
```

## Environment Variables

### Required Variables

#### `SSH_AUTH_SOCK`
Path to SSH agent socket. Required for Git operations with private repositories.

```bash
# Start SSH agent if not running
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa
```

### Optional Variables

#### `CBOX_REBUILD`
Force rebuild of the Docker image. Set to `1` to rebuild.

```bash
CBOX_REBUILD=1 cbox
```

#### `CBOX_VERBOSE`
Enable verbose debug output. Set to `1` to enable.

```bash
CBOX_VERBOSE=1 cbox
# Equivalent to: cbox --verbose
```

#### `XDG_CACHE_HOME`
Override cache directory location. Default: `~/.cache`

```bash
XDG_CACHE_HOME=/tmp/cache cbox
```

#### `XDG_CONFIG_HOME`
Override config directory location. Default: `~/.config`

```bash
XDG_CONFIG_HOME=/tmp/config cbox
```

#### `XDG_DATA_HOME`
Override data directory location. Default: `~/.local/share`

```bash
XDG_DATA_HOME=/tmp/data cbox
```

#### `TERM`
Terminal type passed to container. Default: `xterm-256color`

```bash
TERM=xterm cbox
```

## Volume Mounts

cbox automatically mounts the following volumes:

| Host Path | Container Path | Access | Purpose |
|-----------|---------------|--------|---------|
| `$WORKDIR` | `/work` | read-write | Project files |
| `$SSH_AUTH_SOCK` | `/ssh-agent` | socket | SSH authentication |
| `~/.claude` | `/home/host/.claude` | read-write | Claude config/agents |
| `~/.claude.json` | `/home/host/.claude.json` | read-write | Claude authentication |
| `~/.gitconfig` | `/home/host/.gitconfig` | read-only | Git configuration |
| `~/.ssh/known_hosts` | `/home/host/.ssh/known_hosts` | read-only | SSH known hosts |
| `~/.git-credentials` | `/home/host/.git-credentials` | read-only | Git credentials |

## Docker Container Details

### Base Image
`node:20-bookworm-slim`

### Installed Packages
- git
- openssh-client
- ca-certificates
- tini (init system)
- bash
- less
- curl
- wget
- procps (process utilities)
- gosu (user switching)
- @anthropic-ai/claude-code (latest)
- hermit (package manager)

### Resource Limits
- Memory: 2GB
- CPUs: 2 cores

### User Mapping
Container automatically maps to your host user ID/GID to ensure proper file ownership.

## Examples

### Basic Usage

```bash
# Run in current directory
cbox

# Run in specific project
cbox ~/projects/myapp

# Open shell for debugging
cbox --shell
```

### With Claude Arguments

```bash
# Start chat with specific model
cbox -- chat --model opus

# Execute a specific task
cbox -- chat "Write unit tests for auth.py"

# Review code changes
cbox ~/project -- chat "Review the changes in my last commit"
```

### Advanced Usage

```bash
# Force rebuild and run verbose
CBOX_REBUILD=1 CBOX_VERBOSE=1 cbox

# Use custom cache directory
XDG_CACHE_HOME=/tmp/cbox-cache cbox

# Run with custom terminal
TERM=xterm-256color cbox

# Multiple environment variables
CBOX_VERBOSE=1 TERM=xterm cbox --shell
```

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Code Review with Claude
  run: |
    eval $(ssh-agent -s)
    ssh-add - <<< "${{ secrets.SSH_PRIVATE_KEY }}"
    ./cbox . -- chat "Review code for security issues"

# GitLab CI example
code_review:
  script:
    - eval $(ssh-agent -s)
    - echo "$SSH_PRIVATE_KEY" | ssh-add -
    - cbox . -- chat "Check for code quality issues"
```

### Troubleshooting Commands

```bash
# Verify installation
cbox --verify

# Check Docker image
docker images | grep cbox

# Remove and rebuild image
docker rmi cbox:latest
CBOX_REBUILD=1 cbox --verify

# Debug mode
CBOX_VERBOSE=1 cbox 2>&1 | tee cbox-debug.log

# Check container processes
docker ps | grep cbox

# Clean up stopped containers
docker container prune
```

## Configuration File

cbox supports an optional `.cbox.json` configuration file. See the main README for configuration options.

```bash
# Use project-specific config
echo '{"network": "host"}' > .cbox.json
cbox

# Use user-specific config
echo '{"memory": "4g"}' > ~/.cbox.json
cbox
```

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Docker not found or not running |
| 3 | SSH agent not available |
| 4 | Invalid directory or path |
| 5 | Security violation (blocked directory) |
| 127 | Command not found |

## Security Considerations

1. **Path Validation**: cbox validates all paths to prevent access to system directories
2. **Shell Injection**: Input is sanitized to prevent shell command injection
3. **Container Isolation**: Runs with limited resources (2GB RAM, 2 CPUs)
4. **Read-only Mounts**: Sensitive files mounted as read-only
5. **User Mapping**: Proper UID/GID mapping prevents permission issues

## Caching

cbox caches the Docker image and Dockerfile in:
```
~/.cache/cbox/
├── Dockerfile
└── [other cache files]
```

To clear the cache:
```bash
rm -rf ~/.cache/cbox
docker rmi cbox:latest
```

## Uninstallation

```bash
# Remove cbox script
sudo rm /usr/local/bin/cbox

# Remove Docker image
docker rmi cbox:latest

# Clean cache and config
rm -rf ~/.cache/cbox
rm -rf ~/.config/cbox
rm -rf ~/.local/share/cbox

# Remove any stopped containers
docker container prune
```

## See Also

- [README.md](README.md) - Main documentation
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [SECURITY_AUDIT.md](SECURITY_AUDIT.md) - Security analysis

## Support

For issues, questions, or contributions, visit:
https://github.com/bradleydwyer/cbox