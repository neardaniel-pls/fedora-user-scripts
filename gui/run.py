#!/usr/bin/env python3
"""Launcher script for Fedora Scripts Manager."""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fedora_scripts_manager.main import main

if __name__ == "__main__":
    main()
