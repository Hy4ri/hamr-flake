#!/usr/bin/env python3
"""
Web Apps plugin - Install and manage web apps.

Stores web apps in ~/.config/hamr/webapps.json and launches them
in app mode (standalone browser window) via the bundled launch-webapp script.

Features:
- Install web apps from URL + icon
- Browse and search installed web apps
- Launch web apps in standalone browser window
- Delete web apps
- Index support for main search integration
"""

import json
import os
import subprocess
import sys
from pathlib import Path

# Test mode support
TEST_MODE = os.environ.get("HAMR_TEST_MODE") == "1"

# Config file location
if TEST_MODE and os.environ.get("HAMR_TEST_CONFIG_DIR"):
    CONFIG_DIR = Path(os.environ["HAMR_TEST_CONFIG_DIR"])
else:
    CONFIG_DIR = Path.home() / ".config/hamr"

WEBAPPS_FILE = CONFIG_DIR / "webapps.json"
ICONS_DIR = CONFIG_DIR / "webapp-icons"
PLUGIN_DIR = Path(__file__).parent
LAUNCHER_SCRIPT = PLUGIN_DIR / "launch-webapp"


def ensure_dirs():
    """Ensure required directories exist"""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    ICONS_DIR.mkdir(parents=True, exist_ok=True)


def load_webapps() -> list[dict]:
    """Load web apps from config file"""
    if not WEBAPPS_FILE.exists():
        return []
    try:
        with open(WEBAPPS_FILE) as f:
            data = json.load(f)
            return data.get("webapps", [])
    except Exception:
        return []


def save_webapps(webapps: list[dict]) -> bool:
    """Save web apps to config file"""
    try:
        ensure_dirs()
        with open(WEBAPPS_FILE, "w") as f:
            json.dump({"webapps": webapps}, f, indent=2)
        return True
    except Exception:
        return False


def sanitize_name(name: str) -> str:
    """Sanitize app name for use in filenames"""
    safe = "".join(c if c.isalnum() else "-" for c in name)
    while "--" in safe:
        safe = safe.replace("--", "-")
    return safe.strip("-").lower()


def download_icon(url: str, name: str) -> str | None:
    """Download icon from URL, return local path or None on failure"""
    ensure_dirs()
    icon_path = ICONS_DIR / f"{sanitize_name(name)}.png"

    try:
        result = subprocess.run(
            ["curl", "-sL", "-o", str(icon_path), url],
            capture_output=True,
            timeout=30,
        )
        if (
            result.returncode == 0
            and icon_path.exists()
            and icon_path.stat().st_size > 0
        ):
            return str(icon_path)
    except Exception:
        pass

    # Cleanup failed download
    if icon_path.exists():
        icon_path.unlink()
    return None


def delete_icon(name: str):
    """Delete icon file for a web app"""
    icon_path = ICONS_DIR / f"{sanitize_name(name)}.png"
    if icon_path.exists():
        icon_path.unlink()


def get_plugin_actions() -> list[dict]:
    """Get plugin-level actions for the action bar"""
    return [
        {
            "id": "add",
            "name": "Install Web App",
            "icon": "add_circle",
            "shortcut": "Ctrl+1",
        }
    ]


def show_add_form(name: str = "", url: str = "", icon_url: str = ""):
    """Show form for adding a new web app"""
    print(
        json.dumps(
            {
                "type": "form",
                "form": {
                    "title": "Install Web App",
                    "submitLabel": "Install",
                    "cancelLabel": "Cancel",
                    "fields": [
                        {
                            "id": "name",
                            "type": "text",
                            "label": "App Name",
                            "placeholder": "My Favorite Web App",
                            "required": True,
                            "default": name,
                        },
                        {
                            "id": "url",
                            "type": "text",
                            "label": "URL",
                            "placeholder": "https://example.com",
                            "required": True,
                            "default": url,
                        },
                        {
                            "id": "icon_url",
                            "type": "text",
                            "label": "Icon URL",
                            "placeholder": "https://example.com/icon.png",
                            "required": True,
                            "default": icon_url,
                            "hint": "PNG icon URL (try dashboardicons.com)",
                        },
                    ],
                },
                "context": "__add__",
            }
        )
    )


