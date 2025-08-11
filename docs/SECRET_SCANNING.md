# Secret Scanning Setup Guide

This project uses automated secret scanning to prevent accidental commits of sensitive information like API keys, passwords, and tokens.

## Tools Used

- **Gitleaks v8.18.1**: Fast secret detection in git repositories (Hermit-managed)
- **TruffleHog v2.2.1**: Comprehensive scanning with regex patterns (Hermit-managed via pip)
- **Pre-commit Framework v4.2.0**: Automated git hook management (Hermit-managed)
- **Python3 v3.12.8**: Required for TruffleHog and pre-commit (Hermit-managed)

## Installation

### Option 1: Using Hermit Package Manager (Recommended)

This project uses [Hermit](https://github.com/cashapp/hermit) to manage secret scanning tools for consistent versions across all environments.

**Benefits of Hermit:**
- ✅ **Consistent tool versions** across Linux, macOS, and CI environments
- ✅ **No system dependencies** - tools are isolated and portable
- ✅ **Easy setup** - no need to install tools system-wide
- ✅ **Version pinning** - ensures reproducible builds and scans
- ✅ **Project-local tools** - each project can have different tool versions

**Quick Setup:**
```bash
# Tools are already configured in this project
# Simply activate the Hermit environment
source bin/activate-hermit

# Verify tools are available
./bin/gitleaks version
./bin/pre-commit --version
./bin/trufflehog --help
```

**For New Projects:**
1. **Install Hermit**:
   ```bash
   curl -fsSL https://github.com/cashapp/hermit/releases/download/stable/install.sh | bash
   ```

2. **Initialize Hermit in your project**:
   ```bash
   hermit init
   ```

3. **Install secret scanning tools**:
   ```bash
   hermit install gitleaks@8.18.1 pre-commit@4.2.0 python3@3.12.3
   ```

### Option 2: Manual Installation

1. **Install pre-commit framework**:
   ```bash
   # Using pip (Python)
   pip install pre-commit
   
   # Using Homebrew (macOS)
   brew install pre-commit
   
   # Using apt (Ubuntu/Debian)
   apt install pre-commit
   ```

2. **Install Gitleaks**:
   ```bash
   # Using Homebrew (macOS)
   brew install gitleaks
   
   # Using Docker
   docker pull zricethezav/gitleaks:latest
   
   # Download binary (Linux/macOS)
   wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.1/gitleaks_8.18.1_linux_x64.tar.gz
   tar -xzf gitleaks_8.18.1_linux_x64.tar.gz
   sudo mv gitleaks /usr/local/bin/
   ```

3. **Install TruffleHog**:
   ```bash
   # Using pip
   pip install truffleHog
   
   # Using Homebrew (macOS)
   brew install trufflehog
   
   # Using Docker
   docker pull trufflesecurity/trufflehog:latest
   ```

### Setup Pre-commit Hooks

#### Using Hermit (Recommended)
```bash
# Install the git hooks using Hermit-managed pre-commit
./bin/pre-commit install

# Verify installation
./bin/pre-commit --version

# Run manually on all files (optional first-time check)
./bin/pre-commit run --all-files
```

#### Manual Installation
After installing the prerequisites manually, run:

```bash
# Install the git hooks
pre-commit install

# Verify installation
pre-commit --version

# Run manually on all files (optional first-time check)
pre-commit run --all-files
```

## How It Works

When you run `git commit`, the pre-commit hooks will automatically:

1. **Gitleaks** scans staged files for:
   - Hardcoded passwords
   - API keys (AWS, Azure, GCP, GitHub, etc.)
   - Private keys and certificates
   - Generic secrets based on entropy

2. **TruffleHog** performs deeper scanning:
   - Verifies credentials against actual APIs
   - Checks only changes since last commit
   - Reports only verified (working) credentials
   - Prevents commit if active secrets are found

## Configuration Files

- `.pre-commit-config.yaml`: Defines which hooks to run
- `.gitleaks.toml`: Custom rules and allowlists for Gitleaks

## Manual Scanning

### Scan entire repository history

#### Using Hermit-managed tools
```bash
# Using Hermit-managed Gitleaks
./bin/gitleaks detect --source . --verbose

# Using Hermit-managed TruffleHog
./bin/trufflehog --regex --entropy=False --json .
```

#### Using system-installed tools
```bash
# Using Gitleaks
gitleaks detect --source . --verbose

# Using TruffleHog (Note: different syntax for newer versions)
trufflehog git file://. --only-verified
```

### Scan specific files
```bash
# Using Hermit-managed Gitleaks
./bin/gitleaks detect --source . --verbose --staged

# Using Hermit-managed TruffleHog on current directory
./bin/trufflehog --regex --json .
```

## Bypassing Hooks (Use Carefully!)

If you need to bypass the hooks temporarily (NOT RECOMMENDED):

```bash
# Skip all hooks for this commit
git commit --no-verify -m "commit message"

# Or using shorthand
git commit -n -m "commit message"
```

⚠️ **WARNING**: Only bypass hooks if you're absolutely certain no secrets are being committed.

## Troubleshooting

### "command not found" errors

Ensure the tools are installed and in your PATH:
```bash
which gitleaks
which trufflehog
which pre-commit
```

### False positives

If legitimate code is being flagged:

1. **For Gitleaks**: Add patterns to `.gitleaks.toml` allowlist
2. **For specific lines**: Add `# gitleaks:allow` comment
3. **For TruffleHog**: Use `--only-verified` flag (already configured)

### Hooks not running

```bash
# Reinstall hooks
pre-commit uninstall
pre-commit install

# Check git hooks directory
ls -la .git/hooks/
```

### Performance issues

For large repositories, you can:
```bash
# Skip TruffleHog verification temporarily
SKIP=trufflehog git commit -m "message"

# Run only on staged files
pre-commit run --files $(git diff --staged --name-only)
```

## CI/CD Integration

To add secret scanning to your CI/CD pipeline:

### GitHub Actions
```yaml
- name: Run Gitleaks
  uses: gitleaks/gitleaks-action@v2
  with:
    config: .gitleaks.toml
```

### GitLab CI
```yaml
secret_scanning:
  stage: test
  script:
    - pre-commit run --all-files
```

## Best Practices

1. **Never commit secrets**, even temporarily
2. **Use environment variables** for sensitive data
3. **Rotate any exposed credentials** immediately
4. **Review scan results** before bypassing
5. **Keep scanning tools updated** regularly

## Additional Resources

- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [TruffleHog Documentation](https://github.com/trufflesecurity/trufflehog)
- [Pre-commit Framework](https://pre-commit.com/)
- [OWASP Secret Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)