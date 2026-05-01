"""Application entry point — Adw.Application with About dialog."""

import sys

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, Gio

from . import __version__
from .window import MainWindow


class FedoraScriptsManagerApp(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id="org.fedoraproscripts.Manager",
            flags=Gio.ApplicationFlags.FLAGS_NONE,
        )
        self._window = None

    def do_activate(self):
        if self._window is None:
            self._window = MainWindow(application=self)
        self._window.present()

    def do_startup(self):
        Adw.Application.do_startup(self)

        about_action = Gio.SimpleAction.new("about", None)
        about_action.connect("activate", self._on_about)
        self.add_action(about_action)

        quit_action = Gio.SimpleAction.new("quit", None)
        quit_action.connect("activate", lambda _a, _p: self.quit())
        self.add_action(quit_action)

        self.set_accels_for_action("app.quit", ["<Ctrl>q"])

    def _on_about(self, _action, _param):
        about = Adw.AboutWindow(
            transient_for=self._window,
            application_name="Fedora Scripts Manager",
            application_icon="system-run-symbolic",
            version=__version__,
            comments="A GUI for managing and running fedora-user-scripts",
            website="https://github.com/near-whisper/fedora-user-scripts",
            license_type=Gtk.License.MIT_X11,
            copyright="© 2025 fedora-user-scripts contributors",
        )
        about.present()


def main():
    app = FedoraScriptsManagerApp()
    app.run(sys.argv)


if __name__ == "__main__":
    main()
