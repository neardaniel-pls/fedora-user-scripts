"""Main application window — assembles sidebar, script cards, and output viewer."""

import os
import stat
import subprocess

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, Gio, GObject

from .scripts_registry import (
    SCRIPTS, CATEGORIES, ScriptEntry, ScriptType, SudoMode,
)
from .script_card import ScriptCard
from .output_viewer import OutputViewer


def _is_config_safe(path: str) -> bool:
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


class MainWindow(Adw.ApplicationWindow):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.set_title("Fedora Scripts Manager")
        self.set_default_size(900, 700)

        self._cards: dict[str, ScriptCard] = {}
        self._active_card_id: str | None = None
        self._scripts_dir = self._resolve_scripts_dir()
        self._populating = False

        self._build_ui()
        self._populate_scripts("all")

    def _resolve_scripts_dir(self) -> str:
        default = os.path.join(os.path.expanduser("~"), "Documents", "code", "fedora-user-scripts")
        env_val = os.environ.get("FEDORA_SCRIPTS_DIR", "")
        if env_val and os.path.isdir(env_val):
            return env_val
        config_path = os.path.join(
            os.path.expanduser("~"), ".config", "fedora-user-scripts", "config.sh"
        )
        if os.path.isfile(config_path) and _is_config_safe(config_path):
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
        return default

    def _build_ui(self):
        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        header = Adw.HeaderBar()
        header.add_css_class("flat")
        content_box.append(header)

        self._split_view = Adw.NavigationSplitView()
        self._split_view.set_vexpand(True)

        sidebar_page = self._build_sidebar()
        self._split_view.set_sidebar(sidebar_page)

        content_page = self._build_content_page()
        self._split_view.set_content(content_page)

        content_box.append(self._split_view)

        self._output_viewer = OutputViewer()
        self._output_viewer.connect("process-exited", self._on_process_exited)
        content_box.append(self._output_viewer)

        toast_overlay = Adw.ToastOverlay()
        toast_overlay.set_child(content_box)
        self._toast_overlay = toast_overlay

        self.set_content(toast_overlay)

    def _build_sidebar(self):
        self._category_list = Gtk.ListBox()
        self._category_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self._category_list.add_css_class("navigation-sidebar")
        self._category_list.connect("row-selected", self._on_category_selected)

        all_row = Gtk.ListBoxRow()
        all_row.set_child(Gtk.Label(label="All Scripts", xalign=0.0))
        all_row.category_id = "all"
        self._category_list.append(all_row)

        for cat_id, cat_name in CATEGORIES:
            row = Gtk.ListBoxRow()
            label_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            count = sum(1 for s in SCRIPTS if s.category == cat_id)
            name_label = Gtk.Label(label=cat_name, xalign=0.0)
            name_label.set_hexpand(True)
            count_label = Gtk.Label(label=str(count))
            count_label.add_css_class("caption")
            count_label.add_css_class("dim-label")
            label_box.append(name_label)
            label_box.append(count_label)
            row.set_child(label_box)
            row.category_id = cat_id
            self._category_list.append(row)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_child(self._category_list)
        scrolled.set_vexpand(True)

        sidebar_content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        sidebar_content.set_size_request(200, -1)

        sidebar_header = Adw.HeaderBar()
        sidebar_header.set_title_widget(Gtk.Label(label="Categories"))
        sidebar_header.add_css_class("flat")
        sidebar_content.append(sidebar_header)
        sidebar_content.append(scrolled)

        page = Adw.NavigationPage(title="Categories")
        page.set_child(sidebar_content)

        return page

    def _build_content_page(self):
        self._scripts_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self._scripts_list.set_margin_top(12)
        self._scripts_list.set_margin_bottom(12)
        self._scripts_list.set_margin_start(16)
        self._scripts_list.set_margin_end(16)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_vexpand(True)
        scrolled.set_child(self._scripts_list)

        clamp = Adw.Clamp()
        clamp.set_maximum_size(700)
        clamp.set_child(scrolled)

        page = Adw.NavigationPage(title="Scripts")
        page.set_child(clamp)

        return page

    def _populate_scripts(self, category: str = "all"):
        self._populating = True

        child = self._scripts_list.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            self._scripts_list.remove(child)
            child = next_child

        scripts = SCRIPTS if category == "all" else [s for s in SCRIPTS if s.category == category]

        if not scripts:
            empty = Adw.StatusPage(
                title="No Scripts",
                description="No scripts found in this category.",
            )
            empty.set_vexpand(True)
            self._scripts_list.append(empty)
            self._populating = False
            return

        current_cat = None
        for script in scripts:
            if category == "all" and script.category != current_cat:
                current_cat = script.category
                cat_label = Gtk.Label(label=current_cat.title())
                cat_label.add_css_class("heading")
                cat_label.set_halign(Gtk.Align.START)
                cat_label.set_margin_top(8)
                self._scripts_list.append(cat_label)

            if script.id not in self._cards:
                card = ScriptCard(script)
                card.connect("run-requested", self._on_run_requested)
                card.connect("stop-requested", self._on_stop_requested)
                self._cards[script.id] = card
            self._scripts_list.append(self._cards[script.id])

        self._populating = False

    def _on_category_selected(self, list_box, row):
        if row is None or self._populating:
            return
        self._populate_scripts(row.category_id)

    def _on_run_requested(self, card: ScriptCard, script_id: str):
        entry = card.get_entry()
        cli_args = card.get_cli_args()

        script_full_path = os.path.join(self._scripts_dir, entry.script_path)
        if not os.path.isfile(script_full_path):
            self._show_toast(f"Script not found: {entry.script_path}", error=True)
            card.set_status("Script not found", success=False)
            return

        resolved = os.path.realpath(script_full_path)
        expected_prefix = os.path.realpath(self._scripts_dir)
        if not resolved.startswith(expected_prefix + os.sep):
            self._show_toast("Invalid script path", error=True)
            card.set_status("Invalid path", success=False)
            return

        argv = [script_full_path] + cli_args

        if entry.sudo_mode == SudoMode.ENFORCED:
            user_home = os.path.expanduser("~")
            user_name = os.environ.get("USER", "")
            argv = [
                "pkexec", "env",
                f"HOME={user_home}",
                f"SUDO_USER={user_name}",
                f"HOSTS_REPO_PATH={user_home}/Documents/code/hosts",
            ] + argv

        card.set_running(True)
        self._active_card_id = script_id
        self._set_all_cards_sensitive(False, except_id=script_id)

        env = {
            "FEDORA_SCRIPTS_DIR": self._scripts_dir,
            "SUDO_USER": os.environ.get("USER", ""),
        }
        if entry.sudo_mode == SudoMode.ENFORCED:
            env["HOME"] = os.path.expanduser("~")

        if entry.script_type == ScriptType.INTERACTIVE:
            self._output_viewer.run_in_vte(argv, env=env)
        else:
            self._output_viewer.run_subprocess(argv, env=env)

    def _on_stop_requested(self, card: ScriptCard, script_id: str):
        self._output_viewer.stop_process()
        card.set_running(False)
        self._set_all_cards_sensitive(True)

    def _on_process_exited(self, viewer, exit_code: int):
        if self._active_card_id and self._active_card_id in self._cards:
            card = self._cards[self._active_card_id]
            card.set_running(False)
            success = exit_code == 0
            card.set_status("Success" if success else f"Failed (code {exit_code})", success=success)
        self._active_card_id = None
        self._set_all_cards_sensitive(True)

    def _set_all_cards_sensitive(self, sensitive: bool, except_id: str | None = None):
        for sid, card in self._cards.items():
            if sid != except_id:
                card.set_sensitive(sensitive)

    def _show_toast(self, message: str, error: bool = False):
        toast = Adw.Toast(title=message, timeout=3)
        if error:
            toast.add_css_class("error")
        self._toast_overlay.add_toast(toast)
