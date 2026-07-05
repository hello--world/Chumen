---
title: "Chumen Engineering Operating Constraints"
tags: ["planning", "ui", "refresh", "process-name", "agent-memory"]
created: 2026-07-05T03:38:05.603Z
updated: 2026-07-05T03:38:05.603Z
sources: []
links: []
category: convention
confidence: medium
schemaVersion: 1
---

# Chumen Engineering Operating Constraints

## 中文
- 修改重要页面前先规划数据来源、更新频率、状态归属和验证方式，不要只按截图局部硬改。
- 总览、顶部状态、状态栏和设置页应共享可复用的数据协议或更新模块，避免每个页面单独定时刷新。
- 系统代理状态属于应用级外部状态，应由统一更新调度器常驻刷新；内核连接、流量、内存属于内核运行态，只在内核运行时刷新。
- 自定义内核进程名必须通过 Chumen 受控的 chumen- 前缀启动路径实现。优先使用符号链接指向真实 core，避免复制副本导致旧二进制、磁盘浪费或升级不一致。
- UI 焦点态必须反映真实交互状态。未点击的搜索入口不应显示键盘焦点蓝框；真正输入态只在搜索浮层拥有焦点时出现。
- 做完改动必须至少运行 swift build、相关测试或 swift test、git diff --check；需要视觉判断时重启 app 并截图验证。

## English
- Before changing important screens, plan data ownership, refresh cadence, state boundaries, and validation. Do not patch only what the screenshot happens to show.
- Dashboard, header status, status bar, and settings surfaces should share reusable data protocols or update modules instead of each page owning separate timers.
- System proxy status is app-level external state and should be refreshed by the shared update coordinator. Core connections, traffic, and memory are runtime state and refresh only while the core is running.
- Custom core process names must use a Chumen-controlled chumen- prefixed launch path. Prefer a symlink to the real core over copying the binary, preventing stale executables, disk waste, and upgrade drift.
- UI focus states must reflect real interaction. An unfocused search entry should not show a blue keyboard focus ring; the input focus state belongs to the active search overlay.
- After changes, run at least swift build, targeted tests or swift test, and git diff --check. For visual behavior, restart the app and verify with a screenshot.
