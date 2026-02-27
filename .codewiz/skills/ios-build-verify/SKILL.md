---
name: ios-build-verify
description: iOS 项目编译验证。自动检测连接的真机设备，优先使用 iPhone X 真机编译，否则使用 iPhone 17 (Rosetta) 模拟器编译，支持编译缓存加速。
---

# iOS Build Verify Skill

用于快速验证 iOS 项目的编译状态。该技能会：
1. 自动检测连接的 iOS 真机设备
2. 优先使用 iPhone X 真机编译（如果已连接）
3. 否则使用 iPhone 17 (Rosetta) 模拟器编译
4. 启用编译缓存以加速构建过程

## 快速开始（首次设置）

### 第一步：查询并设置设备 ID
```bash
bash .codewiz/skills/ios-build-verify/setup-device.sh
```

这个脚本会：
1. 自动扫描连接的 iOS 设备
2. 显示所有可用设备
3. 让你选择要使用的设备
4. 自动更新 `config.json` 中的设备 ID

**输出示例**:
```
✅ 检测到以下设备:
   [1] iPhone X
       ID: XXXXXXXX-XXXXXXXXXXXXXXXX

✅ 自动选择唯一的设备: iPhone X
✅ 配置文件已更新

✅ 设置完成!
设备信息:
  名称: iPhone X
  ID:   XXXXXXXX-XXXXXXXXXXXXXXXX
```

### 第二步：运行编译
```bash
bash .codewiz/skills/ios-build-verify/build.sh
```

## 使用方式

### 自动触发
当你提到以下关键词时，该技能会自动调用：
- "编译验证"
- "iOS build"
- "验证编译"
- "构建验证"
- "编译检查"

### 手动触发
```
使用 ios-build-verify 技能验证编译
```

## 工作流程

### 1. 首次设置：查询设备 ID
```bash
bash .codewiz/skills/ios-build-verify/setup-device.sh
```
- 自动扫描连接的 iOS 设备
- 显示所有可用设备列表
- 让用户选择要使用的设备
- 自动保存设备 ID 到 `config.json`

### 2. 后续编译：直接使用配置的设备 ID
```bash
bash .codewiz/skills/ios-build-verify/build.sh
```
- 从 `config.json` 读取设备 ID（无需查询）
- 直接使用真机编译
- 如果设备 ID 未配置，自动检测并保存

### 3. 选择编译目标
- **如果配置了设备 ID**: 使用真机编译（快速）
- **如果设备 ID 未配置**: 自动检测或使用模拟器编译

### 3. 编译命令

#### 真机编译（iPhone X）
```bash
xcodebuild \
  -scheme <scheme_name> \
  -configuration Debug \
  -destination "generic/platform=iOS" \
  -derivedDataPath .build \
  build
```

#### 模拟器编译（iPhone 17 Rosetta）
```bash
xcodebuild \
  -scheme <scheme_name> \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -derivedDataPath .build \
  build
```

### 4. 缓存配置
- **派生数据路径**: `.build/` （项目根目录）
- **缓存位置**: `~/Library/Developer/Xcode/DerivedData/`
- **清理缓存**: `rm -rf .build/`

## 配置文件说明

### config.json 结构
```json
{
  "deviceConfig": {
    "deviceId": "YOUR_DEVICE_ID_HERE",  // 设备 ID（首次运行 setup-device.sh 自动填充）
    "preferredDevice": "iPhone X",       // 优先设备
    "fallbackSimulator": "iPhone 17",    // 备选模拟器
    "simulatorOS": "latest"              // 模拟器 OS 版本
  },
  "buildConfig": {
    "scheme": "ExampleApp",              // 编译方案
    "configuration": "Debug",            // 编译配置
    "enableCache": true,                 // 启用缓存
    "cacheDir": ".build"                 // 缓存目录
  }
}
```

### 如何设置设备 ID

**方式 1：自动设置（推荐）**
```bash
bash .codewiz/skills/ios-build-verify/setup-device.sh
```

**方式 2：手动设置**
编辑 `config.json`，将 `deviceId` 改为你的设备 ID：
```json
"deviceId": "XXXXXXXX-XXXXXXXXXXXXXXXX"
```

### 如何获取设备 ID

