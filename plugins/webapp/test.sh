#!/bin/bash
#
# Tests for webapp plugin
# Run: ./test.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export HAMR_TEST_MODE=1
source "$SCRIPT_DIR/../test-helpers.sh"

# ============================================================================
# Config
# ============================================================================

TEST_NAME="Web Apps Plugin Tests"
HANDLER="$SCRIPT_DIR/handler.py"

# Test directories
TEST_CONFIG_DIR="/tmp/hamr-webapp-test-$$"
TEST_ICONS_DIR="$TEST_CONFIG_DIR/webapp-icons"
WEBAPPS_FILE="$TEST_CONFIG_DIR/webapps.json"

# ============================================================================
# Setup / Teardown
# ============================================================================

setup() {
    # Create test directories
    mkdir -p "$TEST_ICONS_DIR"
    
    # Set test config directory
    export HAMR_TEST_CONFIG_DIR="$TEST_CONFIG_DIR"
}

teardown() {
    # Cleanup test directories
    rm -rf "$TEST_CONFIG_DIR"
}

before_each() {
    # Clear test data before each test
    rm -f "$WEBAPPS_FILE"
    rm -f "$TEST_ICONS_DIR"/*.png
}

# ============================================================================
# Helpers
# ============================================================================

set_webapps() {
    mkdir -p "$TEST_CONFIG_DIR"
    echo "$1" > "$WEBAPPS_FILE"
}

clear_webapps() {
    set_webapps '{"webapps": []}'
}

get_webapps_file() {
    cat "$WEBAPPS_FILE"
}

create_test_webapp() {
    local name="$1"
    local url="$2"
    local safe_name=$(echo "$name" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')
    local icon_path="$TEST_ICONS_DIR/${safe_name}.png"
    
    # Create dummy icon
    echo "dummy icon" > "$icon_path"
    
    # Load existing webapps
    local webapps
    if [[ -f "$WEBAPPS_FILE" ]]; then
        webapps=$(cat "$WEBAPPS_FILE")
    else
        webapps='{"webapps": []}'
    fi
    
    # Add new webapp
    webapps=$(echo "$webapps" | jq --arg id "$safe_name" --arg name "$name" --arg url "$url" --arg icon "$icon_path" \
        '.webapps += [{"id": $id, "name": $name, "url": $url, "icon": $icon}]')
    
    mkdir -p "$TEST_CONFIG_DIR"
    echo "$webapps" > "$WEBAPPS_FILE"
}

get_webapp_count() {
    if [[ -f "$WEBAPPS_FILE" ]]; then
        jq '.webapps | length' "$WEBAPPS_FILE"
    else
        echo "0"
    fi
}

# Override hamr_test to inject test directory
hamr_test() {
    if [[ -z "$HANDLER" ]]; then
        echo "Error: HANDLER not set" >&2
        exit 1
    fi
    HAMR_TEST_CONFIG_DIR="$TEST_CONFIG_DIR" "$HAMR_TEST" "$HANDLER" "$@" 2>&1
}

# ============================================================================
# Tests - Initial State
# ============================================================================

test_initial_empty() {
    clear_webapps
    local result=$(hamr_test initial)
    
    assert_type "$result" "results"
    assert_realtime_mode "$result"
    assert_has_result "$result" "__empty__"
    assert_contains "$result" "No web apps installed"
}

test_initial_has_plugin_actions() {
    clear_webapps
    local result=$(hamr_test initial)
    
    assert_contains "$result" "pluginActions"
    assert_json "$result" '.pluginActions[0].id' "add"
    assert_json "$result" '.pluginActions[0].name' "Install Web App"
}

test_initial_with_webapps() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    create_test_webapp "AnotherApp" "https://another.com"
    local result=$(hamr_test initial)
    
    assert_type "$result" "results"
    assert_contains "$result" "TestApp"
    assert_contains "$result" "AnotherApp"
}

test_initial_shows_url_as_description() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    local result=$(hamr_test initial)
    
    local description=$(json_get "$result" '.results[] | select(.name == "TestApp") | .description')
    assert_eq "$description" "https://example.com"
}

test_initial_has_delete_action() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    local result=$(hamr_test initial)
    
    local actions=$(json_get "$result" '.results[] | select(.name == "TestApp") | .actions')
    assert_contains "$actions" "delete"
}

test_initial_has_floating_action() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    local result=$(hamr_test initial)
    
    local actions=$(json_get "$result" '.results[] | select(.name == "TestApp") | .actions')
    assert_contains "$actions" "floating"
}

# ============================================================================
# Tests - Search / Filter
# ============================================================================

test_search_filters_by_name() {
    clear_webapps
    create_test_webapp "Gmail" "https://mail.google.com"
    create_test_webapp "GitHub" "https://github.com"
    create_test_webapp "GitLab" "https://gitlab.com"
    local result=$(hamr_test search --query "git")
    
    assert_contains "$result" "GitHub"
    assert_contains "$result" "GitLab"
    assert_not_contains "$result" "Gmail"
}

test_search_filters_by_url() {
    clear_webapps
    create_test_webapp "Gmail" "https://mail.google.com"
    create_test_webapp "Drive" "https://drive.google.com"
    local result=$(hamr_test search --query "google")
    
    assert_contains "$result" "Gmail"
    assert_contains "$result" "Drive"
}

test_search_no_results() {
    clear_webapps
    create_test_webapp "Gmail" "https://mail.google.com"
    local result=$(hamr_test search --query "nonexistent")
    
    assert_has_result "$result" "__empty__"
    assert_contains "$result" "No matching"
}

test_search_realtime_mode() {
    clear_webapps
    local result=$(hamr_test search --query "test")
    
    assert_realtime_mode "$result"
}

# ============================================================================
# Tests - Add Web App (Form API)
# ============================================================================

test_add_shows_form() {
    clear_webapps
    local result=$(hamr_test action --id "__plugin__" --action "add")
    
    assert_type "$result" "form"
    assert_json "$result" '.context' "__add__"
    assert_json "$result" '.form.title' "Install Web App"
}

test_add_form_has_name_field() {
    clear_webapps
    local result=$(hamr_test action --id "__plugin__" --action "add")
    
    local name_field=$(json_get "$result" '.form.fields[] | select(.id == "name")')
    assert_contains "$name_field" '"type": "text"'
    assert_contains "$name_field" '"required": true'
}

test_add_form_has_url_field() {
    clear_webapps
    local result=$(hamr_test action --id "__plugin__" --action "add")
    
    local url_field=$(json_get "$result" '.form.fields[] | select(.id == "url")')
    assert_contains "$url_field" '"type": "text"'
    assert_contains "$url_field" '"required": true'
}

test_add_form_has_icon_url_field() {
    clear_webapps
    local result=$(hamr_test action --id "__plugin__" --action "add")
    
    local icon_field=$(json_get "$result" '.form.fields[] | select(.id == "icon_url")')
    assert_contains "$icon_field" '"type": "text"'
    assert_contains "$icon_field" '"required": true'
    assert_contains "$icon_field" "dashboardicons"
}

test_add_form_requires_name() {
    clear_webapps
    local result=$(hamr_test form --data '{"name": "", "url": "https://example.com", "icon_url": "https://example.com/icon.png"}' --context "__add__")
    
    assert_type "$result" "error"
    assert_contains "$result" "name is required"
}

test_add_form_requires_url() {
    clear_webapps
    local result=$(hamr_test form --data '{"name": "Test", "url": "", "icon_url": "https://example.com/icon.png"}' --context "__add__")
    
    assert_type "$result" "error"
    assert_contains "$result" "URL is required"
}

test_add_form_requires_icon_url() {
    clear_webapps
    local result=$(hamr_test form --data '{"name": "Test", "url": "https://example.com", "icon_url": ""}' --context "__add__")
    
    assert_type "$result" "error"
    assert_contains "$result" "Icon URL is required"
}

test_add_form_cancel_returns_to_list() {
    clear_webapps
    local result=$(hamr_test action --id "__form_cancel__")
    
    assert_type "$result" "results"
    assert_contains "$result" "pluginActions"
}

# ============================================================================
# Tests - Delete Web App
# ============================================================================

test_delete_removes_webapp() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    assert_eq "$(get_webapp_count)" "1"
    
    local result=$(hamr_test action --id "testapp" --action "delete")
    
    assert_type "$result" "results"
    assert_eq "$(get_webapp_count)" "0"
}

test_delete_shows_remaining() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    create_test_webapp "AnotherApp" "https://another.com"
    
    local result=$(hamr_test action --id "testapp" --action "delete")
    
    assert_type "$result" "results"
    assert_contains "$result" "AnotherApp"
    assert_not_contains "$result" "TestApp"
}

test_delete_shows_empty_when_last() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    
    local result=$(hamr_test action --id "testapp" --action "delete")
    
    assert_type "$result" "results"
    assert_has_result "$result" "__empty__"
}

# ============================================================================
# Tests - Launch Web App
# ============================================================================

test_launch_returns_execute() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    local result=$(hamr_test action --id "testapp")
    
    assert_type "$result" "execute"
    assert_closes "$result"
}

test_launch_uses_launcher_script() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    local result=$(hamr_test action --id "testapp")
    
    assert_contains "$result" "launch-webapp"
    assert_contains "$result" "https://example.com"
}

test_launch_includes_name_for_history() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    local result=$(hamr_test action --id "testapp")
    
    local name=$(json_get "$result" '.execute.name')
    assert_contains "$name" "TestApp"
}

test_launch_floating_returns_execute() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    local result=$(hamr_test action --id "testapp" --action "floating")
    
    assert_type "$result" "execute"
    assert_closes "$result"
    assert_contains "$result" "--floating"
}

# ============================================================================
# Tests - Index (for main search integration)
# ============================================================================

test_index_returns_items() {
    clear_webapps
    create_test_webapp "Gmail" "https://mail.google.com"
    create_test_webapp "GitHub" "https://github.com"
    local result=$(hamr_test index)
    
    assert_type "$result" "index"
    local count=$(json_get "$result" '.items | length')
    assert_eq "$count" "2"
}

test_index_item_has_execute() {
    clear_webapps
    create_test_webapp "Gmail" "https://mail.google.com"
    local result=$(hamr_test index)
    
    local cmd=$(json_get "$result" '.items[0].execute.command[1]')
    assert_eq "$cmd" "https://mail.google.com"
}

test_index_item_has_delete_action() {
    clear_webapps
    create_test_webapp "Gmail" "https://mail.google.com"
    local result=$(hamr_test index)
    
    local actions=$(json_get "$result" '.items[0].actions')
    assert_contains "$actions" "delete"
}

test_index_item_has_floating_action() {
    clear_webapps
    create_test_webapp "Gmail" "https://mail.google.com"
    local result=$(hamr_test index)
    
    local actions=$(json_get "$result" '.items[0].actions')
    assert_contains "$actions" "floating"
}

# ============================================================================
# Tests - Non-actionable Items
# ============================================================================

test_empty_item_no_action() {
    clear_webapps
    local result=$(hamr_test action --id "__empty__" 2>&1)
    
    # Handler returns nothing for non-actionable items, harness reports error
    assert_contains "$result" "no output"
}

# ============================================================================
# Tests - All Responses Valid
# ============================================================================

test_all_responses_valid() {
    clear_webapps
    create_test_webapp "TestApp" "https://example.com"
    
    assert_ok hamr_test initial
    assert_ok hamr_test search --query "test"
    assert_ok hamr_test action --id "__plugin__" --action "add"
    assert_ok hamr_test action --id "__form_cancel__"
    assert_ok hamr_test action --id "testapp"
    assert_ok hamr_test action --id "testapp" --action "delete"
    assert_ok hamr_test index
}

# ============================================================================
# Run
# ============================================================================

run_tests \
    test_initial_empty \
    test_initial_has_plugin_actions \
    test_initial_with_webapps \
    test_initial_shows_url_as_description \
    test_initial_has_delete_action \
    test_initial_has_floating_action \
    test_search_filters_by_name \
    test_search_filters_by_url \
    test_search_no_results \
    test_search_realtime_mode \
    test_add_shows_form \
    test_add_form_has_name_field \
    test_add_form_has_url_field \
    test_add_form_has_icon_url_field \
    test_add_form_requires_name \
    test_add_form_requires_url \
    test_add_form_requires_icon_url \
    test_add_form_cancel_returns_to_list \
    test_delete_removes_webapp \
    test_delete_shows_remaining \
    test_delete_shows_empty_when_last \
    test_launch_returns_execute \
    test_launch_uses_launcher_script \
    test_launch_includes_name_for_history \
    test_launch_floating_returns_execute \
    test_index_returns_items \
    test_index_item_has_execute \
    test_index_item_has_delete_action \
    test_index_item_has_floating_action \
    test_empty_item_no_action \
    test_all_responses_valid
