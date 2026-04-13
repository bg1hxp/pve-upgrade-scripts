#!/usr/bin/env bash
#
# pve7to8.sh — Proxmox VE 7 (Bullseye) -> 8 (Bookworm) Upgrade Script
#
# Usage: bash pve7to8.sh
#
# Reference: https://pve.proxmox.com/wiki/Upgrade_from_7_to_8
#

set -euo pipefail

# ============================================================
# Color output
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ============================================================
# Pre-flight checks
# ============================================================

# Must run as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
    exit 1
fi

# Verify pveversion exists
if ! command -v pveversion &>/dev/null; then
    error "pveversion not found — is this a Proxmox VE node?"
    exit 1
fi

# Verify current system is PVE 7 (Debian Bullseye)
if ! grep -q 'bullseye' /etc/os-release 2>/dev/null; then
    error "Current system is not Debian Bullseye (PVE 7), aborting"
    exit 1
fi

# Verify minimum PVE version (7.4-16+)
CURRENT_VER=$(pveversion | grep -oP 'pve-manager/\K[0-9]+\.[0-9]+-[0-9]+' || true)
if [[ -z "$CURRENT_VER" ]]; then
    error "Failed to detect PVE version"
    exit 1
fi

MAJOR_MINOR=$(echo "$CURRENT_VER" | grep -oP '^[0-9]+\.[0-9]+')
PATCH=$(echo "$CURRENT_VER" | grep -oP '(?<=-)[0-9]+$')

if ! awk "BEGIN {exit !($MAJOR_MINOR > 7.4 || ($MAJOR_MINOR == 7.4 && $PATCH >= 16))}"; then
    error "PVE version $CURRENT_VER is too old. Minimum required: 7.4-16"
    error "Please run 'apt update && apt dist-upgrade' first to update PVE 7"
    exit 1
fi

info "Current version: $(pveversion)"

# ============================================================
# Step 1: Update PVE 7 to latest
# ============================================================
info "Step 1/7: Updating current PVE 7 to latest..."
apt-get update
apt-get dist-upgrade -y

# ============================================================
# Step 2: Run pve7to8 upgrade checker
# ============================================================
info "Step 2/7: Running pve7to8 pre-upgrade checks..."
if command -v pve7to8 &>/dev/null; then
    pve7to8 --full 2>&1 | tee /tmp/pve7to8-check.log
    warn "Please review the output above — ensure there are no FAILURE items"
    read -rp "Continue with upgrade? (y/N): " CONFIRM </dev/tty
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        info "Upgrade cancelled by user"
        exit 0
    fi
else
    warn "pve7to8 tool not available — ensure pve-manager is up to date"
    read -rp "Skip checks and continue? (y/N): " CONFIRM </dev/tty
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        exit 0
    fi
fi

# ============================================================
# Step 3: Backup APT source configuration
# ============================================================
info "Step 3/7: Backing up APT source configuration..."
BACKUP_DIR="/etc/apt/backup-pve7to8-$(date +%F-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp /etc/apt/sources.list "$BACKUP_DIR/"
cp -r /etc/apt/sources.list.d/ "$BACKUP_DIR/"
info "Backup saved to $BACKUP_DIR"

# ============================================================
# Step 4: Update APT sources to Bookworm
# ============================================================
info "Step 4/7: Switching APT sources to Bookworm..."

# Main Debian sources
cat > /etc/apt/sources.list <<'EOF'
deb http://ftp.debian.org/debian bookworm main contrib
deb http://ftp.debian.org/debian bookworm-updates main contrib
deb http://security.debian.org/debian-security bookworm-security main contrib
EOF

# PVE no-subscription repository
cat > /etc/apt/sources.list.d/pve-no-subscription.list <<'EOF'
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

# Disable enterprise repository (comment out instead of deleting)
if [[ -f /etc/apt/sources.list.d/pve-enterprise.list ]]; then
    sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
    info "Disabled pve-enterprise repository"
fi

# Remove stale PVE 7 install repo if present
rm -f /etc/apt/sources.list.d/pve-install-repo.list

# Update Ceph repository if present
if [[ -f /etc/apt/sources.list.d/ceph.list ]]; then
    warn "Ceph repository detected — updating to Bookworm"
    cat > /etc/apt/sources.list.d/ceph.list <<'EOF'
# deb https://enterprise.proxmox.com/debian/ceph-quincy bookworm enterprise
deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription
EOF
fi

# ============================================================
# Step 5: Update Proxmox GPG key
# ============================================================
info "Step 5/7: Updating Proxmox GPG key..."
wget -qO /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg \
    http://download.proxmox.com/debian/proxmox-release-bookworm.gpg

# ============================================================
# Step 6: Perform upgrade
# ============================================================
info "Step 6/7: Starting system upgrade (this may take a while)..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confold" dist-upgrade -y

# ============================================================
# Step 7: Complete
# ============================================================
info "Step 7/7: Upgrade complete!"
info "New version: $(pveversion)"
echo ""
warn "Post-upgrade checklist:"
echo "  1. Run 'pveversion' to confirm the version"
echo "  2. Verify /etc/apt/sources.list is correct"
echo "  3. Reboot the system when ready"
echo ""
read -rp "Reboot now? (y/N): " REBOOT </dev/tty
if [[ "$REBOOT" == "y" || "$REBOOT" == "Y" ]]; then
    info "Rebooting..."
    sleep 2
    reboot
else
    warn "Reboot skipped — remember to reboot manually"
fi
