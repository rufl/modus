#!/bin/bash
# Pre-commit checks for MODUS Framework
# Run this before committing to catch issues early

set -e

echo "=========================================="
echo "  MODUS Framework Pre-Commit Checks"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

# Check 1: GDScript Formatting
echo "Check 1: GDScript Formatting..."
if gdformat --check --diff game/ tests/ > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Code formatting is correct${NC}"
else
    echo -e "${RED}✗ Code formatting issues detected${NC}"
    echo "  Run: gdformat game/ tests/"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: GDScript Linting
echo ""
echo "Check 2: GDScript Linting..."
if gdlint game/ tests/ > /dev/null 2>&1; then
    echo -e "${GREEN}✓ No linting errors${NC}"
else
    echo -e "${RED}✗ Linting errors detected${NC}"
    echo "  Run: gdlint game/ tests/"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: Trailing Whitespace
echo ""
echo "Check 3: Trailing Whitespace..."
TRAILING_WS=$(find game/ tests/ -name "*.gd" -not -path "*/addons/*" -exec grep -l " $" {} \; | wc -l)
if [ $TRAILING_WS -eq 0 ]; then
    echo -e "${GREEN}✓ No trailing whitespace${NC}"
else
    echo -e "${YELLOW}⚠ Found trailing whitespace in $TRAILING_WS files${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 4: Large Files
echo ""
echo "Check 4: Large Files..."
LARGE_FILES=$(find game/ tests/ -name "*.gd" -not -path "*/addons/*" -exec wc -l {} + | awk '$1 > 500 {print $2}' | wc -l)
if [ $LARGE_FILES -eq 0 ]; then
    echo -e "${GREEN}✓ No excessively large files${NC}"
else
    echo -e "${YELLOW}⚠ Found $LARGE_FILES files over 500 lines${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 5: TODO/FIXME Comments
echo ""
echo "Check 5: TODO/FIXME Comments..."
TODO_COUNT=$(grep -r "TODO\|FIXME" game/ tests/ --include="*.gd" | wc -l)
if [ $TODO_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ No TODO/FIXME comments${NC}"
else
    echo -e "${YELLOW}⚠ Found $TODO_COUNT TODO/FIXME comments${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 6: Print Statements
echo ""
echo "Check 6: Print Statements..."
PRINT_COUNT=$(grep -r "print(" game/ --include="*.gd" | grep -v "# DEBUG" | wc -l)
if [ $PRINT_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ No print statements in game code${NC}"
elif [ $PRINT_COUNT -lt 10 ]; then
    echo -e "${YELLOW}⚠ Found $PRINT_COUNT print statements${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${RED}✗ Found $PRINT_COUNT print statements - use proper logging${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Summary
echo ""
echo "=========================================="
echo "  Summary"
echo "=========================================="
echo -e "Errors: ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}✗ Pre-commit checks failed${NC}"
    echo "Please fix the errors above before committing"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Pre-commit checks passed with warnings${NC}"
    echo "Consider addressing the warnings above"
    exit 0
else
    echo -e "${GREEN}✓ All pre-commit checks passed${NC}"
    exit 0
fi
