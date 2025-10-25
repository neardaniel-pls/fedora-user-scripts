#!/bin/bash
# This script automates BleachBit using its command-line interface.

# List all the available cleaners
# bleachbit --list-cleaners

# Run BleachBit with a set of cleaners
# Add or remove cleaners as needed
bleachbit --clean \
  # System Cleaners
  system.cache \                  # Clear system cache
  system.clipboard \              # Clear clipboard content
  # system.custom \                 # Delete custom files and folders
  # system.free_disk_space \        # Overwrite free disk space to hide deleted files
  system.memory \                 # Clear system memory and swap
  # system.recent_documents \       # Clear the list of recently used documents
  system.rotated_logs \           # Delete rotated system logs
  system.tmp \                    # Delete temporary files
  system.trash \                  # Empty the trash can

  # Shell Cleaners
  # bash.history \                  # Clear Bash command history

  # Deep Scan Cleaners
  # deep_scan.backup \              # Delete backup files
  deep_scan.ds_store \            # Delete macOS .DS_Store files
  deep_scan.thumbs_db \           # Delete Windows thumbnail cache files
  deep_scan.tmp \                 # Delete temporary files found by deep scan

  # Firefox Cleaners
  firefox.cache \                 # Clear Firefox cache
  firefox.cookies \               # Delete Firefox cookies
  firefox.crash_reports \         # Delete Firefox crash reports
  firefox.dom_storage \           # Clear Firefox DOM storage
  firefox.download_history \      # Clear Firefox download history
  firefox.forms \                 # Clear saved form history in Firefox
  firefox.passwords \             # Delete saved passwords in Firefox
  firefox.session_restore \       # Clear Firefox session restore data
  firefox.site_preferences \      # Delete Firefox site-specific preferences
  firefox.url_history \           # Clear Firefox browsing history

  # Google Chrome Cleaners
  google_chrome.cache \           # Clear Google Chrome cache
  google_chrome.cookies \         # Delete Google Chrome cookies
  google_chrome.dom_storage \     # Clear Google Chrome DOM storage
  google_chrome.form_history \    # Clear saved form history in Google Chrome
  google_chrome.history \         # Clear Google Chrome browsing history
  google_chrome.passwords \       # Delete saved passwords in Google Chrome
  google_chrome.search_engines \  # Clear custom search engines in Google Chrome
  google_chrome.session \         # Clear Google Chrome session data

  # Thunderbird Cleaners
  thunderbird.cache \             # Clear Thunderbird cache
  thunderbird.cookies \           # Delete Thunderbird cookies
  thunderbird.junk_logs \         # Delete Thunderbird junk mail logs
  thunderbird.passwords \         # Delete saved passwords in Thunderbird
  thunderbird.url_history \       # Clear Thunderbird URL history

  # VLC Media Player Cleaner
  vlc.mru \                       # Clear VLC's list of most recently used files

  # X11 Cleaner
  x11.debug_logs                  # Delete X11 debug logs