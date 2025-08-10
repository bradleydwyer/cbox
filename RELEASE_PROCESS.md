# Release Process for cbox

This document outlines the complete process for cutting a new release of cbox, including all files that need to be updated and the proper sequence of operations.

## Overview

cbox uses semantic versioning (MAJOR.MINOR.PATCH) and requires updates to multiple files and systems when cutting a release.

## Pre-Release Checklist

- [ ] Ensure all intended changes are merged to `main`
- [ ] Verify Docker environment works locally
- [ ] Run any available tests/linting (if Docker is available)
- [ ] Review recent commits to determine appropriate version bump

## Files That Must Be Updated

### 1. Version Numbers
These files contain hardcoded version numbers that must be updated:

| File | Location | Example |
|------|----------|---------|
| `cbox` | Line ~5 | `VERSION="1.1.3"` |
| `install.sh` | Line ~5 | `VERSION="1.1.3"` |
| `README.md` | Line ~3 | `[![Version](https://img.shields.io/badge/version-1.1.3-blue.svg)]` |

### 2. Changelog
- `CHANGELOG.md` - Add new version section with changes and update version links

### 3. Checksums
- `SHA256SUMS` - Must be regenerated after version updates

## Step-by-Step Release Process

### Step 1: Update Version Numbers
```bash
# Update version in main script
sed -i 's/VERSION="[^"]*"/VERSION="X.Y.Z"/' cbox

# Update version in install script  
sed -i 's/VERSION="[^"]*"/VERSION="X.Y.Z"/' install.sh

# Update README badge
sed -i 's/version-[^-]*-blue/version-X.Y.Z-blue/' README.md
```

### Step 2: Update Changelog
Add new version section to `CHANGELOG.md`:
```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed  
- Modified features

### Fixed
- Bug fixes

### Removed
- Deprecated features
```

Update version links at bottom:
```markdown
[Unreleased]: https://github.com/bradleydwyer/cbox/compare/vX.Y.Z...HEAD
[X.Y.Z]: https://github.com/bradleydwyer/cbox/compare/vX.Y.Z-1...vX.Y.Z
```

### Step 3: Regenerate Checksums
```bash
# Generate new checksums for all release files
sha256sum cbox cbox-update install.sh verify-install.sh > SHA256SUMS
```

### Step 4: Commit and Tag
```bash
# Stage all changes
git add cbox install.sh README.md CHANGELOG.md SHA256SUMS

# Commit with standard message format
git commit -m "Release version X.Y.Z

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Create annotated tag
git tag -a vX.Y.Z -m "Release version X.Y.Z"
```

### Step 5: Push to Remote
```bash
# Push commit and tag
git push origin main
git push origin vX.Y.Z
```

## Post-Release Verification

### Verify Install Script Works
```bash
# Test the install script with new checksums
curl -fsSL https://raw.githubusercontent.com/bradleydwyer/cbox/main/install.sh | bash
```

### Verify Version Commands
```bash
# Check version is updated
cbox --version
```

## Common Issues and Solutions

### Checksum Verification Failures
**Problem**: Install script fails with "Checksum verification failed"
**Cause**: SHA256SUMS file contains outdated checksums
**Solution**: Regenerate checksums and create new patch release

### Version Mismatch After Release
**Problem**: Different files show different versions
**Cause**: Missed updating a version number somewhere
**Solution**: Create patch release with corrected versions

### Install Script Version Lags Behind
**Problem**: Install script shows old version even after release
**Cause**: Forgot to update VERSION in install.sh
**Solution**: Update install.sh version and create new patch release

## Files Modified During Release

The following files are modified during a typical release:

### Always Modified
- `cbox` - Version number
- `install.sh` - Version number  
- `README.md` - Version badge
- `CHANGELOG.md` - New release section and links
- `SHA256SUMS` - Updated checksums

### Sometimes Modified
- `verify-install.sh` - If verification logic changes
- `cbox-update` - If update mechanism changes
- Documentation files - If features change

## Automation Notes

### Current Manual Process
All release steps are currently manual. Future improvements could include:

1. **Release script** - Automate version updates and checksum generation
2. **GitHub Actions** - Automate release creation and asset uploads
3. **Version validation** - Ensure all files have consistent versions

### Checksum Dependencies
The `SHA256SUMS` file is critical for security. It must be updated whenever ANY of the following files change:
- `cbox`
- `cbox-update` 
- `install.sh`
- `verify-install.sh`

## Version Numbering Guidelines

### Semantic Versioning Rules
- **MAJOR.MINOR.PATCH** format
- **MAJOR**: Breaking changes or major feature additions
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, security updates, documentation

### Examples
- `1.1.3` → `1.1.4`: Bug fix or minor update
- `1.1.3` → `1.2.0`: New feature addition
- `1.1.3` → `2.0.0`: Breaking change or major rewrite

## Emergency Patch Process

If a critical issue is found after release:

1. **Identify the issue** - Security, functionality, or install problems
2. **Create hotfix branch** (optional) - For complex fixes
3. **Make minimal fix** - Only change what's necessary
4. **Follow normal release process** - With PATCH version increment
5. **Test thoroughly** - Especially install script functionality

## Security Considerations

### Checksum Integrity
- SHA256SUMS provides tamper detection for downloads
- Must be updated whenever any release file changes
- Users rely on this for security verification

### Release Timing
- Don't rush releases - checksum mismatches break user installs
- Test install script before pushing tags
- Consider time zones for release announcements

## Future Improvements

### Planned Automation
1. Release script that updates all version numbers
2. Automated checksum generation and validation
3. GitHub Actions for release creation
4. Automated testing of install process

### Version Management  
1. Single source of truth for version number
2. Build-time version injection
3. Runtime version consistency checks

---

**Remember**: Always test the install script after creating a release to ensure checksums are correct!