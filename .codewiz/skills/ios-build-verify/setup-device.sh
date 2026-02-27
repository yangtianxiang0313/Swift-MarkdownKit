#!/bin/bash

# iOS Device Setup Script
# 快速查询并设置 iPhone X 设备 ID

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/config.json"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📱 iOS Device Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 检查 Xcode 是否安装
if ! command -v xcrun &> /dev/null; then
    echo -e "${RED}❌ 错误: 未找到 xcrun，请确保已安装 Xcode${NC}"
    exit 1
fi

echo -e "\n${YELLOW}🔍 扫描连接的 iOS 设备...${NC}"

# 尝试多种方式获取设备列表
devices=""

# 方式 1: 使用 xcrun xctrace list devices
if command -v xcrun &> /dev/null; then
    devices=$(xcrun xctrace list devices 2>/dev/null | grep -i "iphone" | grep -v "simulator" || true)
fi

# 方式 2: 如果方式 1 失败，使用 system_profiler
if [ -z "$devices" ]; then
    devices=$(system_profiler SPUSBDataType 2>/dev/null | grep -A 2 "iPhone" | grep "Serial Number" || true)
fi

# 方式 3: 使用 idevice_id
if [ -z "$devices" ] && command -v idevice_id &> /dev/null; then
    devices=$(idevice_id -l 2>/dev/null || true)
fi

if [ -z "$devices" ]; then
    echo -e "${RED}❌ 未检测到连接的 iOS 真机设备${NC}"
    echo -e "${YELLOW}💡 请确保:${NC}"
    echo "   1. iPhone 已通过 USB 连接到电脑"
    echo "   2. 在 iPhone 上信任此电脑"
    echo "   3. Xcode 已安装并更新"
    echo ""
    echo -e "${YELLOW}或者手动设置设备 ID:${NC}"
    echo "   编辑 config.json，将 deviceId 改为你的设备 ID"
    exit 1
fi

echo -e "${GREEN}✅ 检测到以下设备:${NC}"
echo ""

# 显示所有设备
device_count=0
declare -a device_ids
declare -a device_names

while IFS= read -r line; do
    if [ -n "$line" ]; then
        device_count=$((device_count + 1))
        
        # 提取设备名称和 ID
        device_name=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d'(' -f1 | xargs)
        device_id=$(echo "$line" | grep -oE '[A-F0-9]{8}-[A-F0-9]{16}' | head -1)
        
        # 如果没有找到标准格式的 ID，尝试其他格式
        if [ -z "$device_id" ]; then
            device_id=$(echo "$line" | grep -oE '[A-F0-9]{40}' | head -1)
        fi
        
        # 如果还是没有，使用整行作为 ID
        if [ -z "$device_id" ]; then
            device_id=$(echo "$line" | xargs)
        fi
        
        device_names[$device_count]="$device_name"
        device_ids[$device_count]="$device_id"
        
        echo "   [$device_count] $device_name"
        if [ -n "$device_id" ]; then
            echo "       ID: $device_id"
        fi
        echo ""
    fi
done <<< "$devices"

if [ $device_count -eq 0 ]; then
    echo -e "${RED}❌ 无法解析设备信息${NC}"
    exit 1
fi

# 如果只有一个设备，直接使用
if [ $device_count -eq 1 ]; then
    selected_id=${device_ids[1]}
    selected_name=${device_names[1]}
    echo -e "${GREEN}✅ 自动选择唯一的设备: $selected_name${NC}"
else
    # 多个设备，让用户选择
    echo -e "${YELLOW}请选择要使用的设备 (输入数字):${NC}"
    read -p "选择 [1-$device_count]: " choice
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $device_count ]; then
        echo -e "${RED}❌ 无效的选择${NC}"
        exit 1
    fi
    
    selected_id=${device_ids[$choice]}
    selected_name=${device_names[$choice]}
    echo -e "${GREEN}✅ 已选择: $selected_name${NC}"
fi

# 更新配置文件
echo -e "\n${YELLOW}📝 更新配置文件...${NC}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ 配置文件不存在: $CONFIG_FILE${NC}"
    exit 1
fi

# 使用 sed 更新 deviceId
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/\"deviceId\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"deviceId\": \"$selected_id\"/" "$CONFIG_FILE"
else
    # Linux
    sed -i "s/\"deviceId\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"deviceId\": \"$selected_id\"/" "$CONFIG_FILE"
fi

echo -e "${GREEN}✅ 配置文件已更新${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 设置完成!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "设备信息:"
echo "  名称: $selected_name"
echo "  ID:   $selected_id"
echo ""
echo -e "配置文件: $CONFIG_FILE"
echo ""
echo -e "${YELLOW}现在可以运行编译:${NC}"
echo "  bash .codewiz/skills/ios-build-verify/build.sh"
echo ""
