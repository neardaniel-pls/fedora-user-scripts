#!/bin/bash
#
# update-searxng.sh - SearxNG repository update utility
#
# DESCRIPTION:
#   Updates a local SearxNG git clone by hard-syncing it to the latest commit on
#   the official GitHub repository's default branch. Validates the remote URL,
#   handles ownership drift from sudo/container operations, and discards local
#   tracked changes so the clone always matches upstream exactly. Untracked
#   files (e.g. a custom settings_user.yml) are preserved.
#
# USAGE:
#   ./update-searxng.sh
#
# DEPENDENCIES:
#   - git, standard Unix utilities
#   - SearxNG clone at ~/Documents/code/searxng/searxng/ (or set SEARXNG_DIR)
#
# SECURITY:
#   - Remote URL validated before any sudo operations
#   - Permission fixes skip symlinks to prevent traversal attacks
#   - Hard-syncs to validated remote (no history divergence, no force-push)
#
# EXIT CODES: 0 success, 1 error

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CLI_ARG1="${1:-}"
source "${SCRIPT_DIR}/../lib/ui.sh"

readonly SCRIPT_VERSION="1.3.3"
version_check "$SCRIPT_VERSION"

if [[ "${QUIET:-}" != "1" ]]; then
    print_header "SEARXNG UPDATE"
fi

# ===== Configuration =====
_DEFAULT_SEARXNG_DIR="$(_get_user_home)/Documents/code/searxng/searxng"
SEARXNG_DIR="${SEARXNG_DIR:-$_DEFAULT_SEARXNG_DIR}"

check_dependencies git

# ===== Directory + Repository Validation =====
if [ ! -d "$SEARXNG_DIR" ]; then
    error "Directory $SEARXNG_DIR not found."
    exit 1
fi

cd "$SEARXNG_DIR" || exit 1

if [ ! -d ".git" ]; then
    error "Not a git repository: $SEARXNG_DIR"
    exit 1
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ ! "$REMOTE_URL" =~ ^https?://github\.com[:/]searxng/searxng(\.git)?$ ]]; then
    error "Unexpected git remote: $REMOTE_URL"
    echo "This script only updates the official SearxNG repository."
    exit 1
fi

if [[ "${QUIET:-}" != "1" ]]; then
    print_operation_start "Updating SearxNG"
fi

# ===== Detect default branch =====
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
if [ -z "$DEFAULT_BRANCH" ]; then
    if git rev-parse --verify origin/main >/dev/null 2>&1; then
        DEFAULT_BRANCH="main"
    elif git rev-parse --verify origin/master >/dev/null 2>&1; then
        DEFAULT_BRANCH="master"
    else
        error "Cannot determine default branch."
        exit 1
    fi
fi

# ===== Report local changes that will be discarded =====
# This clone tracks upstream only, so tracked local edits (content + mode) are
# always discarded. Untracked files (e.g. a custom settings_user.yml) are kept.
# Count tracked modifications only -- ignore untracked ('??') entries.
_dirty_count=$(git status --porcelain 2>/dev/null | grep -cv '^??' || true)
if [ "${_dirty_count:-0}" -gt 0 ]; then
    warning "Discarding ${_dirty_count} local change(s) - hard-syncing to upstream."
fi

# ===== Ensure .git is writable (needed for fetch + reset) =====
if [ ! -w ".git" ] || [ ! -w ".git/index" ] 2>/dev/null; then
    fix_ownership "."
fi

_LOCAL_HEAD=$(git rev-parse HEAD)

# ===== Fetch from upstream =====
if ! _fetch_out=$(git fetch origin 2>&1); then
    error "Failed to fetch from upstream."
    echo "$_fetch_out"
    exit 1
fi

_REMOTE_HEAD=$(git rev-parse "origin/${DEFAULT_BRANCH}")

# Warn about local commits ahead of upstream BEFORE discarding them.
# (Working-tree edits are already warned about above via _dirty_count.)
_ahead=$(git rev-list --count "${_REMOTE_HEAD}..${_LOCAL_HEAD}" 2>/dev/null || echo 0)
if [ "${_ahead:-0}" -gt 0 ]; then
    warning "Discarding ${_ahead} local commit(s) ahead of upstream (recoverable via git reflog)."
fi

# ===== Hard reset to upstream =====
# A hard reset also neutralizes mode-only artifacts from fix_ownership, so no
# separate chmod-vs-git workaround is needed.
if ! git reset --hard "origin/${DEFAULT_BRANCH}" >/dev/null 2>&1; then
    error "Failed to sync to origin/${DEFAULT_BRANCH}."
    exit 1
fi

# ===== Report result (based on actual HEAD movement) =====
_forward=$(git rev-list --count "${_LOCAL_HEAD}..${_REMOTE_HEAD}" 2>/dev/null || echo 0)
_backward=$(git rev-list --count "${_REMOTE_HEAD}..${_LOCAL_HEAD}" 2>/dev/null || echo 0)
if [[ "${QUIET:-}" != "1" ]]; then
    if [ "$_LOCAL_HEAD" = "$_REMOTE_HEAD" ]; then
        echo "  Already up to date."
    elif [ "$_backward" -eq 0 ]; then
        echo "  Updated: ${_forward} new commit(s) (now at $(git rev-parse --short HEAD))."
    elif [ "$_forward" -eq 0 ]; then
        echo "  Rewound to upstream: discarded ${_backward} local commit(s) (now at $(git rev-parse --short HEAD))."
    else
        echo "  Synced: ${_forward} new commit(s), discarded ${_backward} local commit(s) (now at $(git rev-parse --short HEAD))."
    fi
    print_operation_end "SearxNG updated"
    success "SearxNG updated successfully"
fi

fix_ownership "."

if [[ "${QUIET:-}" != "1" ]]; then
    print_separator
fi
