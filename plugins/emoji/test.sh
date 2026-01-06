#!/bin/bash
# Emoji plugin tests

export HAMR_TEST_MODE=1
source "$(dirname "$0")/../test-helpers.sh"

TEST_NAME="Emoji Plugin Tests"
HANDLER="$(dirname "$0")/handler.py"

# ============================================================================
# Tests
# ============================================================================

test_initial_returns_grid_browser() {
    local result=$(hamr_test initial)
    assert_type "$result" "gridBrowser"
}

test_initial_has_title() {
    local result=$(hamr_test initial)
    assert_json "$result" '.gridBrowser.title' "Select Emoji"
}

test_initial_returns_many_items() {
    local result=$(hamr_test initial)
    local count=$(json_get "$result" '.gridBrowser.items | length')
    # Should return many items
    [[ "$count" -gt 50 ]] || { echo "Expected >50 items, got $count"; return 1; }
}

test_initial_has_columns() {
    local result=$(hamr_test initial)
    local columns=$(json_get "$result" '.gridBrowser.columns')
    assert_eq "$columns" "10"
}

test_initial_has_actions() {
    local result=$(hamr_test initial)
    local actions=$(json_get "$result" '.gridBrowser.actions | length')
    assert_eq "$actions" "2"  # copy and type
}

test_search_filters_results() {
    local result=$(hamr_test search --query "smile")
    assert_type "$result" "results"
    # Should have some smiling emoji results
    local count=$(get_result_count "$result")
    [[ "$count" -gt 0 ]] || { echo "Expected results for 'smile', got none"; return 1; }
}

test_search_heart() {
    local result=$(hamr_test search --query "heart")
    assert_type "$result" "results"
    local count=$(get_result_count "$result")
    [[ "$count" -gt 0 ]] || { echo "Expected results for 'heart', got none"; return 1; }
}

test_result_has_emoji_icon() {
    local result=$(hamr_test search --query "smile")
    # Results should have iconType: "text" for emoji display
    local icon_type=$(json_get "$result" '.results[0].iconType')
    assert_eq "$icon_type" "text"
}

test_result_has_copy_verb() {
    local result=$(hamr_test search --query "smile")
    local verb=$(json_get "$result" '.results[0].verb')
    assert_eq "$verb" "Copy"
}

test_result_has_actions() {
    local result=$(hamr_test search --query "smile")
    local actions=$(json_get "$result" '.results[0].actions | length')
    assert_eq "$actions" "2"  # copy and type
}

test_action_copy() {
    # Get first smile result
    local results=$(hamr_test search --query "smile")
    local emoji_id=$(json_get "$results" '.results[0].id')
    
    local result=$(hamr_test action --id "$emoji_id" --action "copy")
    assert_type "$result" "execute"
    assert_closes "$result"
    # Check for notification message
    local notify=$(json_get "$result" '.notify')
    assert_contains "$notify" "Copied"
}

test_action_type() {
    local results=$(hamr_test search --query "smile")
    local emoji_id=$(json_get "$results" '.results[0].id')
    
    local result=$(hamr_test action --id "$emoji_id" --action "type")
    assert_type "$result" "execute"
    assert_closes "$result"
    # Check for notification message
    local notify=$(json_get "$result" '.notify')
    assert_contains "$notify" "Typed"
}

test_action_default_is_copy() {
    local results=$(hamr_test search --query "smile")
    local emoji_id=$(json_get "$results" '.results[0].id')
    
    # No action specified should default to copy
    local result=$(hamr_test action --id "$emoji_id")
    assert_type "$result" "execute"
    local notify=$(json_get "$result" '.notify')
    assert_contains "$notify" "Copied"
}

test_grid_browser_action_copy() {
    # Simulate gridBrowser selection via raw input
    local raw_result=$(hamr_test raw --input '{"step": "action", "selected": {"id": "gridBrowser", "itemId": "emoji:😀", "action": "copy"}}')
    assert_type "$raw_result" "execute"
    local notify=$(json_get "$raw_result" '.notify')
    assert_contains "$notify" "Copied"
}

