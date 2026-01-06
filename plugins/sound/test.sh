#!/bin/bash
export HAMR_TEST_MODE=1

source "$(dirname "$0")/../test-helpers.sh"

TEST_NAME="Sound Plugin Tests"
HANDLER="$(dirname "$0")/handler.py"

test_initial_shows_sliders() {
    local result=$(hamr_test initial)
    assert_type "$result" "index"
    # Check that volume and mic items exist in index
    assert_contains "$result" '"id": "volume"'
    assert_contains "$result" '"id": "mic"'
}

test_initial_shows_volume_gauge() {
    local result=$(hamr_test initial)
    assert_type "$result" "index"
    assert_contains "$result" "gauge"
    assert_contains "$result" "50%"
}

test_initial_shows_muted_badge() {
    local result=$(hamr_test initial)
    assert_type "$result" "index"
    # Badges array should be in the response
    assert_contains "$result" "badges"
}

test_action_slider_change_volume() {
    local result=$(hamr_test raw --input '{"step":"action","selected":{"id":"volume"},"action":"slider","value":75}')
    assert_type "$result" "update"
    # Check that the update includes the volume item with gauge data
    assert_contains "$result" '"id": "volume"'
    assert_contains "$result" '"gauge"'
}

test_action_mute_toggle() {
    local result=$(hamr_test action --id "volume" --action "mute-toggle")
    assert_type "$result" "results"
}

test_action_mic_mute_toggle() {
    local result=$(hamr_test action --id "mic" --action "mic-mute-toggle")
    assert_type "$result" "results"
}

test_plugin_action_mute_toggle() {
    local result=$(hamr_test action --id "__plugin__" --action "mute-toggle")
    assert_type "$result" "results"
}

test_volume_slider_type() {
    local result=$(hamr_test initial)
    local slider_type=$(echo "$result" | jq -r '.items[0].type')
    assert_eq "$slider_type" "slider" "First item should be a slider"
}

run_tests \
    test_initial_shows_sliders \
    test_initial_shows_volume_gauge \
    test_initial_shows_muted_badge \
    test_action_slider_change_volume \
    test_action_mute_toggle \
    test_action_mic_mute_toggle \
    test_plugin_action_mute_toggle \
    test_volume_slider_type
