# Proxmox VE Upgrade Scripts

[English](#proxmox-ve-upgrade-scripts) | [中文](README_zh.md)

Automated scripts for upgrading Proxmox VE between major versions.

## Scripts

| Script | Description |
|--------|-------------|
| `pve7to8.sh` | Proxmox VE 7 (Bullseye) → 8 (Bookworm) |

## Usage

### PVE 7 → 8 Upgrade

#### Prerequisites

- Running Proxmox VE **7.4-16 or higher** (Debian 11 Bullseye)
- Root access
- **All VMs and important data backed up**
- For cluster environments, ensure all nodes are healthy with no active HA migrations

#### Quick Start

Run as root on your PVE node:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bg1hxp/pve-upgrade-scripts/main/pve7to8.sh)"
```

#### Manual Execution

If you prefer to review the script before running:

```bash
# 1. Download the script
wget https://raw.githubusercontent.com/bg1hxp/pve-upgrade-scripts/main/pve7to8.sh

# 2. Review the script (optional)
cat pve7to8.sh

# 3. Run as root
bash pve7to8.sh

# 4. Reboot after upgrade completes
reboot
```

#### What the Script Does

1. **Environment check** — Verifies PVE 7 / Debian Bullseye, minimum version 7.4-16
2. **Update current system** — Ensures PVE 7 is fully up to date
3. **Run pve7to8 checker** — Official pre-upgrade check; requires user confirmation before proceeding
4. **Backup APT sources** — Saves current config to `/etc/apt/backup-pve7to8-<timestamp>/`
5. **Switch to Bookworm repos** — Updates Debian, PVE, Ceph sources; disables enterprise repo
6. **Update GPG key** — Fetches the Proxmox Bookworm release key
7. **Run dist-upgrade** — Performs upgrade with `--force-confold` to keep existing configs

#### Important Notes

- The script uses `ftp.debian.org` as the Debian mirror. Edit the script if you need a different mirror.
- For clusters, upgrade **one node at a time** — never all nodes simultaneously.
- Ensure `pve7to8 --full` reports no FAILURE items before proceeding.
- If Ceph storage is detected, the script automatically updates the Ceph repository to `ceph-quincy`.
- The enterprise repository is **commented out** (not deleted), so subscription users can re-enable it easily.
- Uses `DEBIAN_FRONTEND=noninteractive` and `--force-confold` to avoid interactive dpkg prompts during upgrade.

## Rollback

The script automatically backs up your APT source configuration. To roll back:

```bash
# Find the backup directory
ls /etc/apt/backup-pve7to8-*/

# Restore the backup
cp /etc/apt/backup-pve7to8-<timestamp>/sources.list /etc/apt/sources.list
cp /etc/apt/backup-pve7to8-<timestamp>/sources.list.d/* /etc/apt/sources.list.d/
apt update
```

> **Note:** Rolling back APT sources is only effective before `dist-upgrade` runs. Once packages have been upgraded, restoring sources alone will not downgrade the system.

## References

- [Proxmox Official Upgrade Guide: PVE 7 to 8](https://pve.proxmox.com/wiki/Upgrade_from_7_to_8)

## License

MIT
