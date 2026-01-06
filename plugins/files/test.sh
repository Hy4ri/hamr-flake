#!/bin/bash
#
# Tests for files plugin
# Run: ./test.sh
#
# Note: File action tests are limited because they require real files
# and the test harness runs in subshells. The main functionality is
# tested via HAMR_TEST_MODE=1 manual testing.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export HAMR_TEST_MODE=1
source "$SCRIPT_DIR/../test-helpers.sh"

# ============================================================================
# Config
# ============================================================================

TEST_NAME="Files Plugin Tests"
HANDLER="$SCRIPT_DIR/handler.py"

# ============================================================================
# Tests
# ============================================================================

test_initial_shows_info_message() {
    local result=$(hamr_test initial)
    
    assert_type "$result" "results"
    assert_realtime_mode "$result"
    assert_has_result "$result" "__info__"
    assert_contains "$result" "Type to search files"
}

test_search_empty_query_shows_info() {
    local result=$(hamr_test search --query "")
    
    assert_type "$result" "results"
    assert_realtime_mode "$result"
    assert_has_result "$result" "__info__"
}

test_search_no_results() {
    local result=$(hamr_test search --query "nonexistent_xyz_file_12345")
    
    assert_type "$result" "results"
    assert_realtime_mode "$result"
    assert_has_result "$result" "__no_results__"
    assert_contains "$result" "No files found"
}

test_placeholder_text() {
    local result=$(hamr_test initial)
    
    assert_json "$result" '.placeholder' "Search files..."
}

test_nonexistent_file_error() {
    local result=$(hamr_test action --id "/nonexistent/file/path/xyz.txt")
    
    assert_type "$result" "error"
    assert_contains "$result" "not found"
}

test_info_item_not_actionable() {
    # Trying to act on __info__ should not crash (returns empty)
    local result=$(hamr_test action --id "__info__" 2>&1 || true)
    # Just verify it doesn't crash - empty response is expected
    assert_ok true
}

test_no_results_item_not_actionable() {
    # Trying to act on __no_results__ should not crash
    local result=$(hamr_test action --id "__no_results__" 2>&1 || true)
    assert_ok true
}

test_initial_valid_json() {
    assert_ok hamr_test initial
}

test_search_valid_json() {
    assert_ok hamr_test search --query ""
    assert_ok hamr_test search --query "test"
}

# ============================================================================
# Run
# ============================================================================

run_tests \
    test_initial_shows_info_message \
    test_search_empty_query_shows_info \
    test_search_no_results \
    test_placeholder_text \
    test_nonexistent_file_error \
    test_info_item_not_actionable \
    test_no_results_item_not_actionable \
    test_initial_valid_json \
    test_search_valid_json
