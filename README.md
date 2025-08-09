# cbox - Claude Code Sandbox

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/bradleydwyer/cbox/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-%3E%3D20.10-blue.svg)](https://www.docker.com/)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20wsl-lightgrey.svg)](README.md#system-requirements)
[![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-green.svg)](README.md#prerequisites)
[![Maintenance](https://img.shields.io/badge/maintained-yes-brightgreen.svg)](https://github.com/bradleydwyer/cbox/commits/main)

A simple Docker-based sandbox for running Claude Code with full network access and SSH agent forwarding.

## What is cbox?

`cbox` provides a one-command way to run Claude Code in an isolated Docker container while maintaining:
- Full network access (no egress firewall)
- SSH agent forwarding for GitHub push/pull
- Your Claude agents and authentication from `~/.claude`
- Proper file ownership (no root-owned files)
- Git configuration and SSH known hosts

## System Requirements

- **Docker**: Docker Desktop 20.10+ or Docker Engine with BuildKit support
- **Operating System**: macOS, Linux, or WSL2 on Windows
- **Shell**: Bash 4.0+ or Zsh
- **SSH Agent**: Active SSH agent with GitHub key loaded
- **Claude Code CLI**: Installed on host (optional but recommended for authentication)
- **Memory**: At least 4GB RAM available for Docker
- **Disk Space**: ~500MB for Docker image plus project space

## Prerequisites

- Docker Desktop installed and running
- SSH agent running with your GitHub key loaded:
  ```bash
  eval $(ssh-agent -s)
  ssh-add ~/.ssh/id_rsa  # or your key path
  ```

## Installation

### Quick Install (Recommended)

```bash
# Download and run the installation script
curl -fsSL https://raw.githubusercontent.com/bradleydwyer/cbox/main/install.sh | bash

# Verify installation
cbox --version
```

### Manual Installation

1. Clone this repository or copy the `cbox` script
2. Make it executable: `chmod +x cbox`
3. Add to your PATH:

   **For bash users:**
   ```bash
   # Option 1: Copy to a directory already in PATH
   sudo cp cbox /usr/local/bin/
   
   # Option 2: Add this directory to PATH (add to ~/.bashrc for permanent)
   echo 'export PATH="$PATH:/path/to/cbox"' >> ~/.bashrc
   source ~/.bashrc
   ```

   **For zsh users:**
   ```bash
   # Option 1: Copy to a directory already in PATH
   sudo cp cbox /usr/local/bin/
   
   # Option 2: Add this directory to PATH (add to ~/.zshrc for permanent)
   echo 'export PATH="$PATH:/path/to/cbox"' >> ~/.zshrc
   source ~/.zshrc
   ```

## Usage

For complete command-line reference, see [CLI-REFERENCE.md](CLI-REFERENCE.md).

### Quick Help

```bash
cbox --help               # Show help information
cbox --version            # Display version
cbox --verbose            # Run with debug output
cbox --verify             # Verify installation
```

### Basic usage
Run in current directory:
```bash
cbox
```

Run in specific directory:
```bash
cbox ~/code/my-project
```

### Advanced usage
Pass extra arguments to Claude:
```bash
cbox ~/code/my-project -- chat --model sonnet-4.1
```

Force rebuild the Docker image:
```bash
CBOX_REBUILD=1 cbox
```

### More Examples

#### Working with private repositories
```bash
# Clone and work on a private repo
cbox ~/projects -- chat "Clone and analyze https://github.com/myorg/private-repo"
```

#### Switching between multiple projects
```bash
cbox ~/project-a  # Work on project A
cbox ~/project-b  # Switch to project B (separate container instance)
```

#### Using in CI/CD pipelines
```yaml
# Example GitHub Action
- name: Run Claude Code Analysis
  run: |
    eval $(ssh-agent -s)
    ssh-add - <<< "${{ secrets.SSH_PRIVATE_KEY }}"
    ./cbox . -- chat "Review code for security issues"
```

#### Debugging container issues
```bash
# Enable verbose mode to see Docker commands
CBOX_VERBOSE=1 cbox

# Open a shell in the container instead of Claude
cbox --shell

# Check Docker build logs
docker build -t cbox:latest -f ~/.cache/cbox/Dockerfile ~/.cache/cbox

# Manual container inspection
docker run -it --entrypoint /bin/bash cbox:latest
```

## Configuration

### Configuration File (.cbox.json)

cbox supports an optional JSON configuration file for customizing container behavior. The configuration is loaded from (in order of precedence):

1. `./.cbox.json` (project-specific)
2. `~/.cbox.json` (user-specific)
3. `${XDG_CONFIG_HOME}/cbox/config.json` (XDG standard location)

**Example configuration:**

```json
{
  "dockerImage": "cbox:latest",
  "dockerBuildArgs": [
    "HTTP_PROXY=http://proxy.example.com:8080"
  ],
  "volumes": [
    "/host/data:/container/data:rw"
  ],
  "environment": [
    "CUSTOM_VAR=value",
    "DEBUG_LEVEL=info"
  ],
  "network": "bridge",
  "telemetry": false,
  "securityMode": "standard",
  "autoUpdate": true
}
```

**Configuration options:**

| Option | Description | Default | Values |
|--------|-------------|---------|--------|
| `dockerImage` | Docker image to use | `cbox:latest` | Any valid image name |
| `dockerBuildArgs` | Additional build arguments | `[]` | Array of `KEY=value` strings |
| `volumes` | Additional volume mounts | `[]` | Array of `host:container:mode` |
| `environment` | Additional environment variables | `[]` | Array of `KEY=value` strings |
| `network` | Docker network mode | `bridge` | `host`, `bridge`, `none`, or custom |
| `telemetry` | Enable telemetry (not yet implemented) | `false` | `true`, `false` |
| `securityMode` | Security level | `standard` | `standard`, `restricted`, `paranoid` |
| `autoUpdate` | Auto-update Docker image | `true` | `true`, `false` |

**Security modes:**
- `standard`: Default security, allows network access and SSH agent
- `restricted`: Limited network access, SSH agent allowed
- `paranoid`: No network access, no SSH agent, read-only volumes

Copy the example configuration from `.cbox.json.example` to get started:
```bash
cp .cbox.json.example .cbox.json
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CBOX_REBUILD` | Force rebuild of Docker image (set to 1) | 0 |
| `CBOX_VERBOSE` | Enable verbose debug output (set to 1) | 0 |
| `XDG_CACHE_HOME` | Override cache directory location | ~/.cache |
| `XDG_CONFIG_HOME` | Override config directory location | ~/.config |
| `XDG_DATA_HOME` | Override data directory location | ~/.local/share |
| `TERM` | Terminal type passed to container | xterm-256color |
| `SSH_AUTH_SOCK` | SSH agent socket path | (required) |

## How it works

```
Host System                    Docker Container
-----------                    ----------------
Working Dir      ─────mount────>  /work
SSH Agent        ─────socket───>  /ssh-agent  
~/.claude        ─────mount────>  /home/host/.claude
~/.claude.json   ─────mount────>  /home/host/.claude.json
~/.gitconfig     ─────mount────>  /home/host/.gitconfig (read-only)
~/.ssh/known_hosts ───mount────>  /home/host/.ssh/known_hosts (read-only)
```

1. **First run**: Builds a minimal Docker image with Node.js and Claude Code CLI
2. **Mounts volumes**: Maps host directories and configurations into the container
3. **User mapping**: Uses gosu to ensure files created in container have proper host ownership
4. **Runs Claude**: Launches `claude --dangerously-skip-permissions` in the container

## Authentication

cbox automatically uses your host Claude authentication:
- If you've already logged into Claude on your host machine, cbox will use that authentication
- Your authentication is stored in `~/.claude.json` on the host
- To authenticate on the host first, run `claude login` outside of cbox
- All your custom agents from `~/.claude/agents/` are also available in the sandbox

## Network Configuration

- **Full network access**: Container runs with default Docker bridge network
- **Internet connectivity**: Can make outbound connections to any host
- **Host access**: Can reach host services via `host.docker.internal`
- **SSH forwarding**: Uses forwarded agent from host for Git operations
- **No egress filtering**: No firewall restrictions on outbound connections

## File Permissions

- **Ownership preservation**: Files created in container maintain your host user ownership
- **UID/GID mapping**: Uses gosu for proper user ID and group ID mapping
- **No root files**: No root-owned files will be created in your project
- **Mount permissions**: Sensitive files like Git config mounted as read-only
- **Working directory**: Full read/write access to mounted project directory

## Security notes

- `--dangerously-skip-permissions` gives Claude broad access within the container
- The container has full network access (no firewall)
- Your `~/.claude` directory (including auth tokens) is mounted
- Only use on trusted repositories and projects

## Maintenance

### Updating cbox

```bash
# Pull latest version
git pull origin main

# Or re-run installation script
curl -fsSL https://raw.githubusercontent.com/bradleydwyer/cbox/main/install.sh | bash
```

### Updating Claude Code CLI

```bash
# Force rebuild to get latest Claude version
CBOX_REBUILD=1 cbox
```

## Telemetry (Planned Feature)

**Note:** Telemetry is a planned feature that is not yet implemented in the current version of cbox. The telemetry-related command-line options are documented but non-functional.

### Planned Telemetry Features

When implemented, cbox will include optional telemetry to help improve the tool. The planned implementation will:

- Be **disabled by default** and require explicit opt-in
- Collect only anonymous usage data locally
- Never transmit data to external servers
- Respect user privacy as the top priority

### Planned Data Collection

The telemetry system, when implemented, is designed to collect:

- Session start/end times and duration
- Command types executed (sanitized, no sensitive data)
- Error events and performance metrics
- Basic environment information (no PII)

**Privacy guarantees (when implemented):**
- No personally identifiable information (PII) will be collected
- No command arguments or file contents will be logged
- All data will stay local on your machine
- No data will be transmitted to external servers

### Future Telemetry Commands

The following commands are planned but not yet functional:

```bash
# These commands are documented but not yet implemented:
cbox --telemetry-status   # Will check telemetry status
cbox --telemetry-enable   # Will enable telemetry (opt-in)
cbox --telemetry-disable  # Will disable telemetry
cbox --telemetry-clear    # Will clear all collected data
```

### Planned Data Storage Location

When implemented, telemetry data will be stored locally in:
- **Config**: `~/.config/cbox/telemetry.conf`
- **Data**: `~/.local/share/cbox/telemetry/`

### Cleaning up / Uninstalling

```bash
# Remove the cbox script
sudo rm /usr/local/bin/cbox

# Remove Docker image
docker rmi cbox:latest

# Clean cache directory
rm -rf ~/.cache/cbox

# Clean telemetry data (optional)
rm -rf ~/.local/share/cbox ~/.config/cbox

# Remove any stopped containers
docker container prune
```

## Troubleshooting

### SSH agent not detected
```bash
# Start SSH agent
eval $(ssh-agent -s)

# Add your key
ssh-add ~/.ssh/id_rsa

# Verify it's loaded
ssh-add -l
```

### Docker not found
Install Docker Desktop from https://www.docker.com/products/docker-desktop/

### Permission denied
Make sure the script is executable:
```bash
chmod +x cbox
```

## FAQ

### Why use cbox vs direct Claude installation?

- **Isolation**: Keeps Claude Code and its operations separate from your host system
- **Consistency**: Same environment across different machines and team members
- **Easy cleanup**: Simply remove the Docker container when done
- **Security**: Contains Claude's file system access to the container

### Can I use multiple cbox instances simultaneously?

Yes! Each cbox invocation runs in its own container. You can work on multiple projects in parallel:
```bash
# Terminal 1
cbox ~/project-a

# Terminal 2  
cbox ~/project-b
```

### How do I share cbox environments with my team?

1. Commit the `cbox` script to your repository
2. Team members run the installation steps
3. Everyone gets the same containerized environment

### Can I customize the Docker image?

Yes, you can modify the Dockerfile creation in the script. Look for the heredoc section starting around line 22. Future versions will support custom Dockerfiles via configuration.

### Why does first run take longer?

The first run builds the Docker image, which includes:
- Downloading base Node.js image
- Installing Claude Code CLI
- Setting up the container environment

Subsequent runs use the cached image and start instantly.

### How do I use cbox with VS Code or other IDEs?

You can use cbox alongside your IDE - just run cbox in the terminal while editing in your IDE. The mounted volumes ensure both see the same files.

### What if Docker build fails?

Try:
1. Check Docker is running: `docker version`
2. Clear Docker cache: `docker system prune`
3. Rebuild from scratch: `CBOX_REBUILD=1 CBOX_VERBOSE=1 cbox`
4. Check build logs: `docker build -t cbox:latest -f ~/.cache/cbox/Dockerfile ~/.cache/cbox`

## Performance Considerations

- **First run**: Takes 30-60 seconds to build Docker image
- **Subsequent runs**: Start in under 2 seconds using cached image
- **Large directories**: May have slightly slower I/O due to volume mounting
- **Memory usage**: Container typically uses 200-500MB RAM
- **Network latency**: Minimal overhead for network operations

## Documentation

- [CLI-REFERENCE.md](CLI-REFERENCE.md) - Complete command-line reference
- [CHANGELOG.md](CHANGELOG.md) - Version history and release notes
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [SECURITY_AUDIT.md](SECURITY_AUDIT.md) - Security analysis and recommendations

## License

MIT