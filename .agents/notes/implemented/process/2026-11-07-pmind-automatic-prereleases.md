# Agent Note: 原生 macOS 构建自动生成 GitHub 开发预发布

Status: implemented

## Problem

双架构应用已经由 Actions 构建，但下载入口仅是保留 14 天的 Artifacts。用户要求自动放入 GitHub Releases，避免每次构建后手动下载和上传；同时不能把开发签名误称为已经公证的稳定发行版。

## Decision

main push 或在 main 手动触发的工作流，在两个 native 矩阵作业和仓库检查全部成功后，运行独立 release 作业。PR 和其他分支不发布。构建、检查作业维持 contents 只读，只有发布作业获取 contents 写权限，使用 GitHub 提供的本次工作流 token，不配置长期个人密钥。

发布从当前运行下载两个架构的 ZIP 与 SHA-256，检查四个附件存在且校验通过。标签为 `build-<run_number>-<short_sha>`，目标固定到本次测试的完整 GITHUB_SHA；每次成功构建保留一个独立开发预发布，不移动历史标签，也不改变 VERSION 或创建稳定版本。

`script/publish_release.sh` 先创建草稿，全部附件上传成功后才公开为 prerelease，且不设置为 latest 稳定版。失败或取消可以留下未发布草稿，同一运行重试会补传附件并完成它。已公开的同一构建再次运行时不改附件；若已有记录的目标提交不一致则拒绝修改。发布说明同时提供提交、构建链接、架构选择和开发签名/未公证状态。

### 历史笔记审计

按 release、标签、Actions 和自动发布检索活跃 implemented、proposed 与 rejected。[原生 macOS 架构](../architecture/2026-11-07-pmind-native-macos.md) 部分重叠：保留系统文档、双架构开发构建及签名边界，本篇扩展其只读 CI 的发布能力，并互链。没有当前原生自动发布的其他活跃提案需要替代。旧 Web 版本发布的归档为冻结历史，不作为当前实现要求，也不修改它们。

## Alternatives considered

**仅在 v* 标签推送时发稳定 Release。** 显式版本切点清晰，但仍需人为打标签，不能满足每次 main 构建自动进入 Releases 的要求，且当前只有开发签名。将来具备正式签名、公证与版本管理需求时再建立稳定版流程。

**反复覆盖一个 nightly/dev 标签。** 下载链接固定、列表更短，但移动标签和覆盖附件会失去每次构建的精确对应，也容易在替换 ZIP 与校验文件之间产生短暂不一致。每运行一个独立标签可以保留原始来源；同一运行的草稿允许恢复，公开版本则保持不变。

## Consequences

- Releases 为成功构建提供持续的下载入口；Actions Artifacts 仍保留 14 天以便排查。
- 每次 main 成功运行都会增加一条开发预发布，暂不自动删除历史。如果数量影响管理，再单独决定保留政策。
- 取消发布或上传失败可能留下草稿；它不会以不完整附件公开，重跑同一运行可以恢复。
- 对外可下载不意味着 Developer ID 签名、公证、Universal 安装包或 GUI 验收完成。

## Verification

`bash script/tests/publish_release_tests.sh` 的 9 个隔离用例验证 PR/其他分支拒绝、缺少架构、校验失败、精确提交草稿发布、草稿恢复、公开版本不变、提交不符和上传失败不公开。模拟 gh 命令，不连接真实 GitHub。Actions YAML 和 Bash 步骤在 Linux 解析；实际 Release、四个附件和来源标签通过推送后的远端工作流检查。
