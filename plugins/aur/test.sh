#!/bin/bash
export HAMR_TEST_MODE=1

source "$(dirname "$0")/../test-helpers.sh"

TEST_NAME="AUR Plugin Tests"
HANDLER="$(dirname "$0")/handler.py"

test_initial_shows_prompt() {
    local result=$(hamr_test initial)
    assert_type "$result" "results"
    assert_has_result "$result" "__prompt__"
    assert_contains "$result" "Search AUR"
}

test_search_requires_min_chars() {
    local result=$(hamr_test search --query "a")
    assert_type "$result" "results"
    assert_has_result "$result" "__prompt__"
    assert_contains "$result" "at least 2 characters"
}

test_search_returns_results() {
    local result=$(hamr_test search --query "yay")
    assert_type "$result" "results"
    assert_has_result "$result" "yay"
    assert_contains "$result" "Yet another yogurt"
}

test_search_has_paru() {
    local result=$(hamr_test search --query "paru")
    assert_type "$result" "results"
    assert_has_result "$result" "paru"
    assert_contains "$result" "AUR helper"
}

test_action_install() {
    local result=$(hamr_test action --id "pacseek" --action "install")
    assert_type "$result" "execute"
    assert_closes "$result"
}

test_action_uninstall() {
    local result=$(hamr_test action --id "yay" --action "uninstall")
    assert_type "$result" "execute"
    assert_closes "$result"
}

test_action_open_web() {
    local result=$(hamr_test action --id "paru" --action "open_web")
    assert_type "$result" "execute"
    local url=$(json_get "$result" '.openUrl')
    assert_contains "$url" "aur.archlinux.org/packages/paru"
    assert_closes "$result"
}

run_tests \
    test_initial_shows_prompt \
    test_search_requires_min_chars \
    test_search_returns_results \
    test_search_has_paru \
    test_action_install \
    test_action_uninstall \
    test_action_open_web