```bash
# 方式 1：使用 setup-device.sh（自动显示）
bash .codewiz/skills/ios-build-verify/setup-device.sh

# 方式 2：手动查询
xcrun xctrace list devices

# 方式 3：使用 xcode-select
system_profiler SPUSBDataType | grep -A 10 "iPhone"
```

## 编译参数说明

| 参数 | 说明 |
|------|------|
| `-scheme` | 编译方案名称 |
| `-configuration` | 编译配置（Debug/Release） |
| `-destination` | 目标设备或模拟器 |
| `-derivedDataPath` | 派生数据存储路径（启用缓存） |
| `build` | 编译操作 |

## 常见场景

### 场景 1: 快速验证编译
```
我需要验证一下编译是否通过
```
→ 自动检测设备并编译

### 场景 2: 指定编译方案
```
使用 ios-build-verify 技能验证 ExampleApp 方案的编译
```
→ 编译指定的 scheme

### 场景 3: 清理缓存后重新编译
```
清理缓存并验证编译
```
→ 删除 `.build/` 目录后重新编译

## 输出示例

### 成功编译
```
✅ iOS Build Verification
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📱 Device: iPhone X (Real Device)
   Device ID: XXXXXXXX-XXXXXXXXXXXXXXXX
   
🔨 Build Configuration:
   Scheme: ExampleApp
   Configuration: Debug
   Destination: iPhone X Real Device
   
💾 Cache: Enabled (.build/)

⏱️  Build Time: 45s
✅ Build Status: SUCCESS

📊 Build Summary:
   - Compiled: 150 files
   - Warnings: 0
   - Errors: 0
```

### 使用模拟器编译
```
✅ iOS Build Verification
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📱 Device: iPhone 17 Simulator (Rosetta)
   No real device detected, using simulator
   
🔨 Build Configuration:
   Scheme: ExampleApp
   Configuration: Debug
   Destination: iOS Simulator (iPhone 17, Rosetta)
   
💾 Cache: Enabled (.build/)

⏱️  Build Time: 32s
✅ Build Status: SUCCESS

📊 Build Summary:
   - Compiled: 150 files
   - Warnings: 0
   - Errors: 0
```

## 故障排除

### 问题 1: 找不到设备
```
❌ No iOS devices found
→ 检查 USB 连接
→ 检查 Xcode 信任设置
→ 尝试重新连接设备
```

### 问题 2: 编译失败
```
❌ Build Failed
→ 检查编译错误信息
→ 清理缓存: rm -rf .build/
→ 重新编译
```

### 问题 3: 模拟器不可用
```
❌ iPhone 17 Simulator not available
→ 检查 Xcode 版本
→ 创建新的模拟器: xcrun simctl create "iPhone 17" com.apple.CoreSimulator.SimDeviceType.iPhone-17
```

## 高级用法

### 自定义编译配置
在项目根目录创建 `.codewiz/skills/ios-build-verify/config.json`:
```json
{
  "scheme": "ExampleApp",
  "configuration": "Debug",
  "enableCache": true,
  "cacheDir": ".build",
  "preferredSimulator": "iPhone 17"
}
```

### 编译后自动运行测试
```
验证编译并运行单元测试
```
→ 编译成功后自动运行 `xcodebuild test`

## 相关命令

| 命令 | 说明 |
|------|------|
| `xcrun xctrace list devices` | 列出所有设备 |
| `xcrun simctl list devices` | 列出所有模拟器 |
| `xcodebuild -showsdks` | 显示可用的 SDK |
| `xcodebuild -list` | 列出项目的 schemes |
| `rm -rf .build/` | 清理编译缓存 |

## 最佳实践

1. **定期清理缓存** - 每周清理一次 `.build/` 目录
2. **使用真机测试** - 优先在真机上验证编译
3. **监控编译时间** - 记录编译时间变化，识别性能问题
4. **保持 Xcode 更新** - 定期更新 Xcode 以获得最新的编译优化

## 相关文档

- [Xcode Build System](https://developer.apple.com/documentation/xcode/building-your-app-with-xcode)
- [iOS Device Support](https://developer.apple.com/support/xcode/)
- [Simulator Documentation](https://developer.apple.com/documentation/xcode/running-your-app-in-the-simulator-or-on-a-device)