def get_webapp_results(webapps: list[dict]) -> list[dict]:
    """Convert webapps to result format"""
    results = []
    for app in webapps:
        icon_path = app.get("icon", "")
        results.append(
            {
                "id": app["id"],
                "name": app["name"],
                "description": app["url"],
                "thumbnail": icon_path
                if icon_path and Path(icon_path).exists()
                else None,
                "icon": "web"
                if not icon_path or not Path(icon_path).exists()
                else None,
                "verb": "Launch",
                "actions": [
                    {
                        "id": "floating",
                        "name": "Open Floating",
                        "icon": "picture_in_picture",
                    },
                    {"id": "delete", "name": "Delete", "icon": "delete"},
                ],
            }
        )
    return results


def get_empty_results() -> list[dict]:
    """Return empty state results"""
    return [
        {
            "id": "__empty__",
            "name": "No web apps installed",
            "icon": "info",
            "description": "Use 'Install Web App' button or Ctrl+1",
        }
    ]


def webapp_to_index_item(app: dict) -> dict:
    """Convert a webapp to indexable item format for main search."""
    icon_path = app.get("icon", "")
    has_icon = icon_path and Path(icon_path).exists()

    return {
        "id": f"webapp:{app['id']}",
        "name": app["name"],
        "description": app["url"],
        "keywords": app["name"].lower().split(),
        "icon": None if has_icon else "web",
        "thumbnail": icon_path if has_icon else None,
        "verb": "Launch",
        "execute": {
            "command": [str(LAUNCHER_SCRIPT), app["url"]],
            "name": f"Launch {app['name']}",
        },
        "actions": [
            {
                "id": "floating",
                "name": "Open Floating",
                "icon": "picture_in_picture",
                "execute": {
                    "command": [str(LAUNCHER_SCRIPT), "--floating", app["url"]],
                    "name": f"Launch {app['name']} (floating)",
                },
            },
            {
                "id": "delete",
                "name": "Delete",
                "icon": "delete",
                "entryPoint": {
                    "step": "action",
                    "selected": {"id": app["id"]},
                    "action": "delete",
                },
            },
        ],
    }


