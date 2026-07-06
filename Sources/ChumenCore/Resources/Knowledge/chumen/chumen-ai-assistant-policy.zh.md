---
title: "Chumen 智能体策略"
tags: ["chumen", "ai", "assistant", "ollama", "review", "security"]
created: 2026-07-05T14:30:00Z
updated: 2026-07-05T14:30:00Z
sources:
  - docs/security-model.zh.md
  - DESIGN.zh.md
  - Sources/ChumenCore/ChumenAI.swift
  - Sources/ChumenMacApp/AIAssistantOverlayView.swift
  - Sources/ChumenMacApp/AppModel.swift
links:
  - chumen-ai-assistant-policy.en.md
  - chumen-knowledge-routing.zh.md
category: reference
confidence: high
schemaVersion: 1
---

# Chumen 智能体策略

English version: [chumen-ai-assistant-policy.en.md](chumen-ai-assistant-policy.en.md)

## Provider 模型

- 本地 Ollama 是默认优先路径，地址是 `http://127.0.0.1:11434/v1`。
- 本地 Ollama 不需要 API Key。
- 本地模型列表从 Ollama `/api/tags` 获取；用户也可以手动输入模型名。
- 自定义 OpenAI-compatible endpoint 需要 base URL、模型名和 Key。
- Key 存 Keychain，不能写入日志、UI 明文、通知或命令输出。
- 没有可用模型时，智能体入口可以退化为本地搜索。

## 输出协议

模型输出应是 JSON：

- `reply`：给用户看的短解释。
- `changes`：待审核变更列表。

允许的变更：

- `importSubscription`
- `setMode`
- `setTun`
- `setSystemProxy`
- `setConfigAppendix`
- `reloadRuntimeConfig`

所有变更都必须先进待审核队列。用户点击应用前，不得直接修改配置或运行状态。

## 本地帮助分流

教程类问题应优先走 Chumen 应用知识库，不必调用模型或内核 API。例如：

- 我要如何添加代理。
- 怎么导入订阅。
- 怎么添加规则。
- prepend 和 append 是什么。

这类回答必须说明入口、步骤和生效条件。不能只回答“无法连接内核 API”。

具体草稿生成请求仍应进入模型，例如“帮我添加一个 vless 节点，服务器是 1.1.1.1，端口 443”。

## 运行态问题

如果用户问的是当前代理列表、当前连接、当前规则、流量、内存、Provider 状态、DNS query 或 raw API，这些依赖内核 API。API 不可达时可以说明需要启动内核或检查 controller 端口。

## 审核边界

智能体必须：

- 说明修改是“等待审核”，不能声称已经应用。
- 给出类似 git diff 的可检查变更。
- 避免破坏性删除操作。
- 保持回答短，优先 4 条以内。
- 使用当前 UI 语言回答，除非用户要求其他语言。

智能体不得：

- 自动应用配置。
- 自动开关系统代理或 TUN。
- 自动导入订阅。
- 输出 API Key、PIN、controller secret、age 私钥、解密后的配置或带凭据订阅 URL。

## 与知识库的关系

Chumen 应用知识库回答“怎么用 Chumen”。mihomo 知识库回答“字段怎么写”。如果两个知识库都有相关内容，先解释 Chumen 的操作入口，再引用 mihomo 字段细节。
