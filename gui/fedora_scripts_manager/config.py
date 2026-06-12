"""Shared config resolution — scripts directory discovery."""

import os
import stat
import subprocess


def is_config_safe(path: str) -> bool:
    """Check that a config file is owned by the user and not world/group writable."""
    try:
        st = os.stat(path)
        if st.st_mode & stat.S_IWOTH or st.st_mode & stat.S_IWGRP:
            return False
        if st.st_uid != os.getuid():
            return False
        return True
    except OSError:
        return False


def resolve_scripts_dir() -> str:
    """Resolve the fedora-user-scripts directory using the standard fallback chain."""
    env_val = os.environ.get("FEDORA_SCRIPTS_DIR", "")
    if env_val and os.path.isdir(env_val):
        return env_val
    config_path = os.path.join(
        os.path.expanduser("~"), ".config", "fedora-user-scripts", "config.sh"
    )
    if os.path.isfile(config_path) and is_config_safe(config_path):
        try:
            result = subprocess.run(
                ["bash", "-c", f"source '{config_path}' && echo \"$FEDORA_SCRIPTS_DIR\""],
                capture_output=True, text=True, timeout=5,
            )
            val = result.stdout.strip()
            if val and os.path.isdir(val):
                return val
        except Exception:
            pass
    home = os.path.expanduser("~")
    candidates = [
        os.path.join(home, ".local", "share", "fedora-scripts-manager"),
    ]
    for c in candidates:
        if os.path.isdir(c):
            return c
    return os.path.join(home, "Documents", "code", "fedora-user-scripts")
