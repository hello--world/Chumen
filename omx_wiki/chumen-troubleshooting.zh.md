---
title: "Chumen 排障知识"
tags: ["chumen", "troubleshooting", "errors", "core-api", "tun", "proxy", "logs"]
created: 2026-07-05T14:30:00Z
updated: 2026-07-05T14:30:00Z
sources:
  - README.zh.md
  - docs/security-model.zh.md
  - Sources/ChumenMacApp/AppModel.swift
  - Sources/ChumenMacApp/RulesLogsViews.swift
  - Sources/ChumenCore/LogAnalysis.swift
links:
  - chumen-troubleshooting.en.md
  - chumen-runtime-and-system.zh.md
category: debugging
confidence: high
schemaVersion: 1
---

# Chumen 排障知识

English version: [chumen-troubleshooting.en.md](chumen-troubleshooting.en.md)

## 无法连接内核 API

含义：Chumen 当前无法访问 mihomo controller。

影响：

- 代理组、Provider、规则、连接、流量、内存、内核工具不可用或过期。
- 配置库、配置编辑、追加覆盖、教程回答、AI 离线草稿仍可用。

排查：

1. 看内核是否已启动。
2. 看 controller 地址和端口是否与设置一致。
3. 看是否有外部内核占用端口。
4. 看日志页和 `logs/sidecar.log`。
5. 如果刚改了端口或 secret，重新生成并 reload/重启。

## 内核未启动

含义：Chumen 没有运行中的 mihomo 内核。

用户可以继续：

- 编辑配置。
- 导入订阅。
- 修改设置。
- 准备 AI 草稿。

需要启动内核后才有：

- 实时代理列表。
- 连接和规则运行态。
- 流量、内存、日志流。
- 内核工具 API。

## 配置修改不生效

常见原因：

- 只保存了配置，没有应用或 reload。
- 修改了原始订阅以外的追加覆盖，但节点没有加入代理组。
- 新规则被旧规则提前命中，需要 `prepend`。
- 内核运行中但 API reload 失败。
- 用户正在看的是另一个启用配置。

排查路径：

1. 确认当前启用配置。
2. 检查追加覆盖 section 是否正确。
3. 生成 runtime YAML 或使用 reload runtime config。
4. 查看日志里的配置解析错误。
5. 对字段语义问题查 mihomo 知识库。

## 系统代理异常

现象：

- 顶部显示其他代理。
- 系统代理已开启但流量不走 Chumen。
- 停止后系统代理残留。

解释：

- 系统代理是 macOS 外部状态，可能被其他应用改写。
- Chumen 只应清理自己写入或配置要求清理的状态。
- 刷新系统代理状态不依赖内核 API。

## TUN 失败

常见原因：

- helper 未安装或不可用。
- 权限不足。
- TUN 配置字段错误。
- 运行中切换未重启。
- 退出前未按设置清理。

排查：

1. 查看日志和通知。
2. 确认 helper 状态。
3. 重启内核而不是只 reload。
4. 检查 TUN/DNS 配置。
5. 如涉及 macOS 原生网络行为，查 mihomo `tun-macos-native` 知识页。

## AI 回答不对

如果 AI 把教程问题回答成“无法连接内核 API”，这是路由错误。

正确逻辑：

- “如何添加代理/规则/订阅”走 Chumen 应用知识库。
- “当前有哪些代理/规则是否命中/连接状态”才依赖内核 API。
- 具体 YAML 字段走 mihomo 知识库。

## 看哪里

- GUI 日志页：看应用日志、运行日志、错误分析。
- `logs/sidecar.log`：看持久事件和内核 stdout/stderr。
- 内核工具页：API 在线时做 DNS/storage/raw API 检查。
- 配置页：检查启用配置和追加覆盖。
- 设置页：检查系统代理、TUN、自动清理和语言/AI 设置。
