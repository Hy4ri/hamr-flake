#!/bin/bash
export HAMR_TEST_MODE=1

source "$(dirname "$0")/../test-helpers.sh"

TEST_NAME="Player Plugin Tests"
HANDLER="$(dirname "$0")/handler.py"

test_initial_shows_players() {
    local result=$(hamr_test initial)
    assert_type "$result" "results"
    assert_has_result "$result" "player:spotify"
    assert_has_result "$result" "player:firefox"
}

test_initial_shows_status() {
    local result=$(hamr_test initial)
    assert_contains "$result" "Playing"
    assert_contains "$result" "Paused"
}

test_search_filters_players() {
    local result=$(hamr_test search --query "spotify")
    assert_has_result "$result" "player:spotify"
}

test_select_player_toggles_playback() {
    local result=$(hamr_test action --id "player:spotify")
    assert_type "$result" "execute"
}

test_player_action_next() {
    local result=$(hamr_test action --id "player:spotify" --action "next")
    assert_type "$result" "execute"
}

test_more_shows_controls() {
    local result=$(hamr_test action --id "player:spotify" --action "more")
    assert_type "$result" "results"
    assert_has_result "$result" "control:spotify:loop-none"
    assert_has_result "$result" "control:spotify:shuffle-on"
}

test_controls_have_plugin_actions() {
    local result=$(hamr_test action --id "player:spotify" --action "more")
    assert_contains "$result" "play-pause:spotify"
    assert_contains "$result" "previous:spotify"
    assert_contains "$result" "next:spotify"
}

test_plugin_action_play_pause() {
    local result=$(hamr_test action --id "__plugin__" --action "play-pause:spotify")
    assert_type "$result" "execute"
}

test_control_loop_track() {
    local result=$(hamr_test action --id "control:spotify:loop-track")
    assert_type "$result" "execute"
}

test_back_navigation() {
    local result=$(hamr_test action --id "__back__")
    assert_type "$result" "results"
    assert_has_result "$result" "player:spotify"
}

test_album_art_displayed() {
    local result=$(hamr_test initial)
    # Spotify mock player has artUrl, should show thumbnail
    assert_contains "$result" "thumbnail"
    assert_contains "$result" "/tmp/album-art.jpg"
}

run_tests \
    test_initial_shows_players \
    test_initial_shows_status \
    test_search_filters_players \
    test_select_player_toggles_playback \
    test_player_action_next \
    test_more_shows_controls \
    test_controls_have_plugin_actions \
    test_plugin_action_play_pause \
    test_control_loop_track \
    test_back_navigation \
    test_album_art_displayed
