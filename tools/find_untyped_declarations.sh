#!/bin/bash
# Find all untyped variable declarations in production code
# Excludes test files and examples

echo "Scanning for untyped variable declarations..."
echo "=============================================="

# Find untyped var declarations (var x = ... without type annotation)
echo -e "\n=== GAME DIRECTORY ==="
grep -rn "^\s*var [a-z_][a-z0-9_]*\s*=\s*" game/ \
  --include="*.gd" \
  --exclude-dir=examples \
  | grep -v ":\s*" \
  | head -100

echo -e "\n=== SHARED DIRECTORY ==="
grep -rn "^\s*var [a-z_][a-z0-9_]*\s*=\s*" shared/ \
  --include="*.gd" \
  | grep -v ":\s*" \
  | head -50

echo -e "\n=== SCAN COMPLETE ==="
