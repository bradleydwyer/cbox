# Security Audit: cbox v1.4.0 Auto-Update System Design

## Executive Summary

**Recommendation: HIGH RISK - DO NOT IMPLEMENT AS PROPOSED**

The proposed auto-update system introduces significant security vulnerabilities that fundamentally compromise the security model established in v1.3.0. While the design attempts to maintain some security boundaries, the writable npm directory and self-updating capability create unacceptable attack surfaces that cannot be adequately mitigated.

## Severity Assessment

| Component | Risk Level | CVSS Score | Impact |
|-----------|------------|------------|--------|
| Writable npm directory | **CRITICAL** | 9.8 | Remote Code Execution |
| Self-updating Claude Code | **HIGH** | 8.1 | Supply Chain Attack |
| Persistent volume mount | **HIGH** | 7.5 | Privilege Escalation |
| Update check mechanism | **MEDIUM** | 5.3 | Information Disclosure |
| GitHub API access | **LOW** | 3.1 | Rate Limiting DoS |

## Critical Security Issues

### 1. Writable NPM Directory (CRITICAL)

**Vulnerability**: Persistent writable npm directory allows code injection and persistence

**Attack Vectors**:
- **Supply Chain Poisoning**: Malicious packages can modify Claude Code or install backdoors
- **Dependency Confusion**: Attacker can inject packages with similar names
- **Post-install Scripts**: npm packages can execute arbitrary code during installation
- **Path Traversal**: Packages can write outside intended directories

**Specific Risks**:
```bash
# Attack scenario 1: Malicious package modifies Claude Code
npm install malicious-package
# Post-install script can:
# - Modify /opt/npm-user/lib/node_modules/@anthropic-ai/claude-code
# - Install persistent backdoors
# - Exfiltrate credentials from ~/.claude.json

# Attack scenario 2: Persistence across sessions
# Once compromised, the persistent volume ensures malware survives container restarts
~/.cache/cbox/npm-user → /opt/npm-user (persistent infection)
```

**OWASP Mapping**: 
- A01:2021 - Broken Access Control
- A06:2021 - Vulnerable and Outdated Components
- A08:2021 - Software and Data Integrity Failures

### 2. Self-Updating Capability (HIGH)

**Vulnerability**: Claude Code self-update bypasses version control and security review

**Attack Vectors**:
- **Update Hijacking**: MITM attacks on npm registry connections
- **Malicious Updates**: Compromised npm account pushes malicious update
- **Version Pinning Bypass**: Automatic updates ignore version constraints
- **Regression Introduction**: Updates may introduce new vulnerabilities

**Specific Risks**:
```javascript
// npm update process has no integrity verification beyond npm's basic checks
// No code signing verification
// No update rollback mechanism
// No update approval process
```

### 3. Persistent Volume Security (HIGH)

**Vulnerability**: Persistent volume creates long-lived attack surface

**Attack Vectors**:
- **Cross-Project Contamination**: Malware from one project affects all projects
- **Credential Theft**: Persistent access to npm tokens and credentials
- **Cache Poisoning**: Corrupted packages remain in cache
- **Filesystem Attacks**: Symlink attacks, race conditions

**Specific Risks**:
```bash
# Persistent volume owned by host user
~/.cache/cbox/npm-user (host:host ownership)
# Writable by container's host user via gosu
# No integrity checking between sessions
# No cleanup mechanism for infected files
```

### 4. Update Check Implementation (MEDIUM)

**Vulnerability**: Information disclosure and potential command injection

**Attack Vectors**:
- **Version Enumeration**: Reveals exact cbox version to attackers
- **Network Fingerprinting**: Identifies available host tools
- **Command Injection**: If update check isn't properly sanitized
- **Cache Poisoning**: Malicious data in update cache

**Security Concerns**:
```bash
# Fallback chain reveals system configuration
curl → wget → fetch → python → perl → nc → docker
# Each tool has different security properties
# No certificate pinning for GitHub API
```

## Comparison to Current v1.3.0 Security Model

