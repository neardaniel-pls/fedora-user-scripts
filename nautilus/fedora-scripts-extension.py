#!/usr/bin/env python3
"""Nautilus context menu extension for clean-metadata.sh.

Adds "Clean Metadata" to the right-click context menu when one or more
PDF, PNG, or JPEG files are selected in Nautilus.
"""

import os
import stat
import subprocess
import tempfile

from gi.repository import Nautilus, GObject

SUPPORTED_MIMES = {
    "application/pdf",
    "image/png",
    "image/jpeg",
}

CONFIG_PATH = os.path.join(
    os.path.expanduser("~"), ".config", "fedora-user-scripts", "config.sh"
)


def _is_config_safe(path):
    try:
        st = os.stat(path)
        if st.st_mode & stat.S_IWOTH or st.st_mode & stat.S_IWGRP:
            return False
        if st.st_uid != os.getuid():
            return False
        return True
    except OSError:
        return False


def _get_scripts_dir():
    default = os.path.join(
        os.path.expanduser("~"), "Documents", "code", "fedora-user-scripts"
    )
    env_val = os.environ.get("FEDORA_SCRIPTS_DIR", "")
    if env_val and os.path.isdir(env_val):
        return env_val
    if os.path.isfile(CONFIG_PATH) and _is_config_safe(CONFIG_PATH):
        try:
            result = subprocess.run(
                ["bash", "-c", f"source '{CONFIG_PATH}' && echo \"$FEDORA_SCRIPTS_DIR\""],
                capture_output=True, text=True, timeout=5,
            )
            val = result.stdout.strip()
            if val and os.path.isdir(val):
                return val
        except Exception:
            pass
    return default


def _get_script_path():
    return os.path.join(_get_scripts_dir(), "scripts", "maintenance", "clean-metadata.sh")


class CleanMetadataExtension(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()

    def _clean_metadata(self, _menu_item, files):
        script = _get_script_path()
        if not os.path.isfile(script):
            self._notify("Clean Metadata", "Script not found. Please run setup.sh first.", "dialog-error")
            return

        file_paths = []
        for f in files:
            path = f.get_location().get_path()
            if path:
                file_paths.append(path)

        if not file_paths:
            return

        log_fd, log_file = tempfile.mkstemp(suffix=".log", prefix="clean-metadata-")
        os.close(log_fd)

        env = os.environ.copy()
        env["NO_COLOR"] = "1"
        env["USE_ICONS"] = "0"

        argv = [script, "--"] + file_paths

        try:
            result = subprocess.run(
                argv,
                capture_output=True,
                text=True,
                env=env,
                timeout=600,
            )

            with open(log_file, "w") as lf:
                lf.write(result.stdout)
                if result.stderr:
                    lf.write("\n--- STDERR ---\n")
                    lf.write(result.stderr)

            if result.returncode == 0:
                count = len(file_paths)
                self._notify(
                    "Clean Metadata",
                    f"{count} file{'s' if count > 1 else ''} processed successfully.",
                    "dialog-information",
                )
            else:
                self._notify(
                    "Clean Metadata",
                    f"Errors occurred. See log: {log_file}",
                    "dialog-error",
                )
        except subprocess.TimeoutExpired:
            self._notify("Clean Metadata", "Operation timed out.", "dialog-error")
        except Exception as e:
            self._notify("Clean Metadata", f"Error: {e}", "dialog-error")

    def _notify(self, title, body, icon_name="dialog-information"):
        try:
            subprocess.run(
                ["notify-send", "-i", icon_name, title, body],
                timeout=5,
            )
        except Exception:
            pass

    def get_file_items(self, *args):
        files = args[-1]

        has_supported = False
        for f in files:
            mime = f.get_mime_type()
            if mime in SUPPORTED_MIMES:
                has_supported = True
                break

        if not has_supported:
            return []

        item = Nautilus.MenuItem(
            name="CleanMetadataExtension::CleanMetadata",
            label="Clean Metadata",
            tip="Remove metadata from selected files",
            icon="edit-clear-all-symbolic",
        )
        item.connect("activate", self._clean_metadata, files)
        return [item]

    def get_background_items(self, *args):
        return []
