#!/usr/bin/env python3
"""
GUT Framework Integration Validation Script
Validates GUT integration without requiring Godot to be running
"""

import os
import json
import re
import sys
from pathlib import Path

def validate_gut_config():
    """Validate .gutconfig.json exists and has correct structure"""
    print("=== Validating GUT Configuration ===")
    
    config_path = Path(".gutconfig.json")
    if not config_path.exists():
        print("❌ .gutconfig.json not found")
        return False
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        required_keys = ["dirs", "prefix", "suffix", "include_subdirs"]
        for key in required_keys:
            if key not in config:
                print(f"❌ Missing required config key: {key}")
                return False
        
        # Validate specific values
        if config["prefix"] != "test_":
            print(f"❌ Incorrect test prefix: {config['prefix']} (expected: test_)")
            return False
        
        if config["suffix"] != ".gd":
            print(f"❌ Incorrect test suffix: {config['suffix']} (expected: .gd)")
            return False
        
        if config["include_subdirs"] is not True:
            print("❌ GUT must include nested test directories")
            return False
        
        print("✅ GUT configuration is valid")
        return True
        
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON in .gutconfig.json: {e}")
        return False

def validate_test_structure():
    """Validate test directory structure and naming conventions"""
    print("\n=== Validating Test Structure ===")
    
    tests_dir = Path("tests")
    if not tests_dir.exists():
        print("❌ tests/ directory not found")
        return False
    
    config = json.loads(Path(".gutconfig.json").read_text(encoding="utf-8"))
    configured_dirs = [
        Path(str(directory).removeprefix("res://")) for directory in config["dirs"]
    ]
    test_files = sorted(
        path
        for directory in configured_dirs
        for path in directory.rglob("test_*.gd")
    )
    if not test_files:
        print("❌ No test files found matching test_*.gd pattern")
        return False
    
    print(f"✅ Found {len(test_files)} test files")
    
    # Validate each test file
    valid_files = 0
    for test_file in test_files:
        if validate_test_file(test_file):
            valid_files += 1
    
    print(f"✅ {valid_files}/{len(test_files)} test files are valid")
    return valid_files == len(test_files)

def validate_test_file(test_file_path):
    """Validate individual test file structure"""
    print(f"  Checking {test_file_path.name}...")
    
    try:
        with open(test_file_path, 'r') as f:
            content = f.read()
        
        # Check for proper extends clause
        accepted_bases = (
            "GutTest",
            "ModusGutTestBase",
            "GutCompatibleBase",
            "PropertyBasedTesting",
            "Node",
            "Node3D",
            "RefCounted",
        )
        extends_match = re.search(r"(?m)^extends\s+([A-Za-z0-9_]+)", content)
        if not extends_match or extends_match.group(1) not in accepted_bases:
            print(f"    ❌ {test_file_path.name}: Missing proper extends clause")
            return False
        
        # Check for test methods
        test_methods = re.findall(r'func\s+(test_\w+)', content)
        if not test_methods and not re.search(r"(?m)^func\s+_(ready|init)\(", content):
            print(f"    ❌ {test_file_path.name}: No test methods found")
            return False
        
        if test_methods:
            print(f"    ✅ {test_file_path.name}: {len(test_methods)} test methods found")
        else:
            print(f"    ✅ {test_file_path.name}: scene-driven test entry point found")
        return True
        
    except Exception as e:
        print(f"    ❌ {test_file_path.name}: Error reading file: {e}")
        return False

def validate_gut_integration_test():
    """Validate the maintained GUT base and headless runner wiring."""
    print("\n=== Validating GUT Integration ===")

    required_markers = {
        Path("tests/modus_gut_test_base.gd"): (
            'extends "res://addons/gut/test.gd"',
            "class_name ModusGutTestBase",
        ),
        Path("tests/runners/run_gut_tests_headless.gd"): (
            "extends SceneTree",
            'load("res://addons/gut/gut.gd")',
            '_gut.add_directory("res://tests/unit/"',
            '_gut.add_directory("res://tests/integration/"',
            '_gut.add_directory("res://tests/property/"',
        ),
    }
    for path, markers in required_markers.items():
        if not path.is_file():
            print(f"❌ Maintained GUT integration file missing: {path}")
            return False
        content = path.read_text(encoding="utf-8")
        missing = [marker for marker in markers if marker not in content]
        if missing:
            print(f"❌ {path} is missing integration markers: {missing}")
            return False

    print("✅ Maintained GUT base and headless runner are wired")
    return True

def validate_ci_cd_pipeline():
    """Validate CI/CD pipeline configuration"""
    print("\n=== Validating CI/CD Pipeline ===")
    
    # Check GitHub Actions workflow
    workflow_path = Path(".github/workflows/ci.yml")
    if not workflow_path.exists():
        print("❌ CI workflow not found")
        return False
    
    try:
        with open(workflow_path, 'r') as f:
            workflow_content = f.read()
        
        # Check for required jobs
        required_jobs = ["code-quality", "test", "build", "security-scan"]
        for job in required_jobs:
            if f"{job}:" not in workflow_content:
                print(f"❌ Missing required job: {job}")
                return False
        
        # Check for GUT test execution
        if "run_unit_tests_only.gd" not in workflow_content:
            print("❌ Unit test execution not found in workflow")
            return False
        
        if "run_benchmark_tests_only.gd" not in workflow_content:
            print("❌ Benchmark test execution not found in workflow")
            return False
        
        print("✅ CI/CD pipeline configuration is valid")
        return True
        
    except Exception as e:
        print(f"❌ Error reading CI workflow: {e}")
        return False

def validate_code_quality_setup():
    """Validate code quality automation setup"""
    print("\n=== Validating Code Quality Setup ===")
    
    # Check for required files
    required_files = [
        ".pre-commit-config.yaml",
        ".editorconfig",
        ".gdlintrc",
        "tools/scripts/setup-dev-tools.sh"
    ]
    
    all_valid = True
    for file_path in required_files:
        if not Path(file_path).exists():
            print(f"❌ Missing required file: {file_path}")
            all_valid = False
        else:
            print(f"✅ Found: {file_path}")
    
    # Check code quality workflow
    quality_workflow = Path(".github/workflows/code-quality.yml")
    if not quality_workflow.exists():
        print("❌ Code quality workflow not found")
        all_valid = False
    else:
        print("✅ Code quality workflow found")
    
    return all_valid

def main():
    """Main validation function"""
    print("GUT Framework Integration Validation")
    print("=" * 50)
    
    validations = [
        ("GUT Configuration", validate_gut_config),
        ("Test Structure", validate_test_structure),
        ("GUT Integration Test", validate_gut_integration_test),
        ("CI/CD Pipeline", validate_ci_cd_pipeline),
        ("Code Quality Setup", validate_code_quality_setup)
    ]
    
    results = []
    for name, validator in validations:
        try:
            result = validator()
            results.append((name, result))
        except Exception as e:
            print(f"❌ {name}: Validation failed with error: {e}")
            results.append((name, False))
    
    # Summary
    print("\n" + "=" * 50)
    print("VALIDATION SUMMARY")
    print("=" * 50)
    
    passed = 0
    total = len(results)
    
    for name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{name}: {status}")
        if result:
            passed += 1
    
    print(f"\nOverall: {passed}/{total} validations passed")
    
    if passed == total:
        print("\n🎉 All GUT framework integration validations PASSED!")
        print("The CI/CD pipeline and testing infrastructure is properly configured.")
        return 0
    else:
        print(f"\n⚠️  {total - passed} validation(s) failed.")
        print("Please review the errors above and fix the issues.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