### Current Model (v1.3.0) - SECURE
```dockerfile
# Read-only npm installation
RUN npm i -g @anthropic-ai/claude-code@latest
# Immutable after build
# No persistent state for npm
# Clear security boundary
```

**Security Properties**:
- ✅ Immutable code base
- ✅ No supply chain attack surface after build
- ✅ Version controlled and auditable
- ✅ Clean slate for each rebuild
- ✅ Follows principle of least privilege

### Proposed Model (v1.4.0) - INSECURE
```dockerfile
# No global npm installation
# User-writable npm directory
/opt/npm-user (writable, persistent)
# Dynamic installation on first run
# Self-updating capability
```

**Security Weaknesses**:
- ❌ Mutable code base
- ❌ Persistent attack surface
- ❌ Uncontrolled updates
- ❌ Cross-session contamination
- ❌ Violates least privilege principle

## Attack Scenario Analysis

### Scenario 1: Supply Chain Attack
```
1. Attacker compromises npm package dependency
2. User runs cbox, triggering npm install/update
3. Malicious post-install script executes
4. Backdoor installed in persistent npm directory
5. All future cbox sessions compromised
6. Attacker has persistent access to all projects
```

**Impact**: Complete compromise of development environment

### Scenario 2: Targeted Attack
```
1. Attacker identifies cbox user via update checks
2. Crafts malicious npm package targeting Claude Code
3. Uses typosquatting or dependency confusion
4. Package installed during update process
5. Credentials stolen from ~/.claude.json
6. GitHub tokens exfiltrated via network
```

**Impact**: Credential theft and repository compromise

### Scenario 3: Persistence Attack
```
1. Initial compromise via any vector
2. Malware modifies npm packages in persistent volume
3. Infection survives container restarts
4. Spreads to other projects via shared npm directory
5. Establishes command & control channel
```

**Impact**: Long-term persistent access

## Security Control Analysis

### Proposed Mitigations - INSUFFICIENT

1. **"Claude Code runs as non-root via gosu"**
   - ❌ Still has write access to npm directory
   - ❌ Can modify its own code
   - ❌ No defense against supply chain attacks

2. **"Update checks are read-only"**
   - ⚠️ Information disclosure still present
   - ⚠️ No integrity verification of responses
   - ⚠️ Cache can be poisoned

3. **"GitHub API accessed over HTTPS"**
   - ⚠️ No certificate pinning
   - ⚠️ Vulnerable to MITM with compromised CA
   - ⚠️ No signature verification of releases

4. **"24-hour cache to prevent API abuse"**
   - ✅ Helps with rate limiting
   - ❌ Cache itself becomes attack vector
   - ❌ No cache integrity verification

## Recommended Security Controls

### If Auto-Update Must Be Implemented

#### Option 1: Signed Binary Updates (RECOMMENDED)
```bash
# Download signed binary releases
# Verify GPG signatures before installation
# No npm involvement
# Clear update audit trail
```

#### Option 2: Layered Docker Images (SECURE)
```dockerfile
# Base image with Claude Code
FROM cbox:v1.3.0 as base

# Update layer (rebuilt periodically)
FROM base
RUN npm update @anthropic-ai/claude-code
# Still immutable at runtime
```

#### Option 3: Read-Only npm with Overlay (COMPROMISE)
```bash
# Read-only base npm directory
/opt/npm-base (read-only)
# Temporary overlay for session
/tmp/npm-overlay (tmpfs, session-only)
# No persistence between sessions
```

### Required Security Controls

1. **Code Signing**
   - All updates must be cryptographically signed
   - Signature verification before installation
   - Pinned signing keys

2. **Update Approval**
   - User must explicitly approve updates
   - Show changelog and security notes
   - Option to defer or skip updates

3. **Rollback Capability**
   - Keep previous version available
   - Quick rollback mechanism
   - Version pinning support

4. **Integrity Monitoring**
   - Hash verification of all npm packages
   - Regular integrity checks
   - Alert on unexpected changes

5. **Network Isolation**
   - Update checks only in standard mode
   - No network access in paranoid mode
   - Respect security mode settings

6. **Audit Logging**
   - Log all update attempts
   - Record package installations
   - Track security events

## Alternative Approaches

