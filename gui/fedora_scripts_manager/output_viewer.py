"""Output viewer widget — dual-mode terminal output display."""

import os
import shlex
import signal
import subprocess
import threading

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, GLib, Gdk, GObject

VTE_AVAILABLE = False
try:
    gi.require_version("Vte", "3.91")
    from gi.repository import Vte
    VTE_AVAILABLE = True
except (ValueError, ImportError):
    pass


class OutputViewer(Gtk.Box):
    """Terminal-like output viewer with dual mode support."""

    __gsignals__ = {
        "process-exited": (GObject.SignalFlags.RUN_LAST, None, (int,)),
    }

    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.set_vexpand(False)
        self.set_valign(Gtk.Align.END)

        self._process = None
        self._io_watch_id = None
        self._vte_terminal = None

        self._revealer = Gtk.Revealer()
        self._revealer.set_reveal_child(False)
        self._revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_UP)

        self._stack = Gtk.Stack()
        self._stack.set_size_request(-1, 150)

        self._build_text_view()
        if VTE_AVAILABLE:
            self._build_vte_terminal()

        self._revealer.set_child(self._stack)
        self.append(self._revealer)

        self._toolbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self._toolbar.set_margin_top(4)
        self._toolbar.set_margin_bottom(4)
        self._toolbar.set_margin_start(8)
        self._toolbar.set_margin_end(8)

        self._toggle_btn = Gtk.Button(icon_name="pan-up-symbolic")
        self._toggle_btn.set_tooltip_text("Toggle output panel")
        self._toggle_btn.connect("clicked", self._on_toggle)
        self._toolbar.append(self._toggle_btn)

        self._status_label = Gtk.Label(label="Ready")
        self._status_label.set_hexpand(True)
        self._status_label.set_xalign(0.0)
        self._status_label.add_css_class("caption")
        self._toolbar.append(self._status_label)

        self._clear_btn = Gtk.Button(icon_name="edit-clear-symbolic")
        self._clear_btn.set_tooltip_text("Clear output")
        self._clear_btn.connect("clicked", self._on_clear)
        self._toolbar.append(self._clear_btn)

        self.append(self._toolbar)

    def _build_text_view(self):
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)

        self._textview = Gtk.TextView()
        self._textview.set_editable(False)
        self._textview.set_cursor_visible(False)
        self._textview.set_wrap_mode(Gtk.WrapMode.CHAR)
        self._textview.set_monospace(True)
        self._textview.set_top_margin(8)
        self._textview.set_bottom_margin(8)
        self._textview.set_left_margin(8)
        self._textview.set_right_margin(8)
        self._textview.add_css_class("terminal-view")

        self._textbuf = self._textview.get_buffer()

        provider = Gtk.CssProvider()
        provider.load_from_data(b"""
            .terminal-view {
                background-color: #1e1e2e;
                color: #cdd6f4;
                font-size: 13px;
            }
        """)
        display = Gdk.Display.get_default()
        if display:
            Gtk.StyleContext.add_provider_for_display(
                display, provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
            )

        scrolled.set_child(self._textview)
        self._stack.add_named(scrolled, "textview")

    def _build_vte_terminal(self):
        self._vte_terminal = Vte.Terminal()
        self._vte_terminal.set_vexpand(True)
        self._stack.add_named(self._vte_terminal, "vte")

    def _on_toggle(self, _btn):
        revealed = self._revealer.get_reveal_child()
        self._revealer.set_reveal_child(not revealed)
        icon = "pan-up-symbolic" if not revealed else "pan-down-symbolic"
        self._toggle_btn.set_icon_name(icon)

    def _on_clear(self, _btn):
        self._textbuf.set_text("")

    def show(self):
        self._revealer.set_reveal_child(True)
        self._toggle_btn.set_icon_name("pan-up-symbolic")

    def set_status(self, text: str):
        self._status_label.set_text(text)

    def append_text(self, text: str):
        end_iter = self._textbuf.get_end_iter()
        self._textbuf.insert(end_iter, text)
        adj = self._textview.get_vadjustment()
        GLib.idle_add(lambda: adj.set_value(adj.get_upper()))

    def run_subprocess(self, argv: list[str], env: dict | None = None, cwd: str | None = None):
        """Run a subprocess and stream output to the TextView."""
        self._textbuf.set_text("")
        self._stack.set_visible_child_name("textview")
        self.show()

        script_name = os.path.basename(argv[-1] if "pkexec" in argv else argv[0])
        self.set_status(f"Running: {script_name}")

        self.append_text(f"$ {' '.join(argv)}\n\n")
        self.append_text("Waiting for output (some scripts buffer output until each step completes)...\n\n")

        run_env = os.environ.copy()
        run_env["NO_COLOR"] = "1"
        run_env["USE_ICONS"] = "0"
        if env:
            run_env.update(env)

        self._process = subprocess.Popen(
            argv,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            env=run_env,
            cwd=cwd,
        )

        self._reader_thread = threading.Thread(
            target=self._read_output,
            daemon=True,
        )
        self._reader_thread.start()

        return self._process

    def _read_output(self):
        """Read subprocess output in a background thread and schedule UI updates."""
        try:
            for line in self._process.stdout:
                text = line.decode("utf-8", errors="replace")
                GLib.idle_add(self.append_text, text)
        except Exception:
            pass

        self._process.wait()
        ret = self._process.returncode
        GLib.idle_add(self._on_process_done, ret)

    def _on_process_done(self, exit_code: int):
        self._process = None
        self.set_status(f"Finished (exit code: {exit_code})")
        self.emit("process-exited", exit_code)
        return False

    def run_in_vte(self, argv: list[str], env: dict | None = None, cwd: str | None = None):
        """Run a command inside the Vte terminal (for interactive scripts)."""
        if not VTE_AVAILABLE or self._vte_terminal is None:
            self._fallback_terminal(argv, env, cwd)
            self.emit("process-exited", 0)
            return

        self._stack.set_visible_child_name("vte")
        self.show()
        self.set_status(f"Running: {os.path.basename(argv[-1] if '-c' in argv else argv[0])}")

        run_env = None
        if env:
            run_env = [f"{k}={v}" for k, v in {**os.environ, **env}.items()]

        self._vte_terminal.spawn_sync(
            Vte.PtyFlags.DEFAULT,
            cwd or os.getcwd(),
            argv,
            run_env,
            GLib.SpawnFlags.SEARCH_PATH,
            None,
            None,
        )
        self._vte_terminal.connect("child-exited", self._on_vte_child_exited)

    def _on_vte_child_exited(self, terminal, status):
        self.set_status(f"Finished (exit code: {status})")
        self.emit("process-exited", status)

    def _fallback_terminal(self, argv: list[str], env: dict | None = None, cwd: str | None = None):
        """Launch in gnome-terminal as fallback."""
        cmd = " ".join(shlex.quote(a) for a in argv)
        spawn_env = os.environ.copy()
        if env:
            spawn_env.update(env)
        subprocess.Popen(
            ["gnome-terminal", "--", "bash", "-c", f"{cmd}; exec bash"],
            env=spawn_env,
            cwd=cwd,
        )
        self.set_status(f"Launched in external terminal: {os.path.basename(argv[0])}")

    def stop_process(self):
        """Stop the running subprocess (for service scripts)."""
        if self._process is not None:
            try:
                self._process.terminate()
            except ProcessLookupError:
                pass
            self.set_status("Stopped by user")

    def is_running(self) -> bool:
        return self._process is not None and self._process.poll() is None
