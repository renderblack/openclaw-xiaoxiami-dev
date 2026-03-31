#!/bin/bash

# 日志恢复脚本
# 用于从备份中恢复日志文件

set -e

# 配置变量
BACKUP_DIR="/home/openclaw/.openclaw/log-rotation/backups"
LOG_DIR="/home/openclaw/.openclaw/logs"
RESTORE_DIR="/home/openclaw/.openclaw/log-rotation/restored"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示备份文件列表
list_backups() {
    echo -e "${BLUE}=== 可用的备份文件 ===${NC}"
    
    local backup_files=$(find "$BACKUP_DIR" -type f -name "*.log.*" | sort)
    
    if [ -z "$backup_files" ]; then
        echo "未找到备份文件"
        return
    fi
    
    local count=1
    echo "$backup_files" | while read -r file; do
        local file_name=$(basename "$file")
        local file_date=$(echo "$file_name" | grep -oE '[0-9]{8}' || echo "未知日期")
        local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        local is_compressed=""
        
        if [[ "$file_name" == *.gz ]]; then
            is_compressed="(压缩)"
        fi
        
        printf "%-3d %-40s %-10s %-10s %s\n" \
            "$count" \
            "$file_name" \
            "$file_date" \
            "$(numfmt --to=iec --suffix=B "$file_size")" \
            "$is_compressed"
        
        count=$((count + 1))
    done
}

# 恢复单个文件
restore_file() {
    local backup_file="$1"
    local target_name="$2"
    
    if [ ! -f "$backup_file" ]; then
        log_error "备份文件不存在: $backup_file"
        return 1
    fi
    
    # 创建恢复目录
    mkdir -p "$RESTORE_DIR"
    
    local restore_path="$RESTORE_DIR/$target_name"
    
    # 如果是压缩文件，先解压
    if [[ "$backup_file" == *.gz ]]; then
        log_info "解压文件: $(basename "$backup_file")"
        gunzip -c "$backup_file" > "$restore_path"
    else
        cp "$backup_file" "$restore_path"
    fi
    
    if [ -f "$restore_path" ]; then
        local file_size=$(stat -c%s "$restore_path")
        log_info "恢复成功: $target_name ($(numfmt --to=iec --suffix=B "$file_size"))"
        echo "$restore_path"
    else
        log_error "恢复失败: $target_name"
        return 1
    fi
}

# 按日期恢复
restore_by_date() {
    local date_pattern="$1"
    local file_pattern="$2"
    
    log_info "查找日期为 $date_pattern 的备份文件..."
    
    local backup_files=$(find "$BACKUP_DIR" -type f -name "*${file_pattern}*${date_pattern}*" | sort)
    
    if [ -z "$backup_files" ]; then
        log_warn "未找到日期为 $date_pattern 的备份文件"
        return
    fi
    
    local restored_count=0
    echo "$backup_files" | while read -r backup_file; do
        local original_name=$(basename "$backup_file" | sed 's/\.[0-9]\{8\}//' | sed 's/\.gz$//')
        local restore_name="restored_${original_name}"
        
        if restore_file "$backup_file" "$restore_name" > /dev/null; then
            restored_count=$((restored_count + 1))
        fi
    done
    
    log_info "按日期恢复完成，共恢复 $restored_count 个文件"
}

# 按文件名恢复
restore_by_name() {
    local name_pattern="$1"
    
    log_info "查找文件名为 *$name_pattern* 的备份文件..."
    
    local backup_files=$(find "$BACKUP_DIR" -type f -name "*${name_pattern}*" | sort)
    
    if [ -z "$backup_files" ]; then
        log_warn "未找到文件名为 *$name_pattern* 的备份文件"
        return
    fi
    
    local restored_count=0
    echo "$backup_files" | while read -r backup_file; do
        local file_name=$(basename "$backup_file")
        local restore_name="restored_${file_name}"
        
        if restore_file "$backup_file" "$restore_name" > /dev/null; then
            restored_count=$((restored_count + 1))
        fi
    done
    
    log_info "按文件名恢复完成，共恢复 $restored_count 个文件"
}

