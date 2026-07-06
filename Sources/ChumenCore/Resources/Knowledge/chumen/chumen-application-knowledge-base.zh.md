---
title: "Chumen 应用知识库"
tags: ["chumen", "application", "assistant", "profiles", "workflow", "knowledge-base"]
created: 2026-07-05T14:20:01Z
updated: 2026-07-05T14:20:01Z
sources:
  - README.zh.md
  - DESIGN.zh.md
  - docs/security-model.zh.md
  - docs/ui-design-system.zh.md
  - Sources/ChumenCore/ChumenAI.swift
  - Sources/ChumenMacApp/AppModel.swift
links:
  - chumen-application-knowledge-base.en.md
  - chumen-engineering-operating-constraints.md
category: reference
confidence: high
schemaVersion: 1
---

# Chumen 应用知识库

English version: [chumen-application-knowledge-base.en.md](chumen-application-knowledge-base.en.md)

## 定位

Chumen 是 macOS 原生 SwiftUI 应用，用来启动、控制、观察本机 mihomo 内核。Chumen 自己负责应用入口、配置库、运行配置生成、安全保护、系统代理、TUN helper、仪表盘、日志、AI 待审核变更和状态栏生命周期。mihomo 负责代理协议、配置字段语义和 controller API。

## 相关页面

- [[chumen-knowledge-routing.zh]]：问什么读哪里，以及 Chumen/mihomo 知识边界。
- [[chumen-profile-workflows.zh]]：配置、订阅、节点、规则、代理组和追加覆盖。
- [[chumen-runtime-and-system.zh]]：内核生命周期、系统代理、TUN、端口和状态来源。
- [[chumen-ai-assistant-policy.zh]]：智能体 provider、待审核变更和本地帮助分流。
- [[chumen-troubleshooting.zh]]：内核 API、配置不生效、系统代理、TUN 和 AI 回答排障。

知识库边界：

- Chumen 应用知识库回答“在哪里操作、怎样添加、怎样应用、为什么要审核、为什么需要 PIN/TUN/helper”等应用问题。
- mihomo 知识库回答“某个 YAML 字段怎么写、某个协议有哪些字段、controller 端点如何工作”等内核/协议问题。
- “无法连接内核 API”只影响实时运行状态、代理列表、连接、规则、流量和内核工具，不应阻止配置教程、知识问答或离线编辑说明。

## 信息架构

主要页面：

- 总览：运行状态、核心快捷操作、关键指标、模块化 Dashboard 项、AI 智能体。
- 配置：配置库、订阅导入、本地 YAML 导入、启用、更新、编辑、追加覆盖。
- 代理：代理组和节点选择、延迟测试、清除固定选择。
- Provider：proxy-provider 和 rule-provider 列表、更新、健康检查。
- 连接：连接列表、关闭连接、连接分析。
- 规则：规则列表、规则搜索、命中判断、启用/禁用。
- 内核：mihomo/runtime 设置，包含端口、TUN、DNS、监听器、日志级别等。
- 内核工具：reload/patch config、kernel restart、DNS/fake-IP/cache/storage/raw API 等。
- 日志：应用日志、内核日志、错误分析。
- 设置：Chumen 自身偏好、状态栏、同步、安全和 AI provider。

## 配置与运行模型

Chumen 维护配置库，但运行时会生成最终 YAML 给 mihomo 使用。

- 原始配置来自本地 YAML、远程订阅或从其他客户端导入。
- 配置文件和配置库默认受 age 保护。
- Chumen 生成 runtime YAML 时会覆盖自己拥有的端口、controller、secret、模式、TUN、DNS、监听器、allow-lan、IPv6、external UI、CORS、hosts 等运行项。
- 追加覆盖是 Chumen 的 profile 扩展能力，不是 mihomo 原生字段。Chumen 在生成 runtime YAML 时把它合并进标准 mihomo YAML。
- 运行中的内核可以通过 controller reload；内核未运行时，配置修改会在下次启动生效。

## 追加覆盖协议

追加覆盖用于在不破坏原始订阅/配置的前提下增删列表项。适用 section：

- `proxies`
- `proxy-groups`
- `rules`

三个操作：

