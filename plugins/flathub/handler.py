#!/usr/bin/env python3
"""
Flathub plugin - Search and install apps from Flathub.

Features:
- Search Flathub for apps
- Install apps (non-blocking with notifications)
- Uninstall installed apps
- Open app page on Flathub website
- Detect already installed apps
"""

import json
import os
import subprocess
import sys
import urllib.request
import urllib.error

TEST_MODE = os.environ.get("HAMR_TEST_MODE") == "1"

FLATHUB_API = "https://flathub.org/api/v2/search"
FLATHUB_WEB = "https://flathub.org/apps"


def get_installed_apps() -> set[str]:
    """Get set of installed Flatpak app IDs"""
    try:
        result = subprocess.run(
            ["flatpak", "list", "--app", "--columns=application"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0:
            return set(result.stdout.strip().split("\n")) - {""}
    except Exception:
        pass
    return set()


def search_flathub(query: str) -> list[dict]:
    """Search Flathub API for apps"""
    if TEST_MODE:
        return [
            {
                "app_id": "org.mozilla.firefox",
                "name": "Firefox",
                "summary": "Fast, Private & Safe Web Browser",
                "icon": "https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/org.mozilla.firefox.png",
                "developer_name": "Mozilla",
                "installs_last_month": 314667,
                "verification_verified": True,
            },
            {
                "app_id": "org.videolan.VLC",
                "name": "VLC",
                "summary": "VLC media player",
                "icon": "https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/org.videolan.VLC.png",
                "developer_name": "VideoLAN",
                "installs_last_month": 200000,
                "verification_verified": True,
            },
        ]

    try:
        data = json.dumps({"query": query}).encode("utf-8")
        req = urllib.request.Request(
            FLATHUB_API,
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.loads(response.read().decode("utf-8"))
            return result.get("hits", [])
    except Exception:
        return []


def format_installs(count: int) -> str:
    """Format install count for display"""
    if count >= 1_000_000:
        return f"{count / 1_000_000:.1f}M"
    if count >= 1_000:
        return f"{count / 1_000:.1f}K"
    return str(count)


def app_to_result(app: dict, installed_apps: set[str]) -> dict:
    """Convert Flathub app to result format"""
    app_id = app.get("app_id", "")
    is_installed = app_id in installed_apps
    installs = app.get("installs_last_month", 0)
    verified = app.get("verification_verified", False)

    developer = app.get("developer_name", "")
    stats = []
    if developer:
        stats.append(developer)
    if verified:
        stats.append("Verified")
    if installs:
        stats.append(f"{format_installs(installs)} installs/mo")

    description = " · ".join(stats) if stats else app.get("summary", "")

    actions = []
    if is_installed:
        actions.append({"id": "uninstall", "name": "Uninstall", "icon": "delete"})
        actions.append(
            {"id": "open_web", "name": "View on Flathub", "icon": "open_in_new"}
        )
    else:
        actions.append(
            {"id": "open_web", "name": "View on Flathub", "icon": "open_in_new"}
        )

    return {
        "id": app_id,
        "name": app.get("name", app_id),
        "description": description,
        "thumbnail": app.get("icon", ""),
        "verb": "Open" if is_installed else "Install",
        "actions": actions,
    }


def main():
    input_data = json.load(sys.stdin)
    step = input_data.get("step", "initial")
    query = input_data.get("query", "").strip()
    selected = input_data.get("selected", {})
    action = input_data.get("action", "")

    selected_id = selected.get("id", "")

    # Initial: prompt for search
    if step == "initial":
        print(
            json.dumps(
                {
                    "type": "results",
                    "results": [
                        {
                            "id": "__prompt__",
                            "name": "Search Flathub",
                            "description": "Type to search for apps",
                            "icon": "search",
                        }
                    ],
                    "inputMode": "realtime",
                    "placeholder": "Search Flathub...",
                }
            )
        )
        return

    # Search: query Flathub API
    if step == "search":
        if not query or len(query) < 2:
            print(
                json.dumps(
                    {
                        "type": "results",
                        "results": [
                            {
                                "id": "__prompt__",
                                "name": "Search Flathub",
                                "description": "Type at least 2 characters to search",
                                "icon": "search",
                            }
                        ],
                        "inputMode": "realtime",
                        "placeholder": "Search Flathub...",
                    }
                )
            )
            return

        apps = search_flathub(query)
        installed_apps = get_installed_apps()

        if not apps:
            print(
                json.dumps(
                    {
                        "type": "results",
                        "results": [
                            {
                                "id": "__empty__",
                                "name": "No apps found",
                                "description": f"No results for '{query}'",
                                "icon": "search_off",
                            }
                        ],
                        "inputMode": "realtime",
                        "placeholder": "Search Flathub...",
                    }
                )
            )
            return

        results = [app_to_result(app, installed_apps) for app in apps[:15]]
        print(
            json.dumps(
                {
                    "type": "results",
                    "results": results,
                    "inputMode": "realtime",
                    "placeholder": "Search Flathub...",
                }
            )
        )
        return

    # Action handling
    if step == "action":
        if selected_id in ("__prompt__", "__empty__"):
            return

        installed_apps = get_installed_apps()
        is_installed = selected_id in installed_apps
        app_name = selected.get("name", selected_id)

        # Uninstall action
        if action == "uninstall":
            print(
                json.dumps(
                    {
                        "type": "execute",
                        "execute": {
                            "command": [
                                "bash",
                                "-c",
                                f'notify-send "Flathub" "Uninstalling {app_name}..." -a "Hamr" && '
                                f"(flatpak uninstall --user -y {selected_id} 2>/dev/null || flatpak uninstall -y {selected_id}) && "
                                f'notify-send "Flathub" "{app_name} uninstalled" -a "Hamr" && '
                                f"qs -c hamr ipc call pluginRunner reindex apps || "
                                f'notify-send "Flathub" "Failed to uninstall {app_name}" -a "Hamr"',
                            ],
                            "close": True,
                        },
                    }
                )
            )
            return

        # Open on Flathub website
        if action == "open_web":
            print(
                json.dumps(
                    {
                        "type": "execute",
                        "execute": {
                            "command": ["xdg-open", f"{FLATHUB_WEB}/{selected_id}"],
                            "close": True,
                        },
                    }
                )
            )
            return

        # Default action: Install or Open
        if is_installed:
            # Open the installed app
            print(
                json.dumps(
                    {
                        "type": "execute",
                        "execute": {
                            "command": ["flatpak", "run", selected_id],
                            "close": True,
                        },
                    }
                )
            )
        else:
            # Install the app (non-blocking with notifications)
            # Try user install first, fall back to system install
            print(
                json.dumps(
                    {
                        "type": "execute",
                        "execute": {
                            "command": [
                                "bash",
                                "-c",
                                f'notify-send "Flathub" "Installing {app_name}..." -a "Hamr" && '
                                f"(flatpak install --user -y flathub {selected_id} 2>/dev/null || flatpak install -y flathub {selected_id}) && "
                                f'notify-send "Flathub" "{app_name} installed" -a "Hamr" && '
                                f"qs -c hamr ipc call pluginRunner reindex apps || "
                                f'notify-send "Flathub" "Failed to install {app_name}" -a "Hamr"',
                            ],
                            "close": True,
                        },
                    }
                )
            )
        return


if __name__ == "__main__":
    main()
