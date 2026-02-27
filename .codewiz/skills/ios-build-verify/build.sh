#!/bin/bash

# iOS Build Verification Script
# 直接使用配置文件中的设备 ID，快速编译

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPT_DIR/config.json"

# 配置
SCHEME="${1:-ExampleApp}"
CONFIGURATION="${2:-Debug}"
CACHE_DIR=".build"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📱 iOS Build Verification${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 函数：查找项目目录
find_project_dir() {
    local current_dir="$PWD"
    
    # 首先检查当前目录
    if ls *.xcodeproj >/dev/null 2>&1 || ls *.xcworkspace >/dev/null 2>&1; then
        echo "$current_dir"
        return 0
    fi
    
    # 检查 Example 目录
    if [ -d "Example" ] && (ls Example/*.xcodeproj >/dev/null 2>&1 || ls Example/*.xcworkspace >/dev/null 2>&1); then
        echo "$current_dir/Example"
        return 0
    fi
    
    # 检查 iOS 目录
    if [ -d "iOS" ] && (ls iOS/*.xcodeproj >/dev/null 2>&1 || ls iOS/*.xcworkspace >/dev/null 2>&1); then
        echo "$current_dir/iOS"
        return 0
    fi
    
    # 检查 app 目录
    if [ -d "app" ] && (ls app/*.xcodeproj >/dev/null 2>&1 || ls app/*.xcworkspace >/dev/null 2>&1); then
        echo "$current_dir/app"
        return 0
    fi
    
    # 递归检查子目录
    for dir in */; do
        if [ -d "$dir" ] && (ls "$dir"*.xcodeproj >/dev/null 2>&1 || ls "$dir"*.xcworkspace >/dev/null 2>&1); then
            echo "$current_dir/$dir"
            return 0
        fi
    done
    
    return 1
}

# 函数：从配置文件读取设备 ID
get_device_id_from_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    # 使用 grep 和 sed 提取设备 ID
    local device_id=$(grep -o '"deviceId"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
    
    if [ -z "$device_id" ] || [ "$device_id" = "YOUR_DEVICE_ID_HERE" ]; then
        return 1
    fi
    
    echo "$device_id"
    return 0
}

# 函数：从配置文件读取模拟器名称
get_simulator_name_from_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "iPhone 17"
        return 0
    fi
    
    # 使用 grep 和 sed 提取模拟器名称
    local simulator_name=$(grep -o '"fallbackSimulator"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
    
    if [ -z "$simulator_name" ]; then
        simulator_name="iPhone 17"
    fi
    
    echo "$simulator_name"
    return 0
}

# 函数：编译真机
build_for_device() {
    local device_id=$1
    local project_dir=$2
    
    echo -e "\n${BLUE}🔨 编译配置:${NC}"
    echo "   Scheme: $SCHEME"
    echo "   Configuration: $CONFIGURATION"
    echo "   Destination: iPhone X Real Device"
    echo "   Device ID: $device_id"
    echo "   Project Dir: $project_dir"
    echo "   Cache: Enabled ($CACHE_DIR/)"
    
    echo -e "\n${YELLOW}⏳ 开始编译...${NC}"
    
    local start_time=$(date +%s)
    
    cd "$project_dir"
    
    xcodebuild \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "id=$device_id" \
        -derivedDataPath "$CACHE_DIR" \
        build
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        echo -e "\n${GREEN}✅ 编译成功 (耗时: ${duration}s)${NC}"
        return 0
    else
        echo -e "\n${RED}❌ 编译失败${NC}"
        return 1
    fi
}

# 函数：编译模拟器
build_for_simulator() {
    local simulator_name=$1
    local project_dir=$2
    
    echo -e "\n${BLUE}🔨 编译配置:${NC}"
    echo "   Scheme: $SCHEME"
    echo "   Configuration: $CONFIGURATION"
    echo "   Destination: iOS Simulator ($simulator_name, Rosetta)"
    echo "   Project Dir: $project_dir"
    echo "   Cache: Enabled ($CACHE_DIR/)"
    
    echo -e "\n${YELLOW}⏳ 开始编译...${NC}"
    
    local start_time=$(date +%s)
    
    cd "$project_dir"
    
    xcodebuild \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "platform=iOS Simulator,name=$simulator_name,OS=latest" \
        -derivedDataPath "$CACHE_DIR" \
        build
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        echo -e "\n${GREEN}✅ 编译成功 (耗时: ${duration}s)${NC}"
        return 0
    else
        echo -e "\n${RED}❌ 编译失败${NC}"
        return 1
    fi
}

# 主流程
main() {
    # 检查 Xcode 是否安装
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}❌ 错误: 未找到 xcodebuild，请确保已安装 Xcode${NC}"
        exit 1
    fi
    
    # 查找项目目录
    local project_dir=$(find_project_dir)
    
    if [ -z "$project_dir" ]; then
        echo -e "${RED}❌ 错误: 未找到 Xcode 项目文件${NC}"
        echo -e "${YELLOW}💡 请确保项目目录中存在 .xcodeproj 或 .xcworkspace 文件${NC}"
        exit 1
    fi
    
    echo -e "\n${GREEN}✅ 找到项目目录: $project_dir${NC}"
    
    # 从配置文件读取设备 ID
    local device_id=$(get_device_id_from_config)
    
    if [ -n "$device_id" ]; then
        # 使用真机编译
        echo -e "\n${GREEN}📱 使用 iPhone X 真机编译${NC}"
        build_for_device "$device_id" "$project_dir"
        exit $?
    else
        # 设备 ID 未配置，使用模拟器编译
        echo -e "\n${YELLOW}📱 设备 ID 未配置，使用 iPhone 17 (Rosetta) 模拟器编译${NC}"
        echo -e "${YELLOW}💡 提示: 运行 'bash setup-device.sh' 来配置真机设备${NC}"
        
        local simulator_name=$(get_simulator_name_from_config)
        
        if [ -z "$simulator_name" ]; then
            simulator_name="iPhone 17"
        fi
        
        build_for_simulator "$simulator_name" "$project_dir"
        exit $?
    fi
}

# 运行主函数
main "$@"
