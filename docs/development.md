# 开发说明

## 工程

根目录 `Package.swift` 是唯一构建入口，不需要 XcodeGen、CocoaPods 或外部 Swift 包。

| 目录 | 职责 |
| --- | --- |
| `Sources/MindMapCore` | 主题树、事务命令、文件格式、Markdown、布局几何 |
| `App/Application` | SwiftUI 文档场景、菜单、应用生命周期 |
| `App/Documents` | FileDocument、每窗口编辑会话、系统撤销桥接 |
| `App/Canvas` | NSViewRepresentable、绘制、键盘、文本输入、拖拽和缩放 |
| `App/Views` | 窗口布局、大纲、搜索、主题详情 |
| `App/Support` | Markdown/图片/PDF 导出 |
| `Tests/MindMapCoreTests` | 可在 Linux/macOS 运行的内核回归 |
| `Tests/PMindAppTests` | 仅 macOS 的会话、撤销、多窗口隔离和文本测量测试 |
| `Resources/Info.plist` | 应用 Bundle 和文档类型声明 |
| `script/build_and_run.sh` | 构建、开发签名、启动与调试的唯一入口 |

## 模型和修改

每个主题包含稳定 UUID、标题、备注、折叠状态、可选分支颜色及有序子主题。`MapCommand` 在副本上修改并校验，成功才替换原文档；无效移动、根删除和其他空操作不产生历史。原生层通过 `EditorSession` 调用命令并注册 `UndoManager` 的反向快照。不要在视图里另维护一份可写导图。

`FileDocument` 的绑定保存持久数据，窗口会话只保存选区、搜索、缩放和编辑请求。打开两个窗口时会话与撤销记录隔离。编辑框使用 AppKit 字段编辑器处理中文输入法与原生删除/复制；窗口会话通过弱引用 `TitleEditing` 在命令、复制粘贴和保存/导出前提交自己的标题编辑，失败则中止后续操作并保留输入。新标题的编辑请求仅在输入框成功接管后消费。

布局接收文本测量函数，输出节点矩形、折叠按钮矩形及贝塞尔路径。画布绘制、命中和导出复用这份几何；折叠按钮命中只扫描已布局元数据，不逐节点回查主题树。生产文本通过系统字体实际测量；Linux 布局测试注入固定测量器，不宣称像素与 Mac 一致。PNG 以 2 倍像素输出，限制边长 16384 像素及总像素 6400 万；大型导图可使用 PDF 或折叠分支。

## 文件格式

`.pmind` 是紧凑、键排序的 UTF-8 JSON，顶层为 `format: "pmind"`、`version: 1`、`layout` 和 `root`。保存时保留全部后代，包括折叠主题；拒绝重复标识、超过 128 层、10000 个主题或 8 MiB 的文档。读取时同时检查原始大小和保存编码的大小，接受旧版带缩进 JSON，避免深树仅因格式化膨胀而无法保存。不支持的版本在解析主体前报错，不打开后覆盖。

Markdown 是文本交换格式，不保存 UUID、颜色、折叠或布局。支持真实标题层级、有序/无序列表、引用备注、代码围栏；不是通用 Markdown 富文本渲染器。导出用一级标题表示中心主题，用缩进列表表示后代，标题换行用 `<br>` 表达。

## 构建与测试

Mac：`swift test`，然后 `./script/build_and_run.sh --verify`。`--verify` 只验证进程存在，交互仍按验收清单检查。`--debug` 在 LLDB 中运行应用二进制；`--logs` 观察进程日志；`--telemetry` 过滤 `app.pmind.mac` 子系统。日志不记录标题、备注或文件内容。

Linux 云环境：运行 `./script/setup_linux.sh` 安装经过发布签名验证的 Swift 6.1.3，再运行 `./script/test.sh`。脚本使用 `/workspace/.pmind-native-tools`，可通过 `PMIND_TOOLS_DIR` 指定其他可写目录。工具链没有系统安装步骤。应用目标和原生测试目标在 Linux 不注册，因此测试通过只说明内核通过。测试脚本将 Swift/Clang 缓存指向工具目录，无需改变 HOME。

笔记校验工具是独立的维护工具，需要 Node 22.18+，运行 `npm run verify-notes`；产品本身不需要 Node。

## 分发

当前脚本生成本机架构的开发构建。Apple Silicon 和 Intel 需分别在对应 Mac 构建。对外发布需另外设置 Developer ID 签名、hardened runtime、公证和安装包流程；不要把 ad-hoc 开发签名作为正式分发就绪证明。
