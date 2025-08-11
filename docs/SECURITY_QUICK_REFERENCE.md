# cbox Security Quick Reference

## Security Modes at a Glance

| Mode | Network | SSH Agent | Read-Only | Use Case |
|------|---------|-----------|-----------|----------|
| **standard** (default) | host | ✅ | ❌ | Trusted development |
| **restricted** | bridge | ✅ | ❌ | General use |
| **paranoid** | none | ❌ | ✅ | Maximum security |

## Common Commands

### Basic Usage
```bash
# Standard mode (default)
cbox ~/project

# Restricted mode
cbox --security-mode restricted ~/project

# Paranoid mode
cbox --security-mode paranoid ~/project
```

### Custom Security Configurations
```bash
# Development with read-only protection
cbox --read-only ~/project

# Isolated network but keep SSH
cbox --network bridge --ssh-agent true ~/project

# No network, no SSH (air-gapped)
cbox --network none --ssh-agent false ~/project

# Maximum lockdown
cbox --security-mode paranoid --read-only ~/sensitive-code
```

### Override Examples
```bash
# Paranoid mode but need network (generates warning)
cbox --security-mode paranoid --network host ~/project

# Restricted mode without SSH agent
cbox --security-mode restricted --ssh-agent false ~/project

# Standard mode with read-only
cbox --read-only ~/production-code
```

## Security Decision Tree

```
Is the code trusted?
├─ NO → Use paranoid mode
│   └─ Need network? → Add --network bridge (with warning)
├─ PARTIALLY → Use restricted mode
│   ├─ Need SSH? → Keep default (true)
│   └─ Sensitive files? → Add --read-only
└─ YES → Use standard mode (default)
    └─ Production code? → Consider --read-only
```

## Warning Messages

### Critical Warnings
- "Security Error: Attempted security bypass detected" - Someone tried to disable security
- "Security error: Path contains dangerous shell characters" - Possible injection attempt

### Security Warnings (Yellow)
- "Network enabled in paranoid mode" - Reducing isolation
- "SSH agent enabled in paranoid mode" - Exposing SSH keys
- "Write access enabled in paranoid mode" - Files can be modified
- "Host network with write access" - Maximum exposure

### Configuration Warnings
- "SSH agent enabled but network disabled" - SSH won't work without network

## Quick Security Checklist

Before running cbox, ask yourself:

1. **Do I trust this code?**
   - No → Use `--security-mode paranoid`
   - Maybe → Use `--security-mode restricted`
   - Yes → Use default

2. **Does it need network access?**
   - No → Add `--network none`
   - Only outbound → Use `--network bridge`
   - Full access → Use `--network host` (default)

3. **Does it need my SSH keys?**
   - No → Add `--ssh-agent false`
   - Yes → Keep default

4. **Should it modify files?**
   - No → Add `--read-only`
   - Yes → Keep default

## Environment Variables

```bash
# Enable verbose mode to see security configuration
CBOX_VERBOSE=1 cbox ~/project

# Set resource limits
CBOX_MEMORY=2g CBOX_CPUS=1 cbox ~/project
```

## Testing Your Security Configuration

```bash
# Verify mode settings (dry run)
CBOX_VERBOSE=1 cbox --security-mode paranoid --verify

# Check what would be applied
CBOX_VERBOSE=1 cbox --network none --ssh-agent false --verify
```

## Emergency Commands

```bash
# Maximum security for unknown code
cbox --security-mode paranoid ~/unknown-code

# Quick read-only check
cbox --read-only --network none ~/suspicious-file

# Isolated shell for investigation
cbox --security-mode paranoid --shell ~/project
```

---
*Remember: When in doubt, use paranoid mode!*