#!/bin/bash
# Power plugin tests

export HAMR_TEST_MODE=1
source "$(dirname "$0")/../test-helpers.sh"

TEST_NAME="Power Plugin Tests"
HANDLER="$(dirname "$0")/handler.py"

# ============================================================================
# Tests
# ============================================================================

test_index_returns_items() {
    local result=$(hamr_test index)
    assert_type "$result" "index"
    local count=$(json_get "$result" '.items | length')
    assert_eq "$count" "9"
}

test_index_item_has_power_id() {
    local result=$(hamr_test index)
    local id=$(json_get "$result" '.items[0].id')
    assert_eq "$id" "shutdown"
}

test_index_item_has_entrypoint() {
    local result=$(hamr_test index)
    local step=$(json_get "$result" '.items[0].entryPoint.step')
    assert_eq "$step" "action"
}

test_initial_returns_results() {
    local result=$(hamr_test initial)
    assert_type "$result" "results"
}

test_initial_has_placeholder() {
    local result=$(hamr_test initial)
    assert_json "$result" '.placeholder' "Search power actions..."
}

test_initial_has_all_actions() {
    local result=$(hamr_test initial)
    assert_has_result "$result" "shutdown"
    assert_has_result "$result" "restart"
    assert_has_result "$result" "suspend"
    assert_has_result "$result" "lock"
    assert_has_result "$result" "logout"
    assert_has_result "$result" "reload-hyprland"
    assert_has_result "$result" "reload-niri"
    assert_has_result "$result" "reload-hamr"
}

test_search_filters() {
    local result=$(hamr_test search --query "shut")
    assert_type "$result" "results"
    assert_has_result "$result" "shutdown"
    assert_no_result "$result" "restart"
}

test_search_no_match() {
    local result=$(hamr_test search --query "nonexistent12345")
    assert_type "$result" "results"
    assert_has_result "$result" "__empty__"
}

test_action_executes() {
    local result=$(hamr_test action --id "shutdown")
    assert_type "$result" "execute"
    assert_closes "$result"
}

test_action_empty_closes() {
    local result=$(hamr_test action --id "__empty__")
    assert_closes "$result"
}

# ============================================================================
# Run
# ============================================================================

run_tests \
    test_index_returns_items \
    test_index_item_has_power_id \
    test_index_item_has_entrypoint \
    test_initial_returns_results \
    test_initial_has_placeholder \
    test_initial_has_all_actions \
    test_search_filters \
    test_search_no_match \
    test_action_executes \
    test_action_empty_closes
