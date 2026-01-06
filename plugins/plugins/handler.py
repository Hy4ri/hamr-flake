#!/usr/bin/env python3
"""Plugins browser - list and launch available plugins."""

import json
import sys


def main():
    input_data = json.load(sys.stdin)
    step = input_data.get("step", "initial")
    query = input_data.get("query", "").strip().lower()
    selected = input_data.get("selected", {})
    context = input_data.get("context", {})

    plugins = context.get("plugins", [])

    if step in ("initial", "search"):
        if query:
            filtered = [
                p
                for p in plugins
                if query in p.get("name", "").lower()
                or query in p.get("description", "").lower()
                or query in p.get("id", "").lower()
            ]
        else:
            filtered = plugins

        results = [
            {
                "id": p["id"],
                "name": p.get("name", p["id"]),
                "description": p.get("description", ""),
                "icon": p.get("icon", "extension"),
            }
            for p in filtered
        ]

        print(
            json.dumps(
                {
                    "type": "results",
                    "results": results,
                    "placeholder": "Search plugins...",
                }
            )
        )
        return

    if step == "action":
        plugin_id = selected.get("id", "")
        if plugin_id:
            print(json.dumps({"type": "startPlugin", "pluginId": plugin_id}))
        return


if __name__ == "__main__":
    main()
