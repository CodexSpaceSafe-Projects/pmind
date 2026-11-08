# Agent Note: 启动先显示主界面，再由用户新建或打开导图

Status: implemented

## Problem

应用最初只有 DocumentGroup 场景。用户从应用图标启动时先看到系统打开文件面板，找不到自己的主界面，也容易以为必须先选择文件才能使用。用户要求先进入应用，再选择新建项目或打开已有文件。

## Decision

`PMindApp` 的第一个场景是唯一 ID 为 `pmind.home` 的 SwiftUI Window，之后仍是原有 DocumentGroup。主界面提供新建导图、打开文件和最近八个文件；文件菜单提供显示主界面的入口。窗口创建、关闭后的重新打开和已存在窗口复用交给 SwiftUI 场景管理，不增加一套可写文档模型。

只有点击打开按钮才展示 fileImporter。选中的文件和最近文件通过 SwiftUI openDocument 交给原有文档体系，错误显示在主界面，取消选择仍留在主界面。最近列表取自系统 NSDocumentController，不扫描用户目录、不新增数据库，也不打印路径。

新建按钮使用 newDocument，文件菜单使用同一个 MindMapFile 默认初始化；两者都创建只有中心主题的空白导图，不再自动填入示例。原有保存、自动保存、撤销和多文档隔离继续由 FileDocument/DocumentGroup 负责，Finder 文件打开也继续交给文档场景。

### 历史笔记审计

按启动、欢迎、新建、最近和文档检索活跃 implemented、proposed 和 rejected。[原生 macOS 架构](../architecture/2026-11-07-pmind-native-macos.md) 部分重叠，保留本地文件、SwiftUI、系统文档和多窗口边界，本篇补充启动入口并互链；其他旧 Web 笔记不适用于原生窗口生命周期。没有其他活跃原生开始界面提案需要替代。

## Alternatives considered

**保留 DocumentGroup 为唯一场景，用 AppKit 手动创建欢迎窗口并拦截启动。** 可以精确控制窗口，但容易让默认文档打开流程和自建窗口同时出现，也需要维护额外的窗口与回调生命周期。将 SwiftUI Window 放在首位直接表达默认入口，文档场景仍独立存在。

**只用 defaultLaunchBehavior 修饰文档场景。** 新系统提供明确的启动控制，但该 API 需要 macOS 15，当前产品仍支持 macOS 14。使用已有 Window 场景的默认顺序可以避免抬高最低系统版本或维护两套启动路径；默认场景语义参见 [Apple 场景启动说明](https://developer.apple.com/documentation/swiftui/scene/defaultlaunchbehavior(_:))。

## Consequences

- 普通启动先进入主界面；主界面与多个编辑窗口可以并存，用户可以从文件菜单返回同一主界面。
- 新文档为空白导图，内核的 welcome 示例仅保留为测试和示例数据，不作为默认创建内容。
- 系统最近文件可能包含已移走的文件，点击后以原生打开错误提示处理，不静默修改历史。
- 自动化冷启动检查不等于完整验证中文输入法、系统文件面板取消和文档状态恢复，后者仍在人工验收范围。

## Verification

`HomeStartupTests` 验证新建文档只有一个中心主题；现有会话和内核回归继续运行。Mac CI 在解压签名产物后通过 NSWorkspace 正常启动应用，并以窗口列表检查只有一个标题为 pmind 的主窗口，避免系统打开面板占据启动流程。Linux 仅做 Swift 语法和笔记检查，Mac 编译和运行结果以对应 Actions 记录为准。
