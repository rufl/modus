#!/bin/bash
# Setup CI/CD Environment for Local Testing
# This script helps developers set up their local environment to match CI/CD pipeline

set -e

echo "=========================================="
echo "  MODUS Framework CI/CD Environment Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running in project root
if [ ! -f "project.godot" ]; then
    echo -e "${RED}Error: Must run from project root directory${NC}"
    exit 1
fi

echo "Step 1: Checking Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓ Python found: $PYTHON_VERSION${NC}"
else
    echo -e "${RED}✗ Python 3 not found. Please install Python 3.11+${NC}"
    exit 1
fi

echo ""
echo "Step 2: Installing GDScript Toolkit..."
if pip3 install --upgrade gdtoolkit; then
    echo -e "${GREEN}✓ GDScript Toolkit installed${NC}"
    gdformat --version
    gdlint --version
else
    echo -e "${RED}✗ Failed to install GDScript Toolkit${NC}"
    exit 1
fi

echo ""
echo "Step 3: Installing security analysis tools..."
if pip3 install --upgrade bandit safety; then
    echo -e "${GREEN}✓ Security tools installed${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Failed to install security tools (optional)${NC}"
fi

echo ""
echo "Step 4: Checking Godot installation..."
if command -v godot &> /dev/null; then
    GODOT_VERSION=$(godot --version 2>&1 | head -1)
    echo -e "${GREEN}✓ Godot found: $GODOT_VERSION${NC}"
elif command -v godot4 &> /dev/null; then
    GODOT_VERSION=$(godot4 --version 2>&1 | head -1)
    echo -e "${GREEN}✓ Godot found: $GODOT_VERSION${NC}"
    echo -e "${YELLOW}⚠ Note: Using 'godot4' command${NC}"
else
    echo -e "${YELLOW}⚠ Godot not found in PATH${NC}"
    echo "  Please ensure Godot 4.7+ is installed and accessible"
    echo "  You can create an alias: alias godot=/path/to/godot"
fi

echo ""
echo "Step 5: Verifying project structure..."
REQUIRED_DIRS=("game" "tests" "tests/runners" "tests/utilities" ".github/workflows")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ $dir exists${NC}"
    else
        echo -e "${RED}✗ $dir missing${NC}"
    fi
done

echo ""
echo "Step 6: Checking configuration files..."
REQUIRED_FILES=(".gdlintrc" ".github/workflows/ci.yml" ".github/workflows/code-quality.yml")
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $file exists${NC}"
    else
        echo -e "${RED}✗ $file missing${NC}"
    fi
done

echo ""
echo "Step 7: Creating test results directory..."
mkdir -p test-results
echo -e "${GREEN}✓ test-results directory created${NC}"

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "You can now run local CI/CD checks:"
echo ""
echo "  # Format check"
echo "  gdformat --check --diff game/ tests/"
echo ""
echo "  # Auto-format"
echo "  gdformat game/ tests/"
echo ""
echo "  # Linting"
echo "  gdlint game/ tests/"
echo ""
echo "  # Run tests (requires Godot)"
echo "  godot --headless -s tests/runners/run_gut_tests.gd -gexit"
echo ""
echo "  # Generate coverage report"
echo "  godot --headless -s tests/utilities/generate_coverage_report.gd"
echo ""
echo "  # Security scan (Python files)"
echo "  bandit -r . -ll"
echo ""
echo "For more information, see docs/CI_CD_PIPELINE.md"
echo ""
