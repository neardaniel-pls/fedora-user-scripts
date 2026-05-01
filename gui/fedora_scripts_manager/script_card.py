"""Script card widget — displays a single script with options and run button."""

import os
import re

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GObject

from .scripts_registry import ScriptEntry, ScriptType, SudoMode


class ScriptCard(Adw.ExpanderRow):
    """Card widget for a single script entry."""

    __gsignals__ = {
        "run-requested": (GObject.SignalFlags.RUN_LAST, None, (str,)),
        "stop-requested": (GObject.SignalFlags.RUN_LAST, None, (str,)),
    }

    def __init__(self, entry: ScriptEntry):
        super().__init__()
        self._entry = entry
        self._running = False
        self._option_widgets = {}
        self._file_chooser_row = None
        self._file_paths = []

        self.set_title(entry.name)
        self.set_subtitle(entry.description)
        self.set_icon_name(entry.icon_name)

        self._build_options()
        self._build_file_arg()
        self._build_action_row()

    def _build_options(self):
        for opt in self._entry.options:
            if opt.option_type == "toggle":
                row = Adw.SwitchRow(title=opt.label, subtitle=opt.description)
                row.set_active(opt.default)
                self.add_row(row)
                self._option_widgets[opt.id] = row
            elif opt.option_type == "spin":
                adj = Gtk.Adjustment(value=30, lower=1, upper=365, step_increment=1)
                row = Adw.SpinRow(title=opt.label, subtitle=opt.description, adjustment=adj)
                self.add_row(row)
                self._option_widgets[opt.id] = row
            elif opt.option_type == "entry":
                row = Adw.EntryRow(title=opt.label)
                row.set_tooltip_text(opt.description)
                self.add_row(row)
                self._option_widgets[opt.id] = row

    def _build_file_arg(self):
        if not self._entry.requires_file_arg:
            return

        row = Adw.ActionRow(title=self._entry.file_arg_label)
        if self._entry.file_arg_optional and self._entry.file_arg_default:
            row.set_subtitle(f"Default: {self._entry.file_arg_default}")

        self._file_label = Gtk.Label(label="(none selected)")
        self._file_label.set_ellipsize(3)
        self._file_label.set_max_width_chars(30)
        self._file_label.add_css_class("caption")
        row.add_suffix(self._file_label)

        btn = Gtk.Button(icon_name="document-open-symbolic")
        btn.set_valign(Gtk.Align.CENTER)
        btn.set_tooltip_text("Browse")
        btn.connect("clicked", self._on_browse)
        row.add_suffix(btn)

        self._file_chooser_row = row
        self.add_row(row)

    def _build_action_row(self):
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        box.set_margin_top(6)
        box.set_margin_bottom(6)
        box.set_margin_start(12)
        box.set_margin_end(12)

        self._status_icon = Gtk.Image(icon_name="folder-symbolic")
        self._status_icon.set_pixel_size(16)
        box.append(self._status_icon)

        self._status_label = Gtk.Label(label="")
        self._status_label.add_css_class("caption")
        box.append(self._status_label)

        spacer = Gtk.Label(label="")
        spacer.set_hexpand(True)
        box.append(spacer)

        if self._entry.script_type == ScriptType.SERVICE:
            self._run_btn = Gtk.ToggleButton(label="Start")
            self._run_btn.add_css_class("suggested-action")
            self._run_btn.connect("toggled", self._on_start_stop)
        else:
            self._run_btn = Gtk.Button(label="Run")
            self._run_btn.add_css_class("suggested-action")
            self._run_btn.connect("clicked", self._on_run)

        if self._entry.sudo_mode == SudoMode.ENFORCED:
            lock_icon = Gtk.Image(icon_name="changes-allow-symbolic")
            lock_icon.set_pixel_size(14)
            self._run_btn.set_tooltip_text("Requires administrator privileges")

        box.append(self._run_btn)

        row = Adw.ActionRow()
        row.set_child(box)
        self.add_row(row)

    def _on_browse(self, _btn):
        if self._entry.id == "drive-check":
            dialog = self._create_device_dialog()
        else:
            dialog = self._create_file_dialog()

        parent = self.get_root()
        if parent:
            dialog.present(parent)

    def _create_file_dialog(self):
        if self._entry.id in ("secure-delete",):
            dialog = Gtk.FileDialog()
            dialog.set_title(self._entry.file_arg_label)
            dialog.set_modal(True)
            dialog.open_multiple(None, None, self._on_files_selected, None)
            return None
        else:
            dialog = Gtk.FileDialog()
            dialog.set_title(self._entry.file_arg_label)
            dialog.set_modal(True)
            dialog.open(None, None, self._on_file_selected, None)
            return None

    def _create_device_dialog(self):
        row = Adw.EntryRow(title="Block device path (e.g. /dev/sdb)")
        self._option_widgets["_device_path"] = row

        content = Adw.PreferencesGroup()
        content.add(row)

        dialog = Adw.MessageDialog(
            heading="Select Block Device",
            body="Enter the block device path to inspect.",
        )
        dialog.set_extra_child(content)
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("ok", "OK")
        dialog.set_response_appearance("ok", Adw.ResponseAppearance.SUGGESTED)
        dialog.connect("response", self._on_device_response, row)
        return dialog

    def _on_file_selected(self, source, result, _data):
        try:
            file = source.open_finish(result)
            if file:
                path = file.get_path()
                self._file_paths = [path]
                self._file_label.set_label(os.path.basename(path))
        except GLib.Error:
            pass

    def _on_files_selected(self, source, result, _data):
        try:
            files = source.open_multiple_finish(result)
            self._file_paths = []
            names = []
            if files:
                for f in files:
                    path = f.get_path()
                    self._file_paths.append(path)
                    names.append(os.path.basename(path))
            self._file_label.set_label(", ".join(names) if names else "(none selected)")
        except GLib.Error:
            pass

    def _on_device_response(self, _dialog, response_id, row):
        if response_id == "ok":
            path = row.get_text().strip()
            if not path:
                return
            if not re.match(r'^/dev/[a-zA-Z0-9/]+$', path):
                self._file_label.set_label("Invalid device path")
                self._file_paths = []
                return
            self._file_paths = [path]
            self._file_label.set_label(path)

    def _on_run(self, _btn):
        for opt in self._entry.options:
            if opt.requires_confirm:
                widget = self._option_widgets.get(opt.id)
                if widget and hasattr(widget, "get_active") and widget.get_active():
                    self._show_confirm(opt.confirm_message, opt.id)
                    return
        self.emit("run-requested", self._entry.id)

    def _show_confirm(self, message: str, opt_id: str):
        parent = self.get_root()
        if not parent:
            return
        dialog = Adw.MessageDialog(
            heading="Confirm Action",
            body=message,
        )
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("confirm", "Continue")
        dialog.set_response_appearance("confirm", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.connect("response", self._on_confirm_response)
        dialog.present(parent)

    def _on_confirm_response(self, _dialog, response_id):
        if response_id == "confirm":
            self.emit("run-requested", self._entry.id)

    def _on_start_stop(self, toggle):
        if toggle.get_active():
            toggle.set_label("Stop")
            toggle.remove_css_class("suggested-action")
            toggle.add_css_class("destructive-action")
            self.emit("run-requested", self._entry.id)
        else:
            toggle.set_label("Start")
            toggle.remove_css_class("destructive-action")
            toggle.add_css_class("suggested-action")
            self.emit("stop-requested", self._entry.id)

    def set_running(self, running: bool):
        self._running = running
        if self._entry.script_type != ScriptType.SERVICE:
            self._run_btn.set_sensitive(not running)
            self._run_btn.set_label("Running..." if running else "Run")
        if running:
            self._status_icon.set_from_icon_name("content-loading-symbolic")
            self._status_label.set_label("Running")
        else:
            self._status_icon.set_from_icon_name("emblem-ok-symbolic")
            self._status_label.set_label("")

    def set_status(self, status: str, success: bool = True):
        icon = "emblem-ok-symbolic" if success else "dialog-error-symbolic"
        self._status_icon.set_from_icon_name(icon)
        self._status_label.set_label(status)

    def get_cli_args(self) -> list[str]:
        """Build the CLI argument list from current option states."""
        args = []
        purge_days_val = None
        for opt in self._entry.options:
            widget = self._option_widgets.get(opt.id)
            if widget is None:
                continue
            if opt.option_type == "toggle":
                if hasattr(widget, "get_active") and widget.get_active():
                    if opt.cli_flag.startswith("__"):
                        pass
                    else:
                        args.append(opt.cli_flag)
            elif opt.option_type == "spin":
                if hasattr(widget, "get_value"):
                    purge_days_val = str(int(widget.get_value()))
            elif opt.option_type == "entry":
                if hasattr(widget, "get_text"):
                    text = widget.get_text().strip()
                    if text:
                        if opt.id == "restore_date" and not re.match(r'^\d{8}-\d{6}$', text):
                            continue
                        args.extend([opt.cli_flag, text])

        if "--purge" in args and purge_days_val is not None:
            args.append(purge_days_val)

        if self._file_paths:
            args.extend(self._file_paths)
        return args

    def get_entry(self) -> ScriptEntry:
        return self._entry