- 前置追加 `prepend`：条目放到原始列表前面，适合让规则更早命中或让节点优先出现。
- 后置追加 `append`：条目放到原始列表后面，适合补充节点、规则或分组。
- 删除原始项 `delete`：按完整规则行或节点/代理组名称从原始列表中移除。

GUI 应突出这是“追加覆盖”，不要让用户误以为正在直接改原始订阅文件。

## 常见工作流

### 添加代理节点

添加代理是配置编辑问题，不需要先连上内核 API。

1. 打开“配置”。
2. 找到目标配置，进入“编辑节点”。
3. 在“追加覆盖”里选择“前置追加 prepend”或“后置追加 append”。
4. 填名称、节点类型、服务器、端口和协议字段。
5. 节点类型和端口必须允许手动输入，不能只允许选择预设值。
6. 保存后应用或重载运行配置；如果内核未运行，下次启动生效。

如果用户有订阅 URL，应优先导入订阅；如果要让流量实际走新节点，还需要把节点加入代理组并调整规则。

### 添加规则

1. 打开“配置”，进入目标配置的“编辑规则”。
2. 选择 `prepend`、`append` 或 `delete`。
3. 用表单选择或输入规则类型、匹配内容和目标策略。
4. 目标策略应优先从当前代理组和内置项 `DIRECT`、`REJECT`、`REJECT-DROP`、`PASS` 中选择，同时允许手动输入。
5. 保存后应用或重载。

规则页的搜索/命中判断是运行态辅助能力；配置编辑本身不依赖内核 API。

### 添加代理组

1. 打开“配置”，进入“编辑代理组”。
2. 填名称和分组类型，例如 `select`、`url-test`、`fallback`、`load-balance`，并允许自定义。
3. 从现有节点、代理组和内置项中选择成员，也允许手动输入。
4. 保存后应用或重载。

### 开关系统代理

系统代理是 macOS 外部状态，由 Chumen 通过 `networksetup` 管理。状态属于应用级外部状态，应由统一更新调度器刷新。停止内核时可以按设置自动清理系统代理。

### 开关 TUN

TUN 是启动级配置。运行中切换 TUN 需要重启内核；macOS 上可能需要特权 helper。退出 Chumen 时必须停止由 Chumen 启动的内核，并按设置关闭 TUN/系统代理，避免残留。

## 智能体行为边界

智能体可以：

- 回答 Chumen 使用方法和 mihomo 配置相关问题。
- 生成待审核的配置草稿。
- 提出导入订阅、设置模式、开关 TUN、开关系统代理、追加 YAML、reload runtime config 等变更。

智能体不可以：

- 在用户点击应用前直接修改配置或运行状态。
- 声称修改已经完成，除非应用逻辑确实执行成功。
- 在教程类问题里把“无法连接内核 API”当作唯一回答。
- 记录或展示 API Key、PIN、age 私钥、controller secret、带凭据订阅 URL 或解密配置内容。

对“如何添加代理”“怎么写规则”“怎么导入订阅”这类教程问题，应先用 Chumen 应用知识库回答。只有用户明确问实时代理列表、连接、规则、流量、内核工具或诊断时，才需要依赖内核 API。

## 错误解释

- 无法连接内核 API：实时 controller 不可达。影响实时状态和内核工具，不影响配置编辑教程。
- 内核未启动：代理、连接、规则、流量、内存等运行态数据不可用。
- 外部内核占用控制端口：controller 有响应但进程不是 Chumen 启动的，Chumen只能读取状态，不应接管 stop/restart 语义。
- 配置保护/PIN 问题：参见 `docs/security-model.zh.md`，不要把 PIN 保护等同于应用锁屏。

## 可用的外部 mihomo 知识库

如果本机存在这些路径，可以把它们作为 mihomo 内核知识库来源：

- `/Volumes/SanDisk/code/mihomo/docs/human`
- `/Volumes/SanDisk/code/mihomo/omx_wiki`

接入建议：

- 不要在应用里硬编码绝对磁盘路径。
- 构建或导入时应复制/索引为 Chumen 管理的知识来源。
- Chumen 应用知识优先决定“用户应该点哪里”；mihomo 知识再补充“字段应该怎么写”。
