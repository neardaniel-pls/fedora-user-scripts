#!/bin/bash
#
# update-searxng.sh - SearxNG repository update utility
#
# DESCRIPTION:
#   Updates a local SearxNG git clone by pulling the latest changes from the
#   official GitHub repository using fast-forward merges only. Validates the
#   remote URL, handles ownership drift from sudo/container operations, and
#   preserves real local content changes via git stash.
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
#   - Fast-forward only — no history divergence
#
# EXIT CODES: 0 success, 1 error

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ui.sh"

readonly SCRIPT_VERSION="1.0.0"

if [[ "${1:-}" == "--version" || "${1:-}" == "-V" ]]; then
    echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"
    exit 0
fi

check_dependencies() {
    local missing_deps=0 cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Dependency '$cmd' is not installed."
            missing_deps=1
        fi
    done
    if [ "$missing_deps" -eq 1 ]; then
        error "Please install missing dependencies and try again."
        exit 1
    fi
}

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

# ===== Ensure .git is writable (minimal pre-pull fix) =====
_fix_ownership() {
    local expected_owner expected_group wrong_owner

    if [ -n "${SUDO_USER:-}" ]; then
        expected_owner="$SUDO_USER"
    else
        expected_owner="$(id -un)"
    fi
    expected_group="$(id -gn "$expected_owner")"

    wrong_owner=$(find . -not -type l -not -user "$expected_owner" -print -quit 2>/dev/null)

    if [ -z "$wrong_owner" ]; then
        return 0
    fi

    if ! command -v sudo &>/dev/null; then
        error "Wrong ownership in $SEARXNG_DIR. Fix manually:"
        echo "  sudo chown -R $expected_owner:$expected_group $SEARXNG_DIR"
        exit 1
    fi

    info "Fixing ownership..."
    sudo find . -not -type l -execdir chown "$expected_owner":"$expected_group" {} +
    sudo find . -not -type l -type d -exec chmod 755 {} +
    sudo find . -not -type l -type f -exec chmod 644 {} +
    sudo find . -not -type l -type f -name "*.sh" -exec chmod 755 {} +
    success "Ownership and permissions fixed"
}

if [ ! -w ".git" ] || [ ! -w ".git/index" ] 2>/dev/null; then
    _fix_ownership
fi

# ===== Reset mode-only changes (avoid fighting chmod vs git) =====
# _fix_ownership chmod's .py files to 755, but git tracks them as 644.
# This creates 300+ spurious "modified" files. Reset mode-only diffs so
# git only sees actual content changes.
_has_content_changes() {
    git diff --numstat HEAD 2>/dev/null | awk '$1 != "0" || $2 != "0"' | grep -q .
}

# Always discard mode-only changes — they're artifacts of permission fixing
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    if ! _has_content_changes; then
        git checkout -- . >/dev/null 2>&1 || true
    fi
fi

# ===== Stash real content changes if any =====
STASHED=false
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    _stash_count_before=$(git stash list 2>/dev/null | wc -l)
    if [[ "${QUIET:-}" != "1" ]]; then
        _changed_count=$(git diff --name-only HEAD 2>/dev/null | wc -l)
        echo "  Stashing ${_changed_count} local changes before update..."
    fi
    git stash push -m "auto-stash by update-searxng.sh" >/dev/null 2>&1 || true
    _stash_count_after=$(git stash list 2>/dev/null | wc -l)
    if [ "$_stash_count_after" -gt "$_stash_count_before" ]; then
        STASHED=true
    fi
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

# ===== Pull =====
PULL_SUCCESS=false
_pull_output=$(git pull origin "$DEFAULT_BRANCH" --ff-only 2>&1) && PULL_SUCCESS=true || true

if [ "$STASHED" = true ]; then
    if ! git stash pop >/dev/null 2>&1; then
        warning "Could not restore stashed changes cleanly."
        warning "Resolve conflicts, then run 'git stash drop' to clean up."
    fi
fi

if [ "$PULL_SUCCESS" = true ]; then
    _fix_ownership
    if git diff --quiet HEAD@{1} HEAD 2>/dev/null; then
        if [[ "${QUIET:-}" != "1" ]]; then
            echo "  Already up to date."
            print_operation_end "SearxNG updated"
            success "SearxNG updated successfully"
        fi
    else
        if [[ "${QUIET:-}" != "1" ]]; then
            print_operation_end "SearxNG updated"
            success "SearxNG updated successfully"
        fi
    fi
else
    error "Failed to update."
    echo "$_pull_output"
    exit 1
fi

if [[ "${QUIET:-}" != "1" ]]; then
    print_separator
fi
