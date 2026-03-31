#!/bin/bash
# OpenClaw 备份脚本
# 执行时间：每天凌晨2:00（北京时间）

set -e

BACKUP_ROOT="$HOME/.openclaw/backups"
DATE=$(date +%Y%m%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 创建临时目录
TEMP_DIR="/tmp/openclaw-backup-$TIMESTAMP"
mkdir -p "$TEMP_DIR"

echo "=== OpenClaw 备份开始 $(date) ==="

# 1. 备份配置文件
echo "备份配置文件..."
mkdir -p "$TEMP_DIR/config"
cp -r "$HOME/.openclaw/openclaw.json" "$TEMP_DIR/config/" 2>/dev/null || true
cp -r "$HOME/.openclaw/workspace/" "$TEMP_DIR/config/workspace-backup/" 2>/dev/null || true

# 2. 备份日志文件（最近7天）
echo "备份日志文件..."
mkdir -p "$TEMP_DIR/logs"
find "$HOME/.openclaw/logs/" -name "*.log" -mtime -7 -exec cp {} "$TEMP_DIR/logs/" \; 2>/dev/null || true

# 3. 备份日志轮转配置
echo "备份日志轮转配置..."
mkdir -p "$TEMP_DIR/log-rotation"
cp -r "$HOME/.openclaw/log-rotation/" "$TEMP_DIR/log-rotation/" 2>/dev/null || true

# 4. 备份技能配置
echo "备份技能配置..."
mkdir -p "$TEMP_DIR/skills"
cp -r "$HOME/.nvm/versions/node/v22.22.1/lib/node_modules/openclaw/skills/" "$TEMP_DIR/skills/" 2>/dev/null || true

# 创建压缩包
echo "创建压缩包..."
cd "$TEMP_DIR"
tar -czf "$BACKUP_ROOT/daily/backup-$TIMESTAMP.tar.gz" .

# 清理临时目录
cd /
rm -rf "$TEMP_DIR"

# 清理旧备份（保留最近7天）
echo "清理旧备份..."
find "$BACKUP_ROOT/daily/" -name "*.tar.gz" -mtime +7 -delete 2>/dev/null || true

# 每周备份（每周日）
if [ $(date +%u) -eq 7 ]; then
    echo "创建每周备份..."
    cp "$BACKUP_ROOT/daily/backup-$TIMESTAMP.tar.gz" "$BACKUP_ROOT/weekly/weekly-backup-$DATE.tar.gz"
    find "$BACKUP_ROOT/weekly/" -name "*.tar.gz" -mtime +28 -delete 2>/dev/null || true
fi

# 每月备份（每月1号）
if [ $(date +%d) -eq 1 ]; then
    echo "创建每月备份..."
    cp "$BACKUP_ROOT/daily/backup-$TIMESTAMP.tar.gz" "$BACKUP_ROOT/monthly/monthly-backup-$(date +%Y%m).tar.gz"
    find "$BACKUP_ROOT/monthly/" -name "*.tar.gz" -mtime +365 -delete 2>/dev/null || true
fi

# 配置文件单独备份
echo "备份配置文件..."
cp "$HOME/.openclaw/openclaw.json" "$BACKUP_ROOT/config/openclaw-config-$TIMESTAMP.json" 2>/dev/null || true
find "$BACKUP_ROOT/config/" -name "*.json" -mtime +30 -delete 2>/dev/null || true

echo "=== 备份完成 $(date) ==="
echo "备份文件: $BACKUP_ROOT/daily/backup-$TIMESTAMP.tar.gz"
echo "大小: $(du -h "$BACKUP_ROOT/daily/backup-$TIMESTAMP.tar.gz" | cut -f1)"

exit 0