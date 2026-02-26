#!/bin/bash

# Complete integration test suite
# Runs both success and failure detection tests

set -euo pipefail

cd "$(dirname "$0")/../.."

echo "========================================="
echo "WP3 Validation Workflow Test Suite"
echo "========================================="

total_tests=0
passed_tests=0

# Test 1: Normal validation (should pass)
echo
echo "Test 1: Normal Validation (Expected: All Pass)"
echo "-----------------------------------------------"
total_tests=$((total_tests + 1))
if ./.tests/integration/run_test.sh; then
    echo "✓ Test 1 PASSED: Normal validation works correctly"
    passed_tests=$((passed_tests + 1))
else
    echo "✗ Test 1 FAILED: Normal validation failed unexpectedly"
fi

# Test 2: Failure detection (should detect failures)  
echo
echo "Test 2: Failure Detection (Expected: Some Failures Detected)"
echo "------------------------------------------------------------"
total_tests=$((total_tests + 1))
if ./.tests/integration/test_failures.sh; then
    echo "✓ Test 2 PASSED: Failure detection works correctly"
    passed_tests=$((passed_tests + 1))
else
    echo "✗ Test 2 FAILED: Failure detection not working properly"
fi

# Summary
echo
echo "========================================="
echo "Test Suite Summary"
echo "========================================="
echo "Total tests: $total_tests"
echo "Passed: $passed_tests"
echo "Failed: $((total_tests - passed_tests))"

if [ $passed_tests -eq $total_tests ]; then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi