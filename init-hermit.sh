#!/bin/bash
# Initialize Hermit for the cbox project
# This script properly sets up Hermit with trusted signatures

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Initializing Hermit for cbox project..."
echo "Project directory: $PROJECT_DIR"

# Check if hermit is already installed globally
if command -v hermit &> /dev/null; then
    echo "Found global hermit installation"
    HERMIT_CMD="hermit"
else
    echo "Installing Hermit..."
    # Download and install Hermit if not present
    curl -fsSL https://github.com/cashapp/hermit/releases/download/stable/install.sh | bash
    
    # Try to find hermit in common locations
    if [ -x "$HOME/bin/hermit" ]; then
        HERMIT_CMD="$HOME/bin/hermit"
    elif [ -x "$HOME/.local/bin/hermit" ]; then
        HERMIT_CMD="$HOME/.local/bin/hermit"
    else
        echo "Error: Could not find hermit after installation"
        echo "Please install hermit manually: https://cashapp.github.io/hermit/usage/get-started/"
        exit 1
    fi
fi

echo "Using hermit at: $HERMIT_CMD"

# Initialize Hermit in the project directory
echo "Initializing Hermit environment..."
$HERMIT_CMD init "$PROJECT_DIR"

echo ""
echo "✅ Hermit initialized successfully!"
echo ""
echo "The bin/hermit file has been updated with a trusted signature."
echo "You can now use Hermit-managed tools:"
echo ""
echo "  cd $PROJECT_DIR"
echo "  source bin/activate-hermit"
echo "  gitleaks version"
echo "  pre-commit --version"
echo ""
echo "Or use tools directly:"
echo "  ./bin/gitleaks version"
echo "  ./bin/pre-commit --version"