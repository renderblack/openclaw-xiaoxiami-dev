#!/bin/bash
# OpenClaw 每日自动备份脚本
# 执行时间：每天凌晨 2:00 (北京时间)

set -e

# 配置
WORKSPACE="/root/.openclaw/workspace"
BACKUP_DIR="/sdcard/Documents/openclawbackup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="OpenClaw_Full_Backup_${DATE}"
TEMP_DIR="/tmp/${BACKUP_NAME}"

echo "🔧 OpenClaw 每日自动备份"
echo "=========================="
echo "时间：$(date '+%Y-%m-%d %H:%M:%S')"
echo "备份名称：${BACKUP_NAME}"
echo ""

# 创建临时目录
mkdir -p "${TEMP_DIR}"
mkdir -p "${BACKUP_DIR}"

# 备份工作区文件
echo "📂 备份工作区文件..."
cp -r "${WORKSPACE}/IDENTITY.md" "${TEMP_DIR}/" 2>/dev/null || true
cp -r "${WORKSPACE}/USER.md" "${TEMP_DIR}/" 2>/dev/null || true
cp -r "${WORKSPACE}/MEMORY.md" "${TEMP_DIR}/" 2>/dev/null || true
cp -r "${WORKSPACE}/SOUL.md" "${TEMP_DIR}/" 2>/dev/null || true
cp -r "${WORKSPACE}/AGENTS.md" "${TEMP_DIR}/" 2>/dev/null || true
cp -r "${WORKSPACE}/TOOLS.md" "${TEMP_DIR}/" 2>/dev/null || true
cp -r "${WORKSPACE}/HEARTBEAT.md" "${TEMP_DIR}/" 2>/dev/null || true
cp -r "${WORKSPACE}/memory/" "${TEMP_DIR}/" 2>/dev/null || true
cp -r "${WORKSPACE}/.git/" "${TEMP_DIR}/" 2>/dev/null || true

# 备份配置文件
echo "🔧 备份配置文件..."
cp -r "/root/.openclaw/openclaw.json" "${TEMP_DIR}/" 2>/dev/null || true
cp -r "/root/.openclaw/agents/" "${TEMP_DIR}/" 2>/dev/null || true

# 创建压缩文件
echo "📦 创建压缩包..."
cd /tmp
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"

# 清理临时目录
rm -rf "${TEMP_DIR}"

# 清理旧备份 (保留最近 7 天)
echo "🧹 清理旧备份..."
find "${BACKUP_DIR}" -name "OpenClaw_Full_Backup_*.tar.gz" -mtime +7 -delete 2>/dev/null || true

# 显示备份结果
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
echo ""
echo "✅ 备份完成!"
echo "文件：${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "大小：${BACKUP_SIZE}"
echo ""

# 记录备份日志
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份完成：${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})" >> "${WORKSPACE}/memory/backup-log.md"

echo "备份日志已更新"