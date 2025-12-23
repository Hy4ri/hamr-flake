# Security Policy

## How Hamr Works

Hamr is a launcher that executes plugins. The core launcher (QML/Quickshell) does not perform privileged operations itself - it spawns plugin processes and runs commands that plugins return.

**Hamr executes what plugins tell it to execute.**

## Built-in Plugins

All built-in plugins are written in Python specifically for transparency and easy auditing. You can inspect exactly what each plugin does by reading the source code in the `plugins/` directory.

Built-in plugins only use standard system tools (`wl-copy`, `xdg-open`, `notify-send`, etc.) and do not make network requests unless explicitly required for functionality (e.g., `dict` plugin for definitions, `flathub` for app search).

## Third-Party Plugins

User-installed plugins in `~/.config/hamr/plugins/` run with your user permissions. Before installing third-party plugins:

- Review the source code
- Understand what commands it executes
- Check what data it accesses

Hamr does not sandbox plugins. A malicious plugin can do anything your user account can do.

## Reporting Security Issues

If you discover a security vulnerability in Hamr or any built-in plugin, please report it through GitHub's security advisory feature:

1. Go to https://github.com/stewart86/hamr/issues/new/choose
2. Select "Report a security vulnerability"
3. Provide details about the vulnerability

This ensures your report remains private until we can address it. We will coordinate with you on responsible disclosure.

## Disclaimer

Hamr is provided as-is. The maintainers are not responsible for damages caused by plugins, whether built-in or third-party. Users are responsible for reviewing and trusting the plugins they install and execute.
