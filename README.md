# Proxmox VE 升级脚本

一键升级 Proxmox VE 的自动化脚本集合。

## 脚本列表

| 脚本 | 说明 |
|------|------|
| `pve7to8.sh` | Proxmox VE 7 (Bullseye) → 8 (Bookworm) |

## 使用说明

### PVE 7 → 8 升级

#### 前置条件

- 已运行 Proxmox VE 7.x（基于 Debian 11 Bullseye）
- 拥有 root 权限
- **已备份所有虚拟机和重要数据**
- 如为集群环境，确保所有节点健康且无正在运行的 HA 迁移

#### 快速开始

在 PVE 节点上以 root 执行：

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bg1hxp/pve-upgrade-scripts/main/pve7to8.sh)"
```

#### 手动执行

如果你希望先查看脚本内容再执行：

```bash
# 1. 下载脚本
wget https://raw.githubusercontent.com/bg1hxp/pve-upgrade-scripts/main/pve7to8.sh

# 2. 查看脚本内容（可选）
cat pve7to8.sh

# 3. 以 root 执行
bash pve7to8.sh

# 4. 升级完成后按提示重启
reboot
```

#### 脚本执行流程

1. **环境检查** — 确认当前系统为 PVE 7 / Debian Bullseye
2. **更新当前系统** — 确保 PVE 7 已是最新版本
3. **运行 pve7to8 检查工具** — 官方升级前检查，需用户确认无 FAILURE 后继续
4. **备份 APT 源** — 将当前源配置备份到 `/etc/apt/backup-pve7to8-<timestamp>/`
5. **切换到 Bookworm 源** — 更新 Debian 源、PVE 源，移除旧源文件
6. **更新 GPG 密钥** — 获取 Proxmox Bookworm 签名密钥
7. **执行 dist-upgrade** — 完成系统升级

#### 注意事项

- 脚本使用 `ftp.us.debian.org` 作为 Debian 镜像源，如需使用其他镜像请编辑脚本
- 集群环境请**逐节点升级**，不要同时升级所有节点
- 升级前务必确认 `pve7to8 --full` 检查无 FAILURE 项
- 如有 Ceph 存储，脚本会自动更新 Ceph 源
- enterprise 源会被自动移除（适用于无订阅用户）

## 回滚

脚本会自动备份 APT 源配置。如需回滚：

```bash
# 找到备份目录
ls /etc/apt/backup-pve7to8-*/

# 恢复备份
cp /etc/apt/backup-pve7to8-<timestamp>/sources.list /etc/apt/sources.list
cp /etc/apt/backup-pve7to8-<timestamp>/sources.list.d/* /etc/apt/sources.list.d/
apt update
```

> **注意：** APT 源回滚仅在 `dist-upgrade` 执行前有效。一旦系统包已升级，无法通过简单恢复源来降级系统。

## 参考文档

- [Proxmox 官方升级指南: PVE 7 to 8](https://pve.proxmox.com/wiki/Upgrade_from_7_to_8)

## License

MIT
