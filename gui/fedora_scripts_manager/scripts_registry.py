"""Script registry — metadata for all fedora-user-scripts."""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class ScriptType(Enum):
    ONE_SHOT = "one_shot"
    SERVICE = "service"
    INTERACTIVE = "interactive"


class SudoMode(Enum):
    NONE = "none"
    ENFORCED = "enforced"
    INTERNAL = "internal"


@dataclass
class ScriptOption:
    id: str
    label: str
    cli_flag: str
    description: str
    option_type: str = "toggle"
    default: bool = False
    requires_confirm: bool = False
    confirm_message: str = ""


@dataclass
class ScriptEntry:
    id: str
    name: str
    description: str
    category: str
    icon_name: str
    script_path: str
    script_type: ScriptType
    sudo_mode: SudoMode
    options: list[ScriptOption] = field(default_factory=list)
    requires_file_arg: bool = False
    file_arg_label: str = ""
    file_arg_optional: bool = False
    file_arg_default: str = ""


CATEGORIES = [
    ("maintenance", "Maintenance"),
    ("security", "Security"),
    ("ai", "AI"),
    ("hardware", "Hardware"),
    ("searxng", "SearXNG"),
]

SCRIPTS: list[ScriptEntry] = [
    ScriptEntry(
        id="clean-metadata",
        name="Clean Metadata",
        description="Remove metadata and optimize PDF, PNG, and JPEG files for privacy",
        category="maintenance",
        icon_name="edit-clear-all-symbolic",
        script_path="scripts/maintenance/clean-metadata.sh",
        script_type=ScriptType.ONE_SHOT,
        sudo_mode=SudoMode.NONE,
        options=[
            ScriptOption(
                id="clean",
                label="Clean Only",
                cli_flag="--clean",
                description="Only remove metadata without optimization",
            ),
            ScriptOption(
                id="optimize",
                label="Optimize Only",
                cli_flag="--optimize",
                description="Only optimize without removing metadata",
            ),
            ScriptOption(
                id="replace",
                label="Replace Original",
                cli_flag="--replace",
                description="Replace original files instead of creating copies",
                requires_confirm=True,
                confirm_message="This will overwrite your original files. Continue?",
            ),
            ScriptOption(
                id="verbose",
                label="Verbose",
                cli_flag="--verbose",
                description="Show metadata before cleaning",
            ),
        ],
        requires_file_arg=True,
        file_arg_label="Files or directories to process",
    ),
    ScriptEntry(
        id="fedora-update",
        name="Fedora Update",
        description="Comprehensive system maintenance: packages, Flatpaks, and optional SearXNG update",
        category="maintenance",
        icon_name="system-software-update-symbolic",
        script_path="scripts/maintenance/fedora-update.sh",
        script_type=ScriptType.INTERACTIVE,
        sudo_mode=SudoMode.ENFORCED,
    ),
    ScriptEntry(
        id="clean-downloads",
        name="Clean Downloads",
        description="Organize Downloads into categorized subdirectories and optionally purge old files",
        category="maintenance",
        icon_name="folder-download-symbolic",
        script_path="scripts/maintenance/clean-downloads.sh",
        script_type=ScriptType.ONE_SHOT,
        sudo_mode=SudoMode.NONE,
        options=[
            ScriptOption(
                id="organize",
                label="Organize",
                cli_flag="--organize",
                description="Sort files into categorized subdirectories (default action)",
            ),
            ScriptOption(
                id="purge_enable",
                label="Purge Old Files",
                cli_flag="--purge",
                description="Enable removing files older than specified days",
            ),
            ScriptOption(
                id="purge_days",
                label="Purge Age (days)",
                cli_flag="__purge_days",
                description="Number of days threshold for purge",
                option_type="spin",
            ),
            ScriptOption(
                id="dry_run",
                label="Dry Run",
                cli_flag="--dry-run",
                description="Preview changes without making them",
            ),
        ],
        requires_file_arg=True,
        file_arg_label="Directory to organize",
        file_arg_optional=True,
        file_arg_default="~/Downloads",
    ),
    ScriptEntry(
        id="update-hosts",
        name="Update Hosts",
        description="Update StevenBlack hosts file with configurable ad-blocking extensions",
        category="maintenance",
        icon_name="network-workgroup-symbolic",
        script_path="scripts/maintenance/update-hosts.sh",
        script_type=ScriptType.INTERACTIVE,
        sudo_mode=SudoMode.ENFORCED,
        options=[
            ScriptOption(
                id="auto",
                label="Auto Flush DNS",
                cli_flag="--auto",
                description="Automatically flush DNS cache after updating hosts file",
            ),
        ],
    ),
    ScriptEntry(
        id="security-sweep",
        name="Security Sweep",
        description="Comprehensive security scans: integrity, rootkit, malware, audit, and package checks",
        category="security",
        icon_name="security-high-symbolic",
        script_path="scripts/security/security-sweep.sh",
        script_type=ScriptType.ONE_SHOT,
        sudo_mode=SudoMode.ENFORCED,
        options=[
            ScriptOption(
                id="integrity",
                label="Integrity Check",
                cli_flag="-i",
                description="RPM package integrity verification (rpm -Va)",
                default=True,
            ),
            ScriptOption(
                id="rootkit",
                label="Rootkit Scan",
                cli_flag="-r",
                description="Scan for rootkits with chkrootkit",
                default=True,
            ),
            ScriptOption(
                id="malware",
                label="Malware Scan",
                cli_flag="-m",
                description="Scan for malware with ClamAV",
                default=True,
            ),
            ScriptOption(
                id="audit",
                label="Security Audit",
                cli_flag="-a",
                description="Run Lynis security audit",
                default=True,
            ),
            ScriptOption(
                id="packages",
                label="Package Check",
                cli_flag="-p",
                description="Check for broken dependencies with dnf",
                default=True,
            ),
            ScriptOption(
                id="exclude_home",
                label="Exclude Home",
                cli_flag="-e",
                description="Exclude /home and /root directories from scans",
            ),
        ],
    ),
    ScriptEntry(
        id="secure-delete",
        name="Secure Delete",
        description="Securely delete files by overwriting with random data (3-pass shred)",
        category="security",
        icon_name="user-trash-symbolic",
        script_path="scripts/security/secure-delete.sh",
        script_type=ScriptType.ONE_SHOT,
        sudo_mode=SudoMode.NONE,
        requires_file_arg=True,
        file_arg_label="Files or directories to securely delete",
    ),
    ScriptEntry(
        id="update-ollama-openwebui",
        name="Update Ollama and Open WebUI",
        description="Update Ollama binary and Open Web UI container with automatic backup support",
        category="ai",
        icon_name="software-update-available-symbolic",
        script_path="scripts/ai/update-ollama-openwebui.sh",
        script_type=ScriptType.ONE_SHOT,
        sudo_mode=SudoMode.INTERNAL,
        options=[
            ScriptOption(
                id="backup_only",
                label="Backup Only",
                cli_flag="--backup-only",
                description="Only create a backup without updating",
            ),
            ScriptOption(
                id="restore",
                label="Restore",
                cli_flag="--restore",
                description="Restore from a backup (requires Restore Date to be set)",
            ),
            ScriptOption(
                id="restore_date",
                label="Restore Date",
                cli_flag="--restore-date",
                description="Backup timestamp to restore (YYYYMMDD-HHMMSS), used with Restore",
                option_type="entry",
            ),
            ScriptOption(
                id="no_backup",
                label="Skip Backup",
                cli_flag="--no-backup",
                description="Update without creating a backup (not recommended)",
                requires_confirm=True,
                confirm_message="No backup will be created before updating. Continue?",
            ),
        ],
    ),
    ScriptEntry(
        id="start-ollama-openwebui",
        name="Start Ollama and Open WebUI",
        description="Start Ollama service and Open Web UI container; stops on window close",
        category="ai",
        icon_name="media-playback-start-symbolic",
        script_path="scripts/ai/start-ollama-openwebui.sh",
        script_type=ScriptType.SERVICE,
        sudo_mode=SudoMode.INTERNAL,
    ),
    ScriptEntry(
        id="drive-check",
        name="Drive Check",
        description="Read-only drive inspector: device info, USB speed, capacity, SMART health, and partitions",
        category="hardware",
        icon_name="drive-harddisk-symbolic",
        script_path="scripts/hardware/drive-check.sh",
        script_type=ScriptType.ONE_SHOT,
        sudo_mode=SudoMode.ENFORCED,
        options=[
            ScriptOption(
                id="health",
                label="SMART Health",
                cli_flag="--health",
                description="Show extended SMART attributes (wear leveling, realloc sectors, etc.)",
            ),
        ],
        requires_file_arg=True,
        file_arg_label="Block device path (e.g. /dev/sdb)",
    ),
    ScriptEntry(
        id="run-searxng",
        name="Run SearXNG",
        description="Launch SearXNG privacy-respecting metasearch engine on a local port",
        category="searxng",
        icon_name="system-search-symbolic",
        script_path="scripts/searxng/run-searxng.sh",
        script_type=ScriptType.SERVICE,
        sudo_mode=SudoMode.NONE,
        options=[
            ScriptOption(
                id="verbose",
                label="Verbose",
                cli_flag="--verbose",
                description="Show all SearXNG output including non-critical warnings",
            ),
        ],
    ),
    ScriptEntry(
        id="update-searxng",
        name="Update SearXNG",
        description="Update local SearXNG repository via fast-forward pull from GitHub",
        category="searxng",
        icon_name="software-update-available-symbolic",
        script_path="scripts/searxng/update-searxng.sh",
        script_type=ScriptType.ONE_SHOT,
        sudo_mode=SudoMode.NONE,
    ),
]


def get_scripts_by_category(category: str) -> list[ScriptEntry]:
    return [s for s in SCRIPTS if s.category == category]


def get_script_by_id(script_id: str) -> Optional[ScriptEntry]:
    for s in SCRIPTS:
        if s.id == script_id:
            return s
    return None
