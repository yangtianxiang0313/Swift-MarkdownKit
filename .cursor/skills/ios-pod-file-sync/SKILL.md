---
name: ios-pod-file-sync
description: Syncs new or deleted Swift files to iOS Xcode project for CocoaPods libraries. Runs pod install so source_files glob picks up changes. Use when adding/removing .swift files in Sources/, when user mentions file sync, 文件同步, 新文件不显示, pod install, or when Xcode does not show newly created files.
---

# iOS Pod 文件同步

CocoaPods 的 `source_files` 使用 glob 模式，新增或删除 `.swift` 文件后 Xcode 不会自动刷新，需执行 `pod install` 才能纳入工程。

## 触发后执行

**在以下任一情况发生后**，执行同步：

1. 在 `Sources/**/` 下新增或删除了 `.swift` 文件
2. 用户提到：文件同步、新文件不显示、Xcode 看不到新文件、pod install
3. 修改 podspec 的 `source_files` 后

## 同步流程

### 库代码（Sources/）

podspec 使用 `s.source_files = 'Sources/XHSMarkdownKit/**/*.swift'` 时，新文件在 `pod install` 时才会被纳入。

**执行**：

```bash
cd Example && pod install
```

若项目 Podfile 在根目录，则：

```bash
pod install
```

### 若 sync 后仍无新文件

清理缓存后重装：

```bash
pod cache clean --all
cd Example && pod install
```

### ExampleApp 自身文件（Example/ExampleApp/）

ExampleApp 是普通 Xcode 工程，文件列表在 `project.pbxproj` 中。**不受 pod install 影响**。

**操作**：在 Xcode 中手动 Add Files to "ExampleApp"，或修改 `project.pbxproj`。本 skill 不处理此场景。

## 可选：使用脚本

执行脚本自动定位 Podfile 并运行 `pod install`：

```bash
.cursor/skills/ios-pod-file-sync/scripts/sync.sh
```

从项目根目录运行，脚本会查找 `Example/Podfile` 或根目录 `Podfile`。

## 检查清单

- [ ] 确认新增/删除的是库内的 `.swift` 文件（非 ExampleApp）
- [ ] 在项目根目录或 Example 目录执行 `pod install`
- [ ] 若无效，执行 `pod cache clean --all` 后重试