def main():
    input_data = json.load(sys.stdin)
    step = input_data.get("step", "initial")
    query = input_data.get("query", "").strip()
    selected = input_data.get("selected", {})
    action = input_data.get("action", "")
    context = input_data.get("context", "")

    selected_id = selected.get("id", "")
    webapps = load_webapps()

    # Index: return items for main search integration
    if step == "index":
        items = [webapp_to_index_item(app) for app in webapps]
        print(json.dumps({"type": "index", "items": items}))
        return

    # Initial: show installed web apps
    if step == "initial":
        results = get_webapp_results(webapps) if webapps else get_empty_results()
        print(
            json.dumps(
                {
                    "type": "results",
                    "results": results,
                    "inputMode": "realtime",
                    "placeholder": "Search web apps...",
                    "pluginActions": get_plugin_actions(),
                }
            )
        )
        return

    # Search: filter web apps
    if step == "search":
        if query:
            query_lower = query.lower()
            filtered = [
                app
                for app in webapps
                if query_lower in app["name"].lower()
                or query_lower in app.get("url", "").lower()
            ]
        else:
            filtered = webapps

        results = (
            get_webapp_results(filtered)
            if filtered
            else [
                {
                    "id": "__empty__",
                    "name": "No matching web apps",
                    "icon": "search_off",
                }
            ]
        )

        print(
            json.dumps(
                {
                    "type": "results",
                    "results": results,
                    "inputMode": "realtime",
                    "placeholder": "Search web apps...",
                    "pluginActions": get_plugin_actions(),
                }
            )
        )
        return

    # Form submission
    if step == "form":
        form_data = input_data.get("formData", {})

        if context == "__add__":
            name = form_data.get("name", "").strip()
            url = form_data.get("url", "").strip()
            icon_url = form_data.get("icon_url", "").strip()

            if not name:
                print(json.dumps({"type": "error", "message": "App name is required"}))
                return

            if not url:
                print(json.dumps({"type": "error", "message": "URL is required"}))
                return

            if not icon_url:
                print(json.dumps({"type": "error", "message": "Icon URL is required"}))
                return

            # Add https:// if missing
            if not url.startswith("http://") and not url.startswith("https://"):
                url = "https://" + url

            if not icon_url.startswith("http://") and not icon_url.startswith(
                "https://"
            ):
                icon_url = "https://" + icon_url

            # Check if already exists
            app_id = sanitize_name(name)
            if any(app["id"] == app_id for app in webapps):
                print(
                    json.dumps({"type": "error", "message": f"'{name}' already exists"})
                )
                return

            # Download icon
            icon_path = download_icon(icon_url, name)
            if not icon_path:
                print(
                    json.dumps({"type": "error", "message": "Failed to download icon"})
                )
                return

            # Add new webapp
            new_app = {
                "id": app_id,
                "name": name,
                "url": url,
                "icon": icon_path,
            }
            webapps.append(new_app)

            if save_webapps(webapps):
                print(
                    json.dumps(
                        {
                            "type": "results",
                            "results": get_webapp_results(webapps),
                            "inputMode": "realtime",
                            "clearInput": True,
                            "context": "",
                            "placeholder": "Search web apps...",
                            "pluginActions": get_plugin_actions(),
                        }
                    )
                )
            else:
                print(
                    json.dumps({"type": "error", "message": "Failed to save web app"})
                )
            return

    # Action handling
    if step == "action":
        # Plugin-level action: add (from action bar)
        if selected_id == "__plugin__" and action == "add":
            show_add_form()
            return

        # Form cancelled
        if selected_id == "__form_cancel__":
            results = get_webapp_results(webapps) if webapps else get_empty_results()
            print(
                json.dumps(
                    {
                        "type": "results",
                        "results": results,
                        "inputMode": "realtime",
                        "clearInput": True,
                        "context": "",
                        "placeholder": "Search web apps...",
                        "pluginActions": get_plugin_actions(),
                    }
                )
            )
            return

        # Non-actionable items
        if selected_id in ("__empty__",):
            return

        # Floating action - open as floating window
        if action == "floating":
            app = next((a for a in webapps if a["id"] == selected_id), None)
            if app:
                icon_path = app.get("icon", "")
                has_icon = icon_path and Path(icon_path).exists()
                print(
                    json.dumps(
                        {
                            "type": "execute",
                            "execute": {
                                "command": [
                                    str(LAUNCHER_SCRIPT),
                                    "--floating",
                                    app["url"],
                                ],
                                "name": f"Launch {app['name']} (floating)",
                                "icon": None if has_icon else "web",
                                "thumbnail": icon_path if has_icon else None,
                                "close": True,
                            },
                        }
                    )
                )
            return

        # Delete action
        if action == "delete":
            app = next((a for a in webapps if a["id"] == selected_id), None)
            if app:
                delete_icon(app["name"])
                webapps = [a for a in webapps if a["id"] != selected_id]
                save_webapps(webapps)

            results = get_webapp_results(webapps) if webapps else get_empty_results()
            print(
                json.dumps(
                    {
                        "type": "results",
                        "results": results,
                        "inputMode": "realtime",
                        "clearInput": True,
                        "placeholder": "Search web apps...",
                        "pluginActions": get_plugin_actions(),
                    }
                )
            )
            return

        # Launch web app (default action - click on item)
        app = next((a for a in webapps if a["id"] == selected_id), None)
        if app:
            icon_path = app.get("icon", "")
            has_icon = icon_path and Path(icon_path).exists()
            print(
                json.dumps(
                    {
                        "type": "execute",
                        "execute": {
                            "command": [str(LAUNCHER_SCRIPT), app["url"]],
                            "name": f"Launch {app['name']}",
                            "icon": None if has_icon else "web",
                            "thumbnail": icon_path if has_icon else None,
                            "close": True,
                        },
                    }
                )
            )
        return


if __name__ == "__main__":
    main()
