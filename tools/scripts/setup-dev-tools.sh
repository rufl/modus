#!/bin/bash
# Setup script for MODUS Framework development tools

set -e

echo "Setting up MODUS Framework development tools..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not installed."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "Error: pip3 is required but not installed."
    exit 1
fi

# Install GDScript toolkit
echo "Installing GDScript toolkit..."
pip3 install gdtoolkit

# Install pre-commit
echo "Installing pre-commit..."
pip3 install pre-commit

# Install security tools
echo "Installing security analysis tools..."
pip3 install bandit safety

# Setup pre-commit hooks
echo "Setting up pre-commit hooks..."
pre-commit install

# Verify installations
echo "Verifying installations..."

if command -v gdformat &> /dev/null; then
    echo "✓ gdformat installed successfully"
else
    echo "✗ gdformat installation failed"
fi

if command -v gdlint &> /dev/null; then
    echo "✓ gdlint installed successfully"
else
    echo "✗ gdlint installation failed"
fi

if command -v pre-commit &> /dev/null; then
    echo "✓ pre-commit installed successfully"
else
    echo "✗ pre-commit installation failed"
fi

# Run initial formatting check
echo "Running initial code quality check..."
echo "Checking GDScript formatting..."
gdformat --check --diff game/ tests/ || {
    echo "Code formatting issues found. Run 'gdformat game/ tests/' to fix them."
}

echo "Running GDScript linting..."
gdlint game/ tests/ || {
    echo "Linting issues found. Please review and fix them."
}

echo ""
echo "Development tools setup complete!"
echo ""
echo "Available commands:"
echo "  gdformat game/ tests/                 # Format GDScript files"
echo "  gdlint game/ tests/                   # Lint GDScript files"
echo "  pre-commit run --all-files               # Run all pre-commit hooks"
echo "  bandit -r .                              # Security analysis"
echo ""
echo "Pre-commit hooks are now active and will run automatically on git commit."
