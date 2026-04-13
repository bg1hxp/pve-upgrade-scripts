#!/usr/bin/env bash
#
# pve7to8.sh — Proxmox VE 7 (Bullseye) -> 8 (Bookworm) 升级脚本
#
# 用法: bash pve7to8.sh
#
# 参考: https://pve.proxmox.com/wiki/Upgrade_from_7_to_8
#

set -euo pipefail

# ============================================================
# 颜色输出
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ============================================================
# 前置检查
# ============================================================

# 必须以 root 运行
if [[ $EUID -ne 0 ]]; then
    error "请以 root 用户运行此脚本"
    exit 1
fi

# 确认当前是 PVE 7 (Debian Bullseye)
if ! grep -q 'bullseye' /etc/os-release 2>/dev/null; then
    error "当前系统不是 Debian Bullseye (PVE 7)，中止升级"
    exit 1
fi

# 确认 pveversion 存在
if ! command -v pveversion &>/dev/null; then
    error "未检测到 pveversion 命令，确认这是 Proxmox VE 节点"
    exit 1
fi

info "当前版本: $(pveversion)"

# ============================================================
# 步骤 1: 将 PVE 7 更新到最新
# ============================================================
info "步骤 1/7: 将当前 PVE 7 更新到最新版本..."
apt update
apt dist-upgrade -y

# ============================================================
# 步骤 2: 运行 pve7to8 升级检查工具
# ============================================================
info "步骤 2/7: 运行 pve7to8 升级前检查..."
if command -v pve7to8 &>/dev/null; then
    pve7to8 --full 2>&1 | tee /tmp/pve7to8-check.log
    warn "请检查上方输出，确认没有 FAILURE 项"
    read -rp "是否继续升级? (y/N): " CONFIRM </dev/tty
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        info "用户取消升级"
        exit 0
    fi
else
    warn "pve7to8 工具不可用，请确认已安装最新 pve-manager"
    read -rp "是否跳过检查继续? (y/N): " CONFIRM </dev/tty
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        exit 0
    fi
fi

# ============================================================
# 步骤 3: 备份 APT 源配置
# ============================================================
info "步骤 3/7: 备份当前 APT 源配置..."
BACKUP_DIR="/etc/apt/backup-pve7to8-$(date +%F-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp /etc/apt/sources.list "$BACKUP_DIR/"
cp -r /etc/apt/sources.list.d/ "$BACKUP_DIR/"
info "备份已保存至 $BACKUP_DIR"

# ============================================================
# 步骤 4: 更新 APT 源到 Bookworm
# ============================================================
info "步骤 4/7: 更新 APT 源为 Bookworm..."

# 主 Debian 源
cat > /etc/apt/sources.list <<'EOF'
deb http://ftp.us.debian.org/debian bookworm main contrib
deb http://ftp.us.debian.org/debian bookworm-updates main contrib
deb http://security.debian.org/debian-security bookworm-security main contrib
EOF

# PVE no-subscription 源
cat > /etc/apt/sources.list.d/pve-no-subscription.list <<'EOF'
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

# 移除旧的 PVE 源文件（如存在）
rm -f /etc/apt/sources.list.d/pve-enterprise.list
rm -f /etc/apt/sources.list.d/pve-install-repo.list

# 如有 Ceph 源也需更新
if [[ -f /etc/apt/sources.list.d/ceph.list ]]; then
    warn "检测到 Ceph 源，将其更新为 Bookworm 版本"
    sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list.d/ceph.list
fi

# ============================================================
# 步骤 5: 更新 Proxmox GPG 密钥
# ============================================================
info "步骤 5/7: 更新 Proxmox GPG 密钥..."
wget -qO /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg \
    http://download.proxmox.com/debian/proxmox-release-bookworm.gpg

# ============================================================
# 步骤 6: 执行升级
# ============================================================
info "步骤 6/7: 开始系统升级..."
apt update
apt dist-upgrade -y

# ============================================================
# 步骤 7: 完成
# ============================================================
info "步骤 7/7: 升级完成!"
info "新版本: $(pveversion)"
echo ""
warn "请检查以下事项:"
echo "  1. 运行 'pveversion' 确认版本已更新"
echo "  2. 检查 /etc/apt/sources.list 是否正确"
echo "  3. 确认无误后执行 reboot 重启系统"
echo ""
info "建议执行: reboot"