# 恢复所有文件
restore_all() {
    log_info "恢复所有备份文件..."
    
    local backup_files=$(find "$BACKUP_DIR" -type f -name "*.log.*" | sort)
    
    if [ -z "$backup_files" ]; then
        log_warn "未找到任何备份文件"
        return
    fi
    
    local restored_count=0
    echo "$backup_files" | while read -r backup_file; do
        local file_name=$(basename "$backup_file")
        local restore_name="restored_${file_name}"
        
        if restore_file "$backup_file" "$restore_name" > /dev/null; then
            restored_count=$((restored_count + 1))
        fi
    done
    
    log_info "全部恢复完成，共恢复 $restored_count 个文件"
}

# 显示恢复的文件
show_restored_files() {
    if [ ! -d "$RESTORE_DIR" ] || [ -z "$(ls -A "$RESTORE_DIR" 2>/dev/null)" ]; then
        log_warn "恢复目录为空"
        return
    fi
    
    echo -e "${BLUE}=== 已恢复的文件 ===${NC}"
    
    local restored_files=$(find "$RESTORE_DIR" -type f | sort)
    local count=1
    
    echo "$restored_files" | while read -r file; do
        local file_name=$(basename "$file")
        local file_size=$(stat -c%s "$file")
        
        printf "%-3d %-40s %-10s\n" \
            "$count" \
            "$file_name" \
            "$(numfmt --to=iec --suffix=B "$file_size")"
        
        count=$((count + 1))
    done
    
    local total_size=$(du -sh "$RESTORE_DIR" | cut -f1)
    local file_count=$(find "$RESTORE_DIR" -type f | wc -l)
    
    echo ""
    echo "总计: $file_count 个文件，总大小: $total_size"
}

# 清理恢复目录
clean_restore_dir() {
    if [ -d "$RESTORE_DIR" ]; then
        log_info "清理恢复目录..."
        rm -rf "$RESTORE_DIR"
        log_info "恢复目录已清理"
    fi
}

# 显示使用说明
show_usage() {
    cat << EOF
${BLUE}=== 日志恢复脚本使用说明 ===${NC}

用法: $0 [选项]

选项:
  list              列出所有备份文件
  restore-all       恢复所有备份文件
  restore-date YYYYMMDD  恢复指定日期的备份文件
  restore-name NAME 恢复包含指定名称的备份文件
  show-restored     显示已恢复的文件
  clean             清理恢复目录
  help              显示此帮助信息

示例:
  $0 list                    # 列出所有备份
  $0 restore-all             # 恢复所有备份
  $0 restore-date 20260326   # 恢复2026年3月26日的备份
  $0 restore-name gateway    # 恢复包含'gateway'的日志文件
  $0 show-restored           # 显示已恢复的文件
  $0 clean                   # 清理恢复目录

注意:
  1. 恢复的文件会保存在: $RESTORE_DIR
  2. 压缩文件会自动解压
  3. 恢复前建议先列出备份文件确认
EOF
}

# 主函数
main() {
    echo -e "${BLUE}=== OpenClaw 日志恢复工具 ===${NC}"
    echo "备份目录: $BACKUP_DIR"
    echo "恢复目录: $RESTORE_DIR"
    echo ""
    
    case "${1:-help}" in
        list)
            list_backups
            ;;
        restore-all)
            restore_all
            show_restored_files
            ;;
        restore-date)
            if [ -z "$2" ]; then
                log_error "请指定日期 (格式: YYYYMMDD)"
                show_usage
                exit 1
            fi
            restore_by_date "$2"
            show_restored_files
            ;;
        restore-name)
            if [ -z "$2" ]; then
                log_error "请指定文件名模式"
                show_usage
                exit 1
            fi
            restore_by_name "$2"
            show_restored_files
            ;;
        show-restored)
            show_restored_files
            ;;
        clean)
            clean_restore_dir
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "未知选项: $1"
            show_usage
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"