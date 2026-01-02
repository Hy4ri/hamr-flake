#!/usr/bin/env python3
"""
Power plugin handler - system power and session controls.

Provides shutdown, restart, suspend, logout, lock, and Hyprland reload.
"""

import json
import os
import sys

TEST_MODE = os.environ.get("HAMR_TEST_MODE") == "1"

POWER_ACTIONS = [
    {
        "id": "shutdown",
        "name": "Shutdown",
        "description": "Power off the system",
        "icon": "power_settings_new",
        "command": ["systemctl", "poweroff"],
        "confirm": True,
    },
    {
        "id": "restart",
        "name": "Restart",
        "description": "Reboot the system",
        "icon": "restart_alt",
        "command": ["systemctl", "reboot"],
        "confirm": True,
    },
    {
        "id": "suspend",
        "name": "Suspend",
        "description": "Suspend to RAM",
        "icon": "bedtime",
        "command": ["systemctl", "suspend"],
    },
    {
        "id": "hibernate",
        "name": "Hibernate",
        "description": "Suspend to disk",
        "icon": "downloading",
        "command": ["systemctl", "hibernate"],
    },
    {
        "id": "lock",
        "name": "Lock Screen",
        "description": "Lock the session",
        "icon": "lock",
        "command": ["loginctl", "lock-session"],
    },
    {
        "id": "logout",
        "name": "Log Out",
        "description": "End the current session",
        "icon": "logout",
        "command": ["loginctl", "terminate-user", os.environ.get("USER", "")],
        "confirm": True,
    },
    {
        "id": "reload-hyprland",
        "name": "Reload Hyprland",
        "description": "Reload Hyprland configuration",
        "icon": "refresh",
        "command": [
            "bash",
            "-c",
            "hyprctl reload && notify-send 'Hyprland' 'Configuration reloaded'",
        ],
    },
    {
        "id": "reload-niri",
        "name": "Reload Niri",
        "description": "Reload Niri configuration",
        "icon": "refresh",
        "command": [
            "bash",
            "-c",
            "niri msg action load-config-file && notify-send 'Niri' 'Configuration reloaded'",
        ],
    },
    {
        "id": "reload-hamr",
        "name": "Reload Hamr",
        "description": "Restart Hamr launcher",
        "icon": "sync",
        "command": [
            "systemd-run",
            "--user",
            "--no-block",
            "bash",
            "-c",
            "if systemctl --user is-active --quiet hamr.service; then systemctl --user restart hamr.service; else qs kill -c hamr; qs -c hamr -d; fi; for i in $(seq 1 20); do qs ipc -c hamr call hamr open 2>/dev/null && break; sleep 0.1; done; notify-send 'Hamr' 'Launcher restarted'",
        ],
    },
]


def action_to_index_item(action: dict) -> dict:
    return {
        "id": f"power:{action['id']}",
        "name": action["name"],
        "description": action["description"],
        "icon": action["icon"],
        "verb": "Run",
        "keywords": [action["id"], action["name"].lower()],
        "execute": {
            "command": action["command"],
            "name": action["name"],
            "icon": action["icon"],
        },
    }


def action_to_result(action: dict) -> dict:
    return {
        "id": action["id"],
        "name": action["name"],
        "description": action["description"],
        "icon": action["icon"],
        "verb": "Run",
    }


def main():
    input_data = json.load(sys.stdin)
    step = input_data.get("step", "initial")
    query = input_data.get("query", "").strip().lower()
    selected = input_data.get("selected", {})

    if step == "index":
        items = [action_to_index_item(a) for a in POWER_ACTIONS]
        print(json.dumps({"type": "index", "items": items}))
        return

    if step == "initial":
        results = [action_to_result(a) for a in POWER_ACTIONS]
        print(
            json.dumps(
                {
                    "type": "results",
                    "results": results,
                    "placeholder": "Search power actions...",
                    "inputMode": "realtime",
                }
            )
        )
        return

    if step == "search":
        filtered = [
            a
            for a in POWER_ACTIONS
            if query in a["id"]
            or query in a["name"].lower()
            or query in a["description"].lower()
        ]
        results = [action_to_result(a) for a in filtered]
        if not results:
            results = [
                {
                    "id": "__empty__",
                    "name": f"No actions matching '{query}'",
                    "icon": "search_off",
                }
            ]
        print(
            json.dumps(
                {
                    "type": "results",
                    "results": results,
                    "inputMode": "realtime",
                }
            )
        )
        return

    if step == "action":
        selected_id = selected.get("id", "")

        if selected_id == "__empty__":
            print(json.dumps({"type": "execute", "execute": {"close": True}}))
            return

        action = next((a for a in POWER_ACTIONS if a["id"] == selected_id), None)
        if not action:
            print(
                json.dumps(
                    {"type": "error", "message": f"Unknown action: {selected_id}"}
                )
            )
            return

        if TEST_MODE:
            print(
                json.dumps(
                    {
                        "type": "execute",
                        "execute": {
                            "command": [
                                "echo",
                                f"Would run: {' '.join(action['command'])}",
                            ],
                            "name": action["name"],
                            "icon": action["icon"],
                            "close": True,
                        },
                    }
                )
            )
            return

        print(
            json.dumps(
                {
                    "type": "execute",
                    "execute": {
                        "command": action["command"],
                        "name": action["name"],
                        "icon": action["icon"],
                        "close": True,
                    },
                }
            )
        )
        return

    print(json.dumps({"type": "error", "message": f"Unknown step: {step}"}))


if __name__ == "__main__":
    main()
