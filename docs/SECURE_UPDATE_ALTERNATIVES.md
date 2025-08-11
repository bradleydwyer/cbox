# Secure Update Alternatives for cbox v1.4.0

## Executive Summary

This document presents secure alternatives to the proposed auto-update system that maintain the strong security model of cbox v1.3.0 while providing user-friendly update mechanisms. All alternatives prioritize security and user control over convenience.

## Design Principles

### Security First
- Maintain immutable runtime environment
- Preserve security mode boundaries
- No persistent writable npm directories
- User-controlled update process

### Defense in Depth
- Multiple verification layers
- Secure communication channels
- Integrity checking
- Audit trails

### Fail Secure
- Updates disabled in paranoid mode
- Graceful degradation on errors
- No automatic installations
- Clear user consent required

## Recommended Approaches

### Approach 1: Notification-Only Updates (RECOMMENDED)

#### Implementation
```bash
#!/usr/bin/env bash
# Secure update notification system

check_for_updates() {
  local current_version="$1"
  local security_mode="$2"
  
  # Respect security modes
  case "$security_mode" in
    paranoid)
      # No update checks in paranoid mode
      return 0
      ;;
    restricted)
      # Only check if explicitly requested
      [[ "${CBOX_CHECK_UPDATES:-0}" == "1" ]] || return 0
      ;;
    standard)
      # Check by default but respect opt-out
      [[ "${CBOX_DISABLE_UPDATE_CHECKS:-0}" == "1" ]] && return 0
      ;;
  esac
  
  # Check cached result first
  local cache_file="$HOME/.cache/cbox/update_check"
  local cache_age=86400  # 24 hours
  
  if [[ -f "$cache_file" ]]; then
    local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
    if [[ $file_age -lt $cache_age ]]; then
      [[ -s "$cache_file" ]] && cat "$cache_file"
      return 0
    fi
  fi
  
  # Secure API call with timeout and validation
  local latest_version
  if latest_version=$(timeout 5s curl -s \
    -H "Accept: application/vnd.github.v3+json" \
    -H "User-Agent: cbox/$current_version" \
    --max-redirs 3 \
    --connect-timeout 3 \
    "https://api.github.com/repos/bradleydwyer/cbox/releases/latest" 2>/dev/null |
    jq -r '.tag_name // empty' 2>/dev/null |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null); then
    
    # Validate version format and compare
    if [[ -n "$latest_version" && "$latest_version" != "v$current_version" ]]; then
      local update_message="Update available: cbox $latest_version (current: v$current_version)
To update:
  cd /path/to/cbox
  git pull origin main
  CBOX_REBUILD=1 cbox --verify"
      
      # Cache the result
      mkdir -p "$(dirname "$cache_file")"
      echo "$update_message" > "$cache_file"
      echo "$update_message"
    else
      # Cache "no update" result
      echo "" > "$cache_file"
    fi
  else
    # Failed to check - don't show error in normal operation
    [[ "${CBOX_VERBOSE:-0}" == "1" ]] && echo "cbox: Update check failed" >&2
    return 1
  fi
}
```

#### Security Properties
- ✅ No code modification capability
- ✅ Respects security mode boundaries
- ✅ Fails silently (no disruption)
- ✅ User controls all updates
- ✅ Clear audit trail
- ✅ No persistent attack surface

#### Integration
```bash
# In main cbox script
if [[ "$VERIFY_MODE" == "0" && "$SHELL_MODE" == "0" ]]; then
  check_for_updates "$VERSION" "$SECURITY_MODE" || true
fi
```

### Approach 2: Staged Update System (BALANCED)

