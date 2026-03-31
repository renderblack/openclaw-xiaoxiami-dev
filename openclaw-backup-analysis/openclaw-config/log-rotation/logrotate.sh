#!/bin/bash

# OpenClaw 自定义日志轮转脚本
# 作者：小龙虾🦞
# 日期：2026-03-26
# 功能：按天轮转，保留30天，压缩旧日志

set -e

# 配置变量
LOG_DIR="/home/openclaw/.openclaw/logs"
ROTATION_DIR="/home/openclaw/.openclaw/log-rotation"
BACKUP_DIR="$ROTATION_DIR/backups"
RETENTION_DAYS=30
COMPRESS_DAYS=7  # 7天前的日志进行压缩

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 检查目录
check_directories() {
    if [ ! -d "$LOG_DIR" ]; then
        log_error "日志目录不存在: $LOG_DIR"
        exit 1
    fi
    
    # 创建必要的目录
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$ROTATION_DIR/state"
    
    log_info "目录检查完成"
}

# 获取当前日志文件列表
get_log_files() {
    find "$LOG_DIR" -type f -name "*.log" -o -name "*.jsonl" -o -name "*.txt" | grep -v ".gz$" | grep -v ".bz2$"
}

# 轮转单个日志文件
rotate_log_file() {
    local log_file="$1"
    local log_name=$(basename "$log_file")
    local log_date=$(date +"%Y%m%d")
    local rotated_file="$BACKUP_DIR/${log_name}.${log_date}"
    
    log_debug "处理日志文件: $log_name"
    
    # 如果文件为空或很小，跳过轮转
    local file_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
    if [ "$file_size" -lt 1024 ]; then  # 小于1KB
        log_debug "文件太小 ($file_size bytes)，跳过轮转"
        return 0
    fi
    
    # 复制日志文件到备份目录
    cp "$log_file" "$rotated_file"
    
    # 清空原日志文件
    > "$log_file"
    
    # 记录轮转状态
    echo "$(date -Iseconds) $log_name -> ${log_name}.${log_date} (${file_size} bytes)" >> "$ROTATION_DIR/state/rotation.log"
    
    log_info "轮转完成: $log_name -> ${log_name}.${log_date}"
}

# 压缩旧日志文件
compress_old_logs() {
    log_info "开始压缩旧日志文件（${COMPRESS_DAYS}天前）..."
    
    local compressed_count=0
    
    # 查找需要压缩的文件（未压缩且超过指定天数）
    find "$BACKUP_DIR" -type f -mtime +$COMPRESS_DAYS ! -name "*.gz" ! -name "*.bz2" | while read -r file; do
        local file_name=$(basename "$file")
        
        # 检查文件大小，太小的不压缩
        local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        if [ "$file_size" -lt 10240 ]; then  # 小于10KB
            log_debug "文件太小 ($file_size bytes)，跳过压缩: $file_name"
            continue
        fi
        
        # 使用gzip压缩
        if gzip -9 "$file"; then
            log_info "压缩成功: $file_name.gz"
            compressed_count=$((compressed_count + 1))
        else
            log_warn "压缩失败: $file_name"
        fi
    done
    
    log_info "压缩完成，共处理 $compressed_count 个文件"
}

# 清理过期日志文件
cleanup_expired_logs() {
    log_info "开始清理过期日志文件（${RETENTION_DAYS}天前）..."
    
    local deleted_count=0
    
    # 删除超过保留期限的文件（包括压缩文件）
    find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS | while read -r file; do
        local file_name=$(basename "$file")
        
        if rm -f "$file"; then
            log_info "删除过期文件: $file_name"
            deleted_count=$((deleted_count + 1))
        else
            log_warn "删除失败: $file_name"
        fi
    done
    
    log_info "清理完成，共删除 $deleted_count 个过期文件"
}

# 生成报告
generate_report() {
    local report_file="$ROTATION_DIR/state/report_$(date +%Y%m%d).txt"
    
    cat > "$report_file" << EOF
=== 日志轮转报告 ===
执行时间: $(date)
日志目录: $LOG_DIR
备份目录: $BACKUP_DIR

=== 当前状态 ===
原始日志文件数: $(get_log_files | wc -l)
备份文件总数: $(find "$BACKUP_DIR" -type f | wc -l)
压缩文件数: $(find "$BACKUP_DIR" -type f -name "*.gz" | wc -l)

=== 磁盘使用 ===
日志目录大小: $(du -sh "$LOG_DIR" | cut -f1)
备份目录大小: $(du -sh "$BACKUP_DIR" | cut -f1)
总使用空间: $(du -sh "$LOG_DIR" "$BACKUP_DIR" | tail -1 | cut -f1)

=== 保留策略 ===
保留天数: $RETENTION_DAYS 天
压缩天数: $COMPRESS_DAYS 天前开始压缩
下次清理: $(date -d "+1 day" +%Y-%m-%d)
EOF
    
    log_info "报告已生成: $(basename "$report_file")"
}

# 主函数
main() {
    log_info "=== OpenClaw 日志轮转脚本 ==="
    log_info "开始时间: $(date)"
    log_info "保留策略: ${RETENTION_DAYS}天"
    log_info "压缩策略: ${COMPRESS_DAYS}天前开始压缩"
    
    # 检查目录
    check_directories
    
    # 获取日志文件列表
    local log_files=$(get_log_files)
    local file_count=$(echo "$log_files" | wc -l)
    
    if [ "$file_count" -eq 0 ]; then
        log_warn "未找到需要轮转的日志文件"
    else
        log_info "找到 $file_count 个日志文件需要处理"
        
        # 轮转每个日志文件
        echo "$log_files" | while read -r log_file; do
            rotate_log_file "$log_file"
        done
    fi
    
    # 压缩旧日志
    compress_old_logs
    
    # 清理过期日志
    cleanup_expired_logs
    
    # 生成报告
    generate_report
    
    log_info "=== 日志轮转完成 ==="
    log_info "结束时间: $(date)"
}

# 执行主函数
main "$@"