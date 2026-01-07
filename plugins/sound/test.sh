#!/bin/bash
export HAMR_TEST_MODE=1

source "$(dirname "$0")/../test-helpers.sh"

TEST_NAME="Sound Plugin Tests"
HANDLER="$(dirname "$0")/handler.py"

test_initial_shows_sliders() {
    local result=$(hamr_test initial)
    assert_type "$result" "results"
    assert_contains "$result" '"id": "volume"'
    assert_contains "$result" '"id": "mic"'
}

test_initial_shows_volume_gauge() {
    local result=$(hamr_test initial)
    assert_type "$result" "results"
    assert_contains "$result" "gauge"
    assert_contains "$result" "50%"
}

test_initial_shows_mute_switch() {
    local result=$(hamr_test initial)
    assert_type "$result" "results"
    assert_contains "$result" '"id": "volume-mute"'
    assert_contains "$result" '"type": "switch"'
}

test_action_slider_change_volume() {
    local result=$(hamr_test raw --input '{"step":"action","selected":{"id":"volume"},"action":"slider","value":75}')
    assert_type "$result" "update"
    assert_contains "$result" '"id": "volume"'
    assert_contains "$result" '"gauge"'
}

test_action_switch_mute() {
    local result=$(hamr_test raw --input '{"step":"action","selected":{"id":"volume-mute"},"action":"switch","value":true}')
    assert_type "$result" "update"
    assert_contains "$result" '"id": "volume-mute"'
}

test_action_switch_mic_mute() {
    local result=$(hamr_test raw --input '{"step":"action","selected":{"id":"mic-mute"},"action":"switch","value":true}')
    assert_type "$result" "update"
    assert_contains "$result" '"id": "mic-mute"'
}

test_volume_slider_type() {
    local result=$(hamr_test initial)
    local slider_type=$(json_get "$result" '.results[0].type')
    assert_eq "$slider_type" "slider"
}

test_volume_has_min_max() {
    local result=$(hamr_test initial)
    local min=$(json_get "$result" '.results[0].min')
    local max=$(json_get "$result" '.results[0].max')
    assert_eq "$min" "0"
    assert_eq "$max" "100"
}

run_tests \
    test_initial_shows_sliders \
    test_initial_shows_volume_gauge \
    test_initial_shows_mute_switch \
    test_action_slider_change_volume \
    test_action_switch_mute \
    test_action_switch_mic_mute \
    test_volume_slider_type \
    test_volume_has_min_max
