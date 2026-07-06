---
title: "Chumen 知识库路由"
tags: ["chumen", "knowledge-base", "routing", "mihomo", "assistant"]
created: 2026-07-05T14:30:00Z
updated: 2026-07-05T14:30:00Z
sources:
  - omx_wiki/chumen-application-knowledge-base.zh.md
  - README.zh.md
  - DESIGN.zh.md
  - /Volumes/SanDisk/code/mihomo/docs/human/README.md
  - /Volumes/SanDisk/code/mihomo/omx_wiki/index.md
links:
  - chumen-knowledge-routing.en.md
  - chumen-application-knowledge-base.zh.md
  - chumen-profile-workflows.zh.md
  - chumen-runtime-and-system.zh.md
  - chumen-ai-assistant-policy.zh.md
  - chumen-troubleshooting.zh.md
category: reference
confidence: high
schemaVersion: 1
---

# Chumen 知识库路由

English version: [chumen-knowledge-routing.en.md](chumen-knowledge-routing.en.md)

## 完整性标准

Chumen 知识库至少要能回答五类问题：

1. 应用入口：用户应该去哪个页面、点哪个按钮。
2. 配置工作流：如何导入、编辑、追加覆盖、应用或重载。
3. 运行状态：哪些数据依赖内核 API，哪些是 Chumen 离线状态。
4. 安全与 AI：哪些操作必须审核、哪些秘密不能暴露。
5. 排障：常见错误代表什么，下一步看哪里。

如果问题涉及 mihomo YAML 字段、代理协议、controller API 端点或内核源码，再进入 mihomo 知识库。

## 查询路由

| 用户问题 | 优先读取 |
| --- | --- |
| Chumen 是什么、有哪些页面 | [[chumen-application-knowledge-base.zh]] |
| 如何添加代理、规则、代理组、订阅 | [[chumen-profile-workflows.zh]] |
| 追加覆盖 prepend/append/delete 怎么用 | [[chumen-profile-workflows.zh]] |
| 启动/停止/重启、系统代理、TUN、端口 | [[chumen-runtime-and-system.zh]] |
| 哪些状态需要内核 API | [[chumen-runtime-and-system.zh]] |
| 智能体应该怎么回答、能不能直接改配置 | [[chumen-ai-assistant-policy.zh]] |
| 无法连接内核 API、配置不生效、TUN 失败 | [[chumen-troubleshooting.zh]] |
| mihomo 配置字段、协议字段、controller API | `/Volumes/SanDisk/code/mihomo/omx_wiki/index.md` |
| mihomo 入门和源码学习 | `/Volumes/SanDisk/code/mihomo/docs/human/README.md` |

## 回答策略

- 先判断问题是 Chumen 应用操作还是 mihomo 内核细节。
- 应用操作问题不能只回答“无法连接内核 API”。
- 需要写 YAML 时，先说明 Chumen 入口和审核方式，再给字段层面的 mihomo 内容。
- 涉及当前运行态时，要说明需要内核 API 在线。
- 涉及安全、配置写入、系统代理、TUN、导入订阅时，要说明“待审核/应用后生效”的边界。

## 外部 mihomo 知识库接入建议

当前可用路径：

- `/Volumes/SanDisk/code/mihomo/docs/human`
- `/Volumes/SanDisk/code/mihomo/omx_wiki`

这些路径适合开发环境，不适合硬编码到发布版 Chumen。发布或同步时应复制到 Chumen 管理目录，或建立用户可配置的知识库路径。
