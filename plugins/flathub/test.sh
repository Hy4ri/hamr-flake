#!/bin/bash
#
# Tests for flathub plugin
# Run: ./test.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export HAMR_TEST_MODE=1
source "$SCRIPT_DIR/../test-helpers.sh"

# ============================================================================
# Config
# ============================================================================

TEST_NAME="Flathub Plugin Tests"
HANDLER="$SCRIPT_DIR/handler.py"

# ============================================================================
# Tests - Initial State
# ============================================================================

test_initial_shows_search_prompt() {
    local result=$(hamr_test initial)
    
    assert_type "$result" "results"
    assert_realtime_mode "$result"
    assert_has_result "$result" "__prompt__"
    assert_contains "$result" "Search Flathub"
}

test_initial_has_placeholder() {
    local result=$(hamr_test initial)
    
    assert_json "$result" '.placeholder' "Search Flathub..."
}

# ============================================================================
# Tests - Search
# ============================================================================

test_search_too_short() {
    local result=$(hamr_test search --query "a")
    
    assert_type "$result" "results"
    assert_has_result "$result" "__prompt__"
    assert_contains "$result" "at least 2 characters"
}

test_search_returns_results() {
    local result=$(hamr_test search --query "firefox")
    
    assert_type "$result" "results"
    assert_realtime_mode "$result"
    # In test mode, we return mock data with Firefox
    assert_contains "$result" "Firefox"
}

test_search_result_has_thumbnail() {
    local result=$(hamr_test search --query "firefox")
    
    assert_contains "$result" "thumbnail"
    assert_contains "$result" "https://"
}

test_search_result_has_description() {
    local result=$(hamr_test search --query "firefox")
    
    # Should have developer info in description
    assert_contains "$result" "Mozilla"
}

test_search_result_has_verb() {
    local result=$(hamr_test search --query "firefox")
    
    # Should have Install or Open verb
    local verb=$(json_get "$result" '.results[0].verb')
    [[ "$verb" == "Install" || "$verb" == "Open" ]]
}

test_search_result_has_actions() {
    local result=$(hamr_test search --query "firefox")
    
    assert_contains "$result" "actions"
    assert_contains "$result" "open_web"
}

# ============================================================================
# Tests - Actions
# ============================================================================

test_action_prompt_no_output() {
    local result=$(hamr_test action --id "__prompt__" 2>&1)
    
    assert_contains "$result" "no output"
}

test_action_empty_no_output() {
    local result=$(hamr_test action --id "__empty__" 2>&1)
    
    assert_contains "$result" "no output"
}

test_action_install_returns_execute() {
    local result=$(echo '{"step": "action", "selected": {"id": "org.example.App", "name": "Example App"}}' | HAMR_TEST_MODE=1 python3 "$HANDLER")
    
    assert_type "$result" "execute"
    assert_closes "$result"
    assert_contains "$result" "flatpak install"
    assert_contains "$result" "notify-send"
}

test_action_uninstall_returns_execute() {
    local result=$(echo '{"step": "action", "action": "uninstall", "selected": {"id": "org.example.App", "name": "Example App"}}' | HAMR_TEST_MODE=1 python3 "$HANDLER")
    
    assert_type "$result" "execute"
    assert_closes "$result"
    assert_contains "$result" "flatpak uninstall"
    assert_contains "$result" "notify-send"
}

test_action_open_web_returns_execute() {
    local result=$(hamr_test action --id "org.example.App" --action "open_web")
    
    assert_type "$result" "execute"
    assert_closes "$result"
    assert_contains "$result" "xdg-open"
    assert_contains "$result" "flathub.org/apps/org.example.App"
}

# ============================================================================
# Tests - All Responses Valid
# ============================================================================

test_all_responses_valid() {
    assert_ok hamr_test initial
    assert_ok hamr_test search --query "test"
    assert_ok hamr_test search --query "firefox"
    assert_ok hamr_test action --id "org.example.App"
    assert_ok hamr_test action --id "org.example.App" --action "open_web"
    assert_ok hamr_test action --id "org.example.App" --action "uninstall"
}

# ============================================================================
# Run
# ============================================================================

run_tests \
    test_initial_shows_search_prompt \
    test_initial_has_placeholder \
    test_search_too_short \
    test_search_returns_results \
    test_search_result_has_thumbnail \
    test_search_result_has_description \
    test_search_result_has_verb \
    test_search_result_has_actions \
    test_action_prompt_no_output \
    test_action_empty_no_output \
    test_action_install_returns_execute \
    test_action_uninstall_returns_execute \
    test_action_open_web_returns_execute \
    test_all_responses_valid
