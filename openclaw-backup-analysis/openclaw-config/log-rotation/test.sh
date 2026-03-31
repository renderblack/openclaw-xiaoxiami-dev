#!/bin/bash

# 日志轮转测试脚本
# 用于测试日志轮转功能是否正常工作

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_ROTATE_SCRIPT="$SCRIPT_DIR/logrotate.sh"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== 日志轮转测试开始 ===${NC}"
echo "测试时间: $(date)"
echo "脚本路径: $LOG_ROTATE_SCRIPT"
echo ""

# 测试1: 检查脚本是否存在
echo -e "${YELLOW}[测试1] 检查脚本文件${NC}"
if [ -f "$LOG_ROTATE_SCRIPT" ]; then
    echo -e "${GREEN}✓ 脚本文件存在${NC}"
    echo "  文件大小: $(stat -c%s "$LOG_ROTATE_SCRIPT") bytes"
    echo "  权限: $(stat -c%A "$LOG_ROTATE_SCRIPT")"
else
    echo -e "${RED}✗ 脚本文件不存在${NC}"
    exit 1
fi

echo ""

# 测试2: 检查脚本可执行权限
echo -e "${YELLOW}[测试2] 检查可执行权限${NC}"
if [ -x "$LOG_ROTATE_SCRIPT" ]; then
    echo -e "${GREEN}✓ 脚本可执行${NC}"
else
    echo -e "${YELLOW}⚠ 脚本不可执行，尝试修复...${NC}"
    chmod +x "$LOG_ROTATE_SCRIPT"
    if [ -x "$LOG_ROTATE_SCRIPT" ]; then
        echo -e "${GREEN}✓ 权限修复成功${NC}"
    else
        echo -e "${RED}✗ 权限修复失败${NC}"
    fi
fi

echo ""

# 测试3: 检查目录结构
echo -e "${YELLOW}[测试3] 检查目录结构${NC}"
directories=(
    "/home/openclaw/.openclaw/logs"
    "/home/openclaw/.openclaw/log-rotation"
    "/home/openclaw/.openclaw/log-rotation/backups"
    "/home/openclaw/.openclaw/log-rotation/state"
)

all_dirs_ok=true
for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✓ $dir${NC}"
    else
        echo -e "  ${RED}✗ $dir (不存在)${NC}"
        all_dirs_ok=false
    fi
done

if [ "$all_dirs_ok" = true ]; then
    echo -e "${GREEN}✓ 所有目录都存在${NC}"
else
    echo -e "${YELLOW}⚠ 部分目录不存在，尝试创建...${NC}"
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo -e "  ${GREEN}✓ 创建目录: $dir${NC}"
        fi
    done
fi

echo ""

# 测试4: 创建测试日志文件
echo -e "${YELLOW}[测试4] 创建测试日志文件${NC}"
TEST_LOG="/home/openclaw/.openclaw/logs/test-rotation.log"
TEST_CONTENT="这是测试日志文件，用于验证轮转功能。\n生成时间: $(date)\n文件大小: 1KB测试数据"

echo -e "$TEST_CONTENT" > "$TEST_LOG"
# 添加更多内容使文件达到1KB
for i in {1..50}; do
    echo "测试行 $i: $(date) - 这是第 $i 行测试日志内容。" >> "$TEST_LOG"
done

if [ -f "$TEST_LOG" ]; then
    file_size=$(stat -c%s "$TEST_LOG")
    echo -e "${GREEN}✓ 测试日志文件创建成功${NC}"
    echo "  文件路径: $TEST_LOG"
    echo "  文件大小: $file_size bytes"
else
    echo -e "${RED}✗ 测试日志文件创建失败${NC}"
fi

echo ""

# 测试5: 运行日志轮转脚本（测试模式）
echo -e "${YELLOW}[测试5] 运行日志轮转脚本（测试模式）${NC}"
echo "执行命令: $LOG_ROTATE_SCRIPT"

# 先备份原始文件
cp "$TEST_LOG" "${TEST_LOG}.backup"

# 运行脚本
if bash -n "$LOG_ROTATE_SCRIPT"; then
    echo -e "${GREEN}✓ 脚本语法检查通过${NC}"
    
    # 实际运行脚本
    output=$("$LOG_ROTATE_SCRIPT" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ 脚本执行成功${NC}"
        echo "  退出代码: $exit_code"
        
        # 检查轮转结果
        rotated_file=$(find /home/openclaw/.openclaw/log-rotation/backups -name "test-rotation.log.*" -type f | head -1)
        if [ -n "$rotated_file" ]; then
            echo -e "${GREEN}✓ 日志轮转成功${NC}"
            echo "  轮转文件: $(basename "$rotated_file")"
            echo "  文件大小: $(stat -c%s "$rotated_file") bytes"
        else
            echo -e "${YELLOW}⚠ 未找到轮转后的文件${NC}"
        fi
        
        # 检查原文件是否被清空
        original_size=$(stat -c%s "$TEST_LOG" 2>/dev/null || echo "0")
        if [ "$original_size" -lt 100 ]; then  # 小于100字节
            echo -e "${GREEN}✓ 原日志文件已清空${NC}"
            echo "  清空后大小: $original_size bytes"
        else
            echo -e "${YELLOW}⚠ 原日志文件未完全清空${NC}"
            echo "  当前大小: $original_size bytes"
        fi
    else
        echo -e "${RED}✗ 脚本执行失败${NC}"
        echo "  退出代码: $exit_code"
        echo "  错误输出:"
        echo "$output" | tail -20
    fi
else
    echo -e "${RED}✗ 脚本语法检查失败${NC}"
fi

echo ""

# 测试6: 清理测试文件
echo -e "${YELLOW}[测试6] 清理测试文件${NC}"
rm -f "$TEST_LOG" "${TEST_LOG}.backup"
rm -f /home/openclaw/.openclaw/log-rotation/backups/test-rotation.log.*

if [ ! -f "$TEST_LOG" ] && [ ! -f "${TEST_LOG}.backup" ]; then
    echo -e "${GREEN}✓ 测试文件清理完成${NC}"
else
    echo -e "${YELLOW}⚠ 测试文件清理不完全${NC}"
fi

echo ""

# 测试7: 检查配置文件
echo -e "${YELLOW}[测试7] 检查配置文件${NC}"
CONFIG_FILE="$SCRIPT_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓ 配置文件存在${NC}"
    
    # 检查JSON格式
    if python3 -m json.tool "$CONFIG_FILE" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 配置文件JSON格式正确${NC}"
    else
        echo -e "${YELLOW}⚠ 配置文件JSON格式可能有问题${NC}"
    fi
else
    echo -e "${RED}✗ 配置文件不存在${NC}"
fi

echo ""
echo -e "${GREEN}=== 测试完成 ===${NC}"
echo "总结: 日志轮转系统基本功能测试完成"
echo "建议: 将日志轮转脚本添加到cron任务中，每天自动执行"
echo ""
echo "添加cron任务的命令示例:"
echo "crontab -e"
echo "添加以下行:"
echo "0 2 * * * /home/openclaw/.openclaw/log-rotation/logrotate.sh >> /home/openclaw/.openclaw/log-rotation/state/cron.log 2>&1"