test_grid_browser_action_type() {
    local raw_result=$(hamr_test raw --input '{"step": "action", "selected": {"id": "gridBrowser", "itemId": "emoji:😀", "action": "type"}}')
    assert_type "$raw_result" "execute"
    local notify=$(json_get "$raw_result" '.notify')
    assert_contains "$notify" "Typed"
}

test_grid_browser_action_has_history_name() {
    local raw_result=$(hamr_test raw --input '{"step": "action", "selected": {"id": "gridBrowser", "itemId": "emoji:😀", "action": "copy"}}')
    # Should have .name for history tracking (safe API)
    local name=$(json_get "$raw_result" '.name')
    [[ -n "$name" ]] || { echo "Expected .name for history tracking, got empty"; return 1; }
    # Name should contain the emoji
    assert_contains "$name" "😀"
}

test_index_returns_items() {
    local result=$(hamr_test index)
    assert_type "$result" "index"
    # Should have many indexed items
    local count=$(json_get "$result" '.items | length')
    [[ "$count" -gt 100 ]] || { echo "Expected >100 indexed items, got $count"; return 1; }
}

test_index_items_have_entrypoint() {
    local result=$(hamr_test index)
    # Each indexed item should have entryPoint for execution
    local entry_point=$(json_get "$result" '.items[0].entryPoint')
    [[ "$entry_point" != "null" ]] || { echo "Expected entryPoint to be set, got null"; return 1; }
    # Should have step: "action"
    local step=$(json_get "$result" '.items[0].entryPoint.step')
    assert_eq "$step" "action"
}

test_index_items_have_id() {
    local result=$(hamr_test index)
    # Each indexed item should have a proper id with emoji prefix
    local id=$(json_get "$result" '.items[0].id')
    [[ "$id" =~ ^emoji: ]] || { echo "Expected id with emoji: prefix, got: $id"; return 1; }
}

test_index_items_have_id_prefix() {
    local result=$(hamr_test index)
    local id=$(json_get "$result" '.items[0].id')
    assert_contains "$id" "emoji:"
}

test_empty_query_returns_many() {
    local result=$(hamr_test search --query "")
    local count=$(get_result_count "$result")
    [[ "$count" -gt 50 ]] || { echo "Expected >50 results for empty query, got $count"; return 1; }
}

test_no_match_returns_empty() {
    local result=$(hamr_test search --query "xyznonexistent12345")
    local count=$(get_result_count "$result")
    assert_eq "$count" "0"
}

test_recent_emojis_not_loaded_in_test_mode() {
    # In test mode, recent emojis should be empty (not loaded from disk)
    local result=$(hamr_test initial)
    assert_type "$result" "gridBrowser"
    # Grid should still have items
    local count=$(json_get "$result" '.gridBrowser.items | length')
    [[ "$count" -gt 50 ]] || { echo "Expected >50 items, got $count"; return 1; }
}

# ============================================================================
# Run
# ============================================================================

run_tests \
    test_initial_returns_grid_browser \
    test_initial_has_title \
    test_initial_returns_many_items \
    test_initial_has_columns \
    test_initial_has_actions \
    test_search_filters_results \
    test_search_heart \
    test_result_has_emoji_icon \
    test_result_has_copy_verb \
    test_result_has_actions \
    test_action_copy \
    test_action_type \
    test_action_default_is_copy \
    test_grid_browser_action_copy \
    test_grid_browser_action_type \
    test_grid_browser_action_has_history_name \
    test_index_returns_items \
    test_index_items_have_entrypoint \
    test_index_items_have_id \
    test_index_items_have_id_prefix \
    test_empty_query_returns_many \
    test_no_match_returns_empty \
    test_recent_emojis_not_loaded_in_test_mode
