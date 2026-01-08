#!/usr/bin/env python3
"""
Zoxide plugin handler - index frequently used directories from zoxide.
"""

import json
import os
import select
import shutil
import subprocess
import sys
from pathlib import Path

IS_NIRI = bool(os.environ.get("NIRI_SOCKET"))

MAX_ITEMS = 50
POLL_INTERVAL_SECONDS = 60

ZOXIDE_DB = Path.home() / ".local/share/zoxide/db.zo"


def get_zoxide_dirs() -> list[dict]:
    """Get directories from zoxide database with scores."""
    if not shutil.which("zoxide"):
        return []

    try:
        result = subprocess.run(
            ["zoxide", "query", "-l", "-s"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            return []

        dirs = []
        for line in result.stdout.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split(maxsplit=1)
            if len(parts) != 2:
                continue

            score_str, path = parts
            try:
                score = float(score_str)
            except ValueError:
                continue

            path_obj = Path(path)
            if path_obj.exists() and path_obj.is_dir():
                dirs.append({"path": path, "score": score})

        dirs.sort(key=lambda x: -x["score"])
        return dirs[:MAX_ITEMS]

    except (subprocess.TimeoutExpired, Exception):
        return []


def make_terminal_cmd(path: str) -> list[str]:
    """Build command to open terminal at directory.

    Uses terminal's native --working-directory flag.
    For ghostty with gtk-single-instance, we disable it for this invocation
    to ensure the working directory is respected.
    """
    terminal = os.environ.get("TERMINAL", "ghostty")
    terminal_name = os.path.basename(terminal).lower()

    if terminal_name in ("ghostty",):
        cmd_parts = [
            terminal,
            "--gtk-single-instance=false",
            f"--working-directory={path}",
        ]
    elif terminal_name in ("kitty",):
        cmd_parts = [terminal, "-d", path]
    elif terminal_name in ("alacritty",):
        cmd_parts = [terminal, "--working-directory", path]
    elif terminal_name in ("wezterm", "wezterm-gui"):
        cmd_parts = [terminal, "start", "--cwd", path]
    elif terminal_name in ("konsole",):
        cmd_parts = [terminal, "--workdir", path]
    elif terminal_name in ("foot",):
        cmd_parts = [terminal, "-D", path]
    else:
        cmd_parts = [terminal, f"--working-directory={path}"]

    if IS_NIRI:
        return ["niri", "msg", "action", "spawn", "--"] + cmd_parts
    return ["hyprctl", "dispatch", "exec", "--", *cmd_parts]


def get_directory_preview(path: str) -> str:
    """Get a preview of directory contents (first 20 items)."""
    try:
        path_obj = Path(path)
        if not path_obj.exists() or not path_obj.is_dir():
            return ""

        items = []
        for item in sorted(path_obj.iterdir())[:20]:
            suffix = "/" if item.is_dir() else ""
            items.append(f"{item.name}{suffix}")

        if len(list(path_obj.iterdir())) > 20:
            items.append("...")

        return "\n".join(items) if items else "(empty directory)"
    except (PermissionError, OSError):
        return "(permission denied)"


def dir_to_index_item(dir_info: dict) -> dict:
    """Convert directory info to indexable item format."""
    path = dir_info["path"]
    path_obj = Path(path)
    name = path_obj.name or path

    home = str(Path.home())
    if path.startswith(home):
        display_path = "~" + path[len(home) :]
    else:
        display_path = path

    path_parts = [p for p in path.lower().split("/") if p]

    preview_content = get_directory_preview(path)

    item_id = f"zoxide:{path}"
    return {
        "id": item_id,
        "name": name,
        "description": display_path,
        "icon": "folder_special",
        "keywords": path_parts,
        "verb": "Open",
        "entryPoint": {
            "step": "action",
            "selected": {"id": item_id},
        },
        "preview": {
            "type": "text",
            "content": preview_content,
            "title": name,
            "metadata": [
                {"label": "Path", "value": display_path},
            ],
        },
        "actions": [
            {
                "id": "files",
                "name": "Open in Files",
                "icon": "folder_open",
            },
            {
                "id": "copy",
                "name": "Copy Path",
                "icon": "content_copy",
            },
        ],
    }


def handle_request(input_data: dict) -> None:
    """Handle a single request."""
    step = input_data.get("step", "initial")

    if step == "index":
        mode = input_data.get("mode", "full")
        indexed_ids = set(input_data.get("indexedIds", []))

        dirs = get_zoxide_dirs()

        current_ids = {f"zoxide:{d['path']}" for d in dirs}

        if mode == "incremental":
            new_ids = current_ids - indexed_ids
            items = [
                dir_to_index_item(d) for d in dirs if f"zoxide:{d['path']}" in new_ids
            ]
            removed_ids = list(indexed_ids - current_ids)

            print(
                json.dumps(
                    {
                        "type": "index",
                        "mode": "incremental",
                        "items": items,
                        "remove": removed_ids,
                    }
                )
            )
        else:
            items = [dir_to_index_item(d) for d in dirs]
            print(json.dumps({"type": "index", "items": items}))
        return

    if step == "action":
        action_id = input_data.get("action")
        selected = input_data.get("selected", {})
        item_id = selected.get("id", "")

        if not item_id.startswith("zoxide:"):
            print(json.dumps({"type": "error", "message": "Invalid item ID"}))
            return
        path = item_id[7:]

        if not path:
            print(json.dumps({"type": "error", "message": "Missing path"}))
            return

        if action_id == "files":
            try:
                subprocess.Popen(["xdg-open", path])
                print(json.dumps({"type": "execute", "close": True}))
            except Exception as e:
                print(json.dumps({"type": "error", "message": str(e)}))
            return

        if action_id == "copy":
            try:
                subprocess.run(
                    ["wl-copy"],
                    input=path.encode(),
                    timeout=5,
                )
                print(json.dumps({"type": "execute", "close": True}))
            except Exception as e:
                print(json.dumps({"type": "error", "message": str(e)}))
            return

        try:
            cmd = make_terminal_cmd(path)
            subprocess.Popen(cmd)
            print(json.dumps({"type": "execute", "close": True}))
        except Exception as e:
            print(json.dumps({"type": "error", "message": str(e)}))
        return

    print(json.dumps({"type": "error", "message": "Invalid request"}))


def emit_full_index() -> None:
    """Emit full index of zoxide directories."""
    dirs = get_zoxide_dirs()

    items = [dir_to_index_item(d) for d in dirs]
    print(
        json.dumps({"type": "index", "mode": "full", "items": items}),
        flush=True,
    )


def main():
    import signal

    signal.signal(signal.SIGTERM, lambda s, f: sys.exit(0))
    signal.signal(signal.SIGINT, lambda s, f: sys.exit(0))

    emit_full_index()

    last_mtime = ZOXIDE_DB.stat().st_mtime if ZOXIDE_DB.exists() else 0

    while True:
        readable, _, _ = select.select([sys.stdin], [], [], POLL_INTERVAL_SECONDS)

        if readable:
            try:
                line = sys.stdin.readline()
                if not line:
                    return
                input_data = json.loads(line)
                handle_request(input_data)
                sys.stdout.flush()
            except json.JSONDecodeError:
                continue

        if ZOXIDE_DB.exists():
            current = ZOXIDE_DB.stat().st_mtime
            if current != last_mtime:
                last_mtime = current
                emit_full_index()


if __name__ == "__main__":
    main()