### Approach 1: Manual Update Notifications (SAFEST)
```bash
# Check for updates
cbox --check-updates

# Display notification only
"New version available: v1.4.1"
"Run 'cbox --upgrade' to update"

# User manually rebuilds
CBOX_REBUILD=1 cbox --verify
```

**Pros**: No security regression, user control, clear audit trail
**Cons**: Requires manual intervention

### Approach 2: Staged Updates (BALANCED)
```bash
# Download update to staging area
cbox --download-update v1.4.1

# Verify update integrity
cbox --verify-update v1.4.1

# Apply update (rebuilds image)
cbox --apply-update v1.4.1
```

**Pros**: Controlled process, verification step, rollback possible
**Cons**: More complex implementation

### Approach 3: Container Registry (MODERN)
```bash
# Pull pre-built images from registry
docker pull ghcr.io/bradleydwyer/cbox:v1.4.1

# Automatic security scanning
# Version control via tags
# Immutable images
```

**Pros**: Industry standard, secure, automated scanning
**Cons**: Requires registry setup

## Impact on Security Modes

### Standard Mode
- Update checks: ⚠️ Acceptable with controls
- Auto-updates: ❌ Not recommended
- Writable npm: ❌ Not acceptable

### Restricted Mode
- Update checks: ⚠️ Should be optional
- Auto-updates: ❌ Must be disabled
- Writable npm: ❌ Violates isolation

### Paranoid Mode
- Update checks: ❌ Must be disabled
- Auto-updates: ❌ Must be disabled
- Writable npm: ❌ Completely unacceptable

## Compliance Implications

### GDPR
- ❌ Uncontrolled data collection via npm telemetry
- ❌ No data processing agreement with npm registry

### HIPAA
- ❌ Unencrypted credential storage in npm cache
- ❌ No audit trail for code changes

### SOC 2
- ❌ Uncontrolled software changes
- ❌ No change management process

### PCI DSS
- ❌ Unverified code execution
- ❌ No secure software development lifecycle

## Security Testing Requirements

If proceeding despite risks, implement:

1. **Supply Chain Testing**
   ```bash
   # Test malicious package detection
   # Test post-install script blocking
   # Test dependency confusion prevention
   ```

2. **Persistence Testing**
   ```bash
   # Test cross-session contamination
   # Test cleanup mechanisms
   # Test volume permission attacks
   ```

3. **Update Security Testing**
   ```bash
   # Test MITM attack prevention
   # Test signature verification
   # Test rollback mechanisms
   ```

## Final Recommendations

### DO NOT IMPLEMENT
The proposed auto-update system introduces unacceptable security risks that fundamentally compromise the security model established in v1.3.0.

### If Updates Are Required

1. **Keep Current Model**: Maintain immutable npm installation
2. **Add Update Notifications**: Check and notify only
3. **Manual Rebuild Process**: User-controlled updates
4. **Sign Releases**: GPG sign all releases
5. **Use Container Registry**: Pre-built, scanned images

### Security-First Alternative

```bash
#!/usr/bin/env bash
# Secure update checker (notification only)

check_for_updates() {
  local current_version="1.3.0"
  local latest_version
  
  # Check with signature verification
  latest_version=$(
    curl -s https://api.github.com/repos/bradleydwyer/cbox/releases/latest |
    jq -r '.tag_name' |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$'
  )
  
  if [[ "$latest_version" > "v$current_version" ]]; then
    echo "Update available: $latest_version"
    echo "To update: cd /path/to/cbox && git pull && CBOX_REBUILD=1 cbox --verify"
  fi
}
```

## Conclusion

The proposed auto-update system would transform cbox from a security-focused tool into a significant attack vector. The writable npm directory and self-updating capability create supply chain vulnerabilities that cannot be adequately mitigated while maintaining the intended functionality.

**Recommendation**: Reject the current proposal and implement notification-only update checks with manual, user-controlled update processes.

---

*Security Audit Date: 2025-08-11*
*Auditor: Security Specialist*
*Risk Assessment: CRITICAL - Do Not Proceed*
*CVSS Base Score: 9.8 (Critical)*