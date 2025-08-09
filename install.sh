#!/usr/bin/env bash
# cbox installation script
set -euo pipefail

VERSION="1.1.0"
INSTALL_DIR="/usr/local/bin"
REPO_URL="https://raw.githubusercontent.com/yourusername/cbox/main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Check if running as root
check_root() {
  if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root"
    echo "Please run as a regular user. The script will use sudo when needed."
    exit 1
  fi
}

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
  else
    OS="unknown"
  fi
  info "Detected OS: $OS"
}

# Check prerequisites
check_prerequisites() {
  local missing_deps=()
  
  # Check for Docker
  if ! command -v docker &> /dev/null; then
    missing_deps+=("docker")
    warn "Docker is not installed"
    echo "  Install Docker Desktop from: https://docs.docker.com/get-docker/"
  else
    info "Docker found: $(docker --version)"
    
    # Check if Docker daemon is running
    if ! docker version &> /dev/null; then
      warn "Docker daemon is not running"
      echo "  Please start Docker Desktop or run: sudo systemctl start docker"
    else
      info "Docker daemon is running"
    fi
  fi
  
  # Check for curl or wget
  if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    missing_deps+=("curl or wget")
    error "Neither curl nor wget is available"
  fi
  
  # Check for sudo (for installation)
  if ! command -v sudo &> /dev/null; then
    warn "sudo not found - you may need to install manually"
  fi
  
  # Check SSH agent (optional)
  if [[ -n "${SSH_AUTH_SOCK:-}" ]] && [[ -S "${SSH_AUTH_SOCK:-}" ]]; then
    info "SSH agent detected"
  else
    warn "SSH agent not running (optional, but recommended for Git operations)"
    echo "  To start: eval \$(ssh-agent -s) && ssh-add ~/.ssh/id_rsa"
  fi
  
  # Check Claude authentication (optional)
  if [[ -f "$HOME/.claude.json" ]]; then
    info "Claude authentication found"
  else
    warn "Claude authentication not found"
    echo "  After installation, run 'claude login' to authenticate"
  fi
  
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    error "Missing required dependencies: ${missing_deps[*]}"
    echo "Please install the missing dependencies and try again."
    exit 1
  fi
}

# Download cbox script
download_cbox() {
  local temp_file="/tmp/cbox.$$"
  
  info "Downloading cbox script..."
  
  if command -v curl &> /dev/null; then
    curl -fsSL "$REPO_URL/cbox" -o "$temp_file" || {
      error "Failed to download cbox script"
      exit 1
    }
  elif command -v wget &> /dev/null; then
    wget -qO "$temp_file" "$REPO_URL/cbox" || {
      error "Failed to download cbox script"
      exit 1
    }
  fi
  
  # Verify download
  if [[ ! -s "$temp_file" ]]; then
    error "Downloaded file is empty"
    exit 1
  fi
  
  # Make executable
  chmod +x "$temp_file"
  
  echo "$temp_file"
}

# Install cbox
install_cbox() {
  local script_path="$1"
  local target_path="$INSTALL_DIR/cbox"
  
  info "Installing cbox to $target_path..."
  
  # Check if target directory exists
  if [[ ! -d "$INSTALL_DIR" ]]; then
    error "Installation directory $INSTALL_DIR does not exist"
    exit 1
  fi
  
  # Install with sudo if needed
  if [[ -w "$INSTALL_DIR" ]]; then
    cp "$script_path" "$target_path"
  else
    info "Requesting sudo access to install to $INSTALL_DIR"
    sudo cp "$script_path" "$target_path"
    sudo chmod 755 "$target_path"
  fi
  
  # Verify installation
  if [[ -x "$target_path" ]]; then
    info "Successfully installed cbox"
  else
    error "Installation failed"
    exit 1
  fi
}

# Setup shell integration
setup_shell() {
  local shell_rc=""
  local shell_name=""
  
  # Detect user's shell
  if [[ -n "${SHELL:-}" ]]; then
    case "$SHELL" in
      *bash)
        shell_rc="$HOME/.bashrc"
        shell_name="bash"
        ;;
      *zsh)
        shell_rc="$HOME/.zshrc"
        shell_name="zsh"
        ;;
      *fish)
        shell_rc="$HOME/.config/fish/config.fish"
        shell_name="fish"
        ;;
      *)
        warn "Unknown shell: $SHELL"
        return
        ;;
    esac
  fi
  
  # Check if /usr/local/bin is in PATH
  if echo "$PATH" | grep -q "/usr/local/bin"; then
    info "/usr/local/bin is already in PATH"
  else
    warn "/usr/local/bin is not in PATH"
    
    if [[ -n "$shell_rc" ]] && [[ -f "$shell_rc" ]]; then
      echo ""
      echo "Would you like to add /usr/local/bin to your PATH? (y/n)"
      read -r response
      
      if [[ "$response" =~ ^[Yy]$ ]]; then
        echo 'export PATH="/usr/local/bin:$PATH"' >> "$shell_rc"
        info "Added /usr/local/bin to PATH in $shell_rc"
        echo "Please run: source $shell_rc"
      fi
    fi
  fi
}

# Build Docker image
build_docker_image() {
  info "Building Docker image (this may take a minute on first run)..."
  
  if CBOX_REBUILD=1 cbox --verify &> /dev/null; then
    info "Docker image built successfully"
  else
    warn "Could not verify Docker image build"
    echo "You can build it manually later by running: CBOX_REBUILD=1 cbox"
  fi
}

# Main installation flow
main() {
  echo "========================================="
  echo "     cbox Installation Script v$VERSION"
  echo "========================================="
  echo ""
  
  check_root
  detect_os
  check_prerequisites
  
  # Download script
  temp_script=$(download_cbox)
  
  # Install
  install_cbox "$temp_script"
  
  # Cleanup temp file
  rm -f "$temp_script"
  
  # Setup shell
  setup_shell
  
  # Verify installation
  echo ""
  info "Running installation verification..."
  if cbox --verify; then
    echo ""
    echo "========================================="
    echo -e "${GREEN}✓ cbox installed successfully!${NC}"
    echo "========================================="
    echo ""
    echo "Quick start:"
    echo "  cbox --help          # Show help"
    echo "  cbox                 # Run in current directory"
    echo "  cbox ~/my-project    # Run in specific directory"
    echo ""
    
    # Try to build Docker image
    echo "Would you like to build the Docker image now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      build_docker_image
    else
      echo "You can build it later by running: CBOX_REBUILD=1 cbox"
    fi
  else
    error "Installation verification failed"
    echo "Please check the error messages above and try again."
    exit 1
  fi
}

# Run main function
main "$@"