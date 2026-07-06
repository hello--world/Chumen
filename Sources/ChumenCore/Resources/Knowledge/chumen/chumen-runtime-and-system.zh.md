---
title: "Chumen 运行、系统代理和 TUN 知识"
tags: ["chumen", "runtime", "core", "system-proxy", "tun", "ports", "status"]
created: 2026-07-05T14:30:00Z
updated: 2026-07-05T14:30:00Z
sources:
  - README.zh.md
  - DESIGN.zh.md
  - Sources/ChumenMacApp/AppModel.swift
  - Sources/ChumenMacApp/CoreViews.swift
  - Sources/ChumenMacApp/AppUpdateCoordinator.swift
links:
  - chumen-runtime-and-system.en.md
  - chumen-troubleshooting.zh.md
category: reference
confidence: high
schemaVersion: 1
---

# Chumen 运行、系统代理和 TUN 知识

English version: [chumen-runtime-and-system.en.md](chumen-runtime-and-system.en.md)

## 状态来源

Chumen 有三类状态：

- 应用状态：配置库、设置、语言、AI provider、PIN、同步、状态栏偏好。通常不依赖内核 API。
- 外部系统状态：macOS 系统代理。由 `networksetup` 读取和写入，应由共享更新调度器刷新。
- 内核运行态：版本、代理组、Provider、规则、连接、流量、内存、日志、DNS/storage/raw API。需要 mihomo controller 可达。

“无法连接内核 API”只说明第三类不可用，不代表应用知识库、配置编辑或离线草稿不可用。

## 内核生命周期

常用操作：

- 启动：用 Chumen 生成的 runtime YAML 启动 mihomo。
- 停止：停止由 Chumen 启动的内核。
- 重启：停止再启动，或通过 controller kernel restart。
- 刷新：重新读取运行态快照。
- Reload runtime config：重新生成 runtime YAML 并请求 controller reload。

Chumen 启动内核前会创建托管启动路径。默认进程名后缀是 `door`，实际进程名是 `chumen-door`。自定义进程名必须走 Chumen 控制的 `chumen-` 前缀路径，优先用符号链接指向真实 core。

## 默认端口

Chumen 默认避开常见代理客户端端口：

- mixed：`19881`
- SOCKS：`19882`
- HTTP：`19883`
- controller：`19897`

端口由 Chumen 设置拥有，会在 runtime YAML 中覆盖原始配置。修改端口后需要应用到运行配置。

## 系统代理

系统代理是 macOS 网络服务上的 HTTP/SOCKS 代理设置。

- 开启系统代理会把网络服务指向 Chumen 的本地代理地址。
- 关闭系统代理会清理 Chumen 写入的代理设置。
- 如果检测到其他代理占用，应显示“其他代理”而不是误认为 Chumen 已开启。
- 启动后自动开启系统代理、停止时自动清理系统代理属于 Chumen 应用偏好。

系统代理状态可以在内核停止时刷新，因为它是 macOS 外部状态。

## TUN

TUN 是启动级网络路由能力。

- 开启 TUN 会影响内核启动配置，运行中切换通常需要重启内核。
- macOS 上 TUN 可能需要特权 helper。
- `enableTunOnStart` 决定启动时是否启用 TUN。
- `disableTunOnQuit` 决定退出时是否关闭 TUN 配置，避免下次自动启动继续捕获流量。
- 退出 Chumen 时必须停止由 Chumen 启动的内核，避免 TUN 或代理进程残留。

## 内核设置页

内核页负责 mihomo/runtime 设置：

- 可执行文件路径。
- 托管进程名。
- controller secret。
- 启动后自动启动内核。
- mixed/SOCKS/HTTP/redir/tproxy 端口。
- allow-lan、IPv6、unified-delay、TCP concurrent、find process。
- TUN 基础和高级设置。
- DNS 基础和高级设置。
- external UI。
- 全局 YAML 追加段。

普通设置可以自动保存；影响运行中内核的设置需要明确应用或 reload。

## 内核工具页

工具页依赖内核 API，常见功能：

- reload runtime config。
- restart kernel API。
- 打开外部 Dashboard。
- flush fake-IP、flush DNS、debug GC。
- 更新/升级 Geo。
- DNS query。
- storage get/put/delete。
- raw API 请求。

如果内核 API 不可达，这些工具会失败，但配置编辑仍可进行。
