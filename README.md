# cbox - Claude Code Sandbox

A simple Docker-based sandbox for running Claude Code with full network access and SSH agent forwarding.

## What is cbox?

`cbox` provides a one-command way to run Claude Code in an isolated Docker container while maintaining:
- Full network access (no egress firewall)
- SSH agent forwarding for GitHub push/pull
- Your Claude agents and authentication from `~/.claude`
- Proper file ownership (no root-owned files)
- Git configuration and SSH known hosts

## Prerequisites

- Docker Desktop installed and running
- SSH agent running with your GitHub key loaded:
  ```bash
  eval $(ssh-agent -s)
  ssh-add ~/.ssh/id_rsa  # or your key path
  ```

## Installation

1. Clone this repository or copy the `cbox` script
2. Make it executable: `chmod +x cbox`
3. Add to your PATH:
   ```bash
   # Option 1: Copy to a directory already in PATH
   sudo cp cbox /usr/local/bin/
   
   # Option 2: Add this directory to PATH
   export PATH="$PATH:/path/to/cbox"
   ```

## Usage

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

## How it works

1. **First run**: Builds a minimal Docker image with Node.js and Claude Code CLI
2. **Mounts volumes**:
   - Your working directory → `/work`
   - SSH agent socket → `/ssh-agent`
   - `~/.claude` → `/home/host/.claude` (includes agents)
   - `~/.claude.json` → `/home/host/.claude.json` (authentication)
   - Git config and SSH known_hosts (read-only)
3. **Runs Claude**: Launches `claude --dangerously-skip-permissions` in the container

## Authentication

cbox automatically uses your host Claude authentication:
- If you've already logged into Claude on your host machine, cbox will use that authentication
- Your authentication is stored in `~/.claude.json` on the host
- To authenticate on the host first, run `claude login` outside of cbox
- All your custom agents from `~/.claude/agents/` are also available in the sandbox

## Security notes

- `--dangerously-skip-permissions` gives Claude broad access within the container
- The container has full network access (no firewall)
- Your `~/.claude` directory (including auth tokens) is mounted
- Only use on trusted repositories and projects

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

## License

MIT