#### Implementation
```bash
#!/usr/bin/env bash
# Staged update system with verification

download_update() {
  local version="$1"
  local download_dir="$HOME/.cache/cbox/updates"
  local version_file="$download_dir/$version/VERSION"
  local signature_file="$download_dir/$version/VERSION.sig"
  
  # Validate version format
  if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format: $version" >&2
    return 1
  fi
  
  mkdir -p "$download_dir/$version"
  
  # Download release archive
  echo "Downloading cbox $version..."
  if ! curl -sL \
    -o "$download_dir/$version/cbox.tar.gz" \
    "https://github.com/bradleydwyer/cbox/archive/refs/tags/$version.tar.gz"; then
    echo "Failed to download release" >&2
    return 1
  fi
  
  # Download signature (if available)
  curl -sL \
    -o "$signature_file" \
    "https://github.com/bradleydwyer/cbox/releases/download/$version/cbox-$version.tar.gz.sig" || true
  
  echo "Downloaded to: $download_dir/$version/"
  echo "Next: cbox --verify-update $version"
}

verify_update() {
  local version="$1"
  local download_dir="$HOME/.cache/cbox/updates/$version"
  
  if [[ ! -d "$download_dir" ]]; then
    echo "Update not found: $version" >&2
    echo "Run: cbox --download-update $version" >&2
    return 1
  fi
  
  # Verify file integrity
  echo "Verifying update integrity..."
  
  # Check GPG signature if available
  if [[ -f "$download_dir/VERSION.sig" ]]; then
    if command -v gpg >/dev/null 2>&1; then
      if ! gpg --verify "$download_dir/VERSION.sig" "$download_dir/VERSION" 2>/dev/null; then
        echo "GPG signature verification failed" >&2
        return 1
      fi
      echo "✅ GPG signature valid"
    else
      echo "⚠️  GPG not available for signature verification"
    fi
  fi
  
  # Verify archive integrity
  if ! tar -tzf "$download_dir/cbox.tar.gz" >/dev/null 2>&1; then
    echo "Archive integrity check failed" >&2
    return 1
  fi
  echo "✅ Archive integrity verified"
  
  # Show changelog if available
  if [[ -f "$download_dir/CHANGELOG.md" ]]; then
    echo "Changelog for $version:"
    head -20 "$download_dir/CHANGELOG.md"
  fi
  
  echo "Update verified. Run: cbox --apply-update $version"
}

apply_update() {
  local version="$1"
  local download_dir="$HOME/.cache/cbox/updates/$version"
  
  if [[ ! -f "$download_dir/cbox.tar.gz" ]]; then
    echo "Update not downloaded or verified" >&2
    return 1
  fi
  
  echo "Applying update $version..."
  
  # Create backup of current installation
  local backup_dir="$HOME/.cache/cbox/backup/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_dir"
  
  # Extract to temporary location
  local temp_dir=$(mktemp -d)
  if ! tar -xzf "$download_dir/cbox.tar.gz" -C "$temp_dir"; then
    echo "Failed to extract update" >&2
    rm -rf "$temp_dir"
    return 1
  fi
  
  # Rebuild container with new version
  CBOX_REBUILD=1 "$temp_dir"/cbox*/cbox --verify
  
  echo "Update applied successfully"
  echo "Backup available at: $backup_dir"
  
  # Cleanup
  rm -rf "$temp_dir"
}
```

#### CLI Integration
```bash
# Add to argument parsing
--check-updates)
  check_for_updates "$VERSION" "$SECURITY_MODE"
  exit 0
  ;;
--download-update)
  shift
  download_update "$1"
  exit 0
  ;;
--verify-update)
  shift
  verify_update "$1"
  exit 0
  ;;
--apply-update)
  shift
  apply_update "$1"
  exit 0
  ;;
```

### Approach 3: Container Registry Updates (MODERN)

#### Implementation
Use GitHub Container Registry for pre-built, signed images:

```dockerfile
# Multi-stage build with security scanning
FROM node:20-bookworm-slim as builder

# Install dependencies and Claude Code
RUN npm i -g @anthropic-ai/claude-code@latest

FROM gcr.io/distroless/nodejs:20
# Copy from builder stage
COPY --from=builder /usr/local/lib/node_modules/@anthropic-ai/claude-code /app
# Add security labels
LABEL org.opencontainers.image.source=https://github.com/bradleydwyer/cbox
LABEL org.opencontainers.image.description="Claude Code in secure container"
LABEL org.opencontainers.image.version=${VERSION}
```

#### Update Process
```bash
update_from_registry() {
  local version="$1"
  local image="ghcr.io/bradleydwyer/cbox:$version"
  
  echo "Pulling $image..."
  
  # Pull with digest verification
  if ! docker pull "$image"; then
    echo "Failed to pull image" >&2
    return 1
  fi
  
  # Verify image signature (if available)
  if command -v cosign >/dev/null 2>&1; then
    if ! cosign verify "$image" --key cosign.pub; then
      echo "Image signature verification failed" >&2
      return 1
    fi
    echo "✅ Image signature verified"
  fi
  
  # Update local image tag
  docker tag "$image" cbox:latest
  
  echo "Update complete: $version"
}
```

## Security Comparison Matrix

| Feature | Notification Only | Staged Updates | Registry Updates |
|---------|------------------|----------------|------------------|
| Security | ✅ Excellent | ⚠️ Good | ✅ Excellent |
| User Control | ✅ Full | ✅ Full | ⚠️ Limited |
| Automation | ❌ Manual | ⚠️ Semi-auto | ✅ Automated |
| Integrity Checks | N/A | ✅ Yes | ✅ Yes |
| Rollback | ✅ Git-based | ✅ Backup | ⚠️ Tag-based |
| Network Dependency | ✅ Optional | ⚠️ Required | ⚠️ Required |
| Complexity | ✅ Simple | ⚠️ Medium | ❌ High |
| Supply Chain Risk | ✅ None | ⚠️ Low | ⚠️ Medium |

## Implementation Recommendations

### Phase 1: Notification Only (Immediate)
- Add update check function to existing cbox script
- Respect security mode boundaries
- Cache results to avoid API abuse
- No automatic actions

### Phase 2: Enhanced Notifications (v1.4.1)
- Add changelog display
- Show security advisories
- Provide direct update commands
- Add opt-out mechanism

### Phase 3: Registry Integration (v1.5.0)
- Set up GitHub Container Registry
- Implement automated builds
- Add image signing with Cosign
- Provide registry-based updates

## Configuration Options

### Environment Variables
```bash
# Disable all update checks
export CBOX_DISABLE_UPDATE_CHECKS=1

# Enable checks in restricted mode
export CBOX_CHECK_UPDATES=1

# Set custom update check interval (seconds)
export CBOX_UPDATE_CHECK_INTERVAL=86400

# Set custom registry
export CBOX_REGISTRY="ghcr.io/myorg/cbox"
```

### User Configuration
```json
// ~/.cbox/config.json
{
  "updates": {
    "enabled": true,
    "check_interval": 86400,
    "auto_check": false,
    "registry": "ghcr.io/bradleydwyer/cbox"
  },
  "security": {
    "require_signatures": true,
    "allow_downgrade": false
  }
}
```

## Testing Strategy

### Unit Tests
```bash
#!/usr/bin/env bash
# Test update functionality

test_update_check_security_modes() {
  # Test paranoid mode blocks checks
  SECURITY_MODE="paranoid" check_for_updates "1.3.0" paranoid
  assert_empty_output
  
  # Test restricted mode requires opt-in
  CBOX_CHECK_UPDATES=0 check_for_updates "1.3.0" restricted
  assert_empty_output
  
  CBOX_CHECK_UPDATES=1 check_for_updates "1.3.0" restricted
  assert_contains_output "Update available"
}

test_version_validation() {
  # Test invalid version formats
  download_update "invalid-version"
  assert_error
  
  download_update "v1.4.0'; rm -rf /"
  assert_error
  
  # Test valid version format
  download_update "v1.4.0"
  assert_success
}
```

### Security Tests
```bash
test_no_code_execution() {
  # Ensure no code can be executed during update checks
  local malicious_response='{"tag_name": "v1.0.0$(rm -rf /)"}'
  
  # Mock API response
  mock_github_api "$malicious_response"
  
  # Run update check
  check_for_updates "1.3.0" standard
  
  # Verify no command execution occurred
  assert_file_exists "/tmp/test-file"  # Should still exist
}
```

## Monitoring and Metrics

### Update Metrics (Non-PII)
- Update check frequency
- Success/failure rates
- Version adoption rates
- Error categories

### Security Metrics
- Signature verification rates
- Failed verification attempts
- Downgrade attempts
- Security mode distribution

## Incident Response

### Update-Related Security Issues

1. **Compromised Update**
   ```bash
   # Immediate response
   export CBOX_DISABLE_UPDATE_CHECKS=1
   
   # Verify current installation
   cbox --verify
   
   # Check for indicators of compromise
   find ~/.cache/cbox -name "*.log" -exec grep -l "error\|fail" {} \;
   ```

2. **Supply Chain Attack**
   ```bash
   # Block all updates
   echo "127.0.0.1 api.github.com" >> /etc/hosts
   
   # Rebuild from clean source
   git clean -fdx
   git pull
   CBOX_REBUILD=1 cbox --verify
   ```

## Migration Path

### From Current v1.3.0
1. Add notification function to existing script
2. Test with feature flag: `CBOX_ENABLE_UPDATE_CHECKS=1`
3. Gradual rollout with monitoring
4. Full deployment after validation

### Backward Compatibility
- All update features are opt-in
- No behavior changes for existing users
- Environment variables for control
- Graceful degradation on errors

## Conclusion

The notification-only approach provides the best balance of security and functionality. It maintains the strong security model of v1.3.0 while providing users with helpful update information. More advanced approaches can be added in future versions once the basic security model is proven.

**Priority Order**:
1. **Notification Only** - Implement immediately
2. **Staged Updates** - Consider for v1.4.x
3. **Registry Updates** - Long-term goal for v1.5.0

All approaches maintain the core principle: **User control over all code execution and modifications**.

---

*Document Date: 2025-08-11*
*Status: Design Proposal*
*Next Review: Implementation Phase*