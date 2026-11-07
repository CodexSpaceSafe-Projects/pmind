# pmind

轻量、离线的 macOS 原生思维导图。用 Swift、SwiftUI 和 AppKit 构建，文档直接保存在你的 Mac 上，无需账号、服务器或数据库。

## 核心功能

- 主题创建、改名、删除、子树复制粘贴、拖拽调整父级与顺序。
- 左右思维导图和向右逻辑图；折叠、触控板平移缩放、适应窗口与中心定位。
- 同步大纲、标题和备注搜索、纯文本备注、分支配色。
- 系统文档窗口、本地 `.pmind` 文件、自动保存、撤销重做。
- Markdown 导入/导出，PNG 和 PDF 导出。

## 在 Mac 上运行

需要 **macOS 14+、Xcode 16+ / Swift 6**，支持 Apple Silicon 与 Intel。没有第三方运行时依赖。

```bash
./script/build_and_run.sh
```

脚本编译并生成 `dist/pmind.app`，使用本地开发签名后启动。也可以在 Xcode 打开根目录 `Package.swift` 查看和调试代码；通过脚本启动可确保文档类型及应用 Bundle 信息完整。

已有应用运行时，脚本在新构建准备完成后正常请求退出，让系统处理未保存内容；取消退出会停止替换和启动。`--build-only` 不会退出正在运行的应用，此时请先保存并关闭应用再构建。

```bash
swift test                           # 内核 + macOS 原生会话测试
./script/build_and_run.sh --build-only # 仅构建 .app
./script/build_and_run.sh --debug      # LLDB
./script/build_and_run.sh --logs       # 系统日志
```

Codex 的 Run 按钮调用相同的构建启动脚本。开发签名不等于正式签名和公证，当前没有正式发布的安装包。

提交到 `main` 或向 `main` 提交 Pull Request 时，[GitHub Actions](https://github.com/CodexSpaceSafe-Projects/pmind/actions/workflows/macos.yml) 自动测试并分别构建 Apple Silicon（`arm64`）和 Intel（`x86_64`）版本，也支持在 Actions 页面使用 **Run workflow** 手动构建。成功运行的 **Artifacts** 提供 `pmind-macos-arm64` 和 `pmind-macos-x86_64`，保留 14 天；下载适合自己 Mac 的产物，再解压其中的 `.zip` 即可得到 `pmind.app`。同时提供 SHA-256 校验文件。这些是开发签名构建，尚未公证。

`main` 的自动或手动构建在全部检查通过后，还会发布到 [GitHub Releases](https://github.com/CodexSpaceSafe-Projects/pmind/releases)。每次构建生成独立的 `build-运行编号-提交短哈希` 开发预发布，包含两个架构的 ZIP 和 SHA-256。PR 不发布；历史版本保留，已公开的同一次构建不会被重跑覆盖。下载对应架构的 ZIP 解压即可使用，开发签名和未公证状态不变。

## 开始编辑

打开应用会创建一份示例导图。双击主题修改标题；画布有焦点时 **Tab** 添加子主题，**Return** 添加同级主题，**Delete** 删除非中心主题。文字输入时使用原生编辑行为，**Shift Return** 插入换行。

拖到主题中央可成为其子主题，拖到主题上/下缘可插入相邻位置。方向键浏览主题；触控板双指滚动平移、捏合缩放，也可按空格拖动或用鼠标中键平移。工具栏分别提供同级和子主题按钮。

使用 **⌘S** 保存、**⇧⌘S** 另存为、**⌘Z / ⇧⌘Z** 撤销重做。文件菜单支持打开 Markdown，并通过“导出”保存 Markdown、PNG 或 PDF。Markdown 包含完整树；图片和 PDF 反映当前折叠状态。

## 重构与验证状态

当前工程已经替换原 Go/React 网站。首版聚焦核心编辑，不包含在线分享、AI、账号、管理后台、概要、联系线、附件、多画布或 XMind 支持。旧 `.wmind` 不直接兼容，迁移方法见 [迁移说明](docs/migration.md)。

当前 Linux 工作区已执行并通过 31 项 Swift 内核测试和 8 个启动脚本模拟用例；macOS 应用编译、8 项原生测试和界面验收尚未在这里执行。仓库提供 macOS CI 与 [验收清单](docs/validation.md)，不能将其配置完成视为验证通过。

开发结构见 [开发说明](docs/development.md)。原网站截图保留在 `docs/screenshots`，仅供历史参考，并非新版界面。许可证为 [MIT](LICENSE)。
