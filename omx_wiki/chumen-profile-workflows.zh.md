---
title: "Chumen 配置与追加覆盖工作流"
tags: ["chumen", "profiles", "append-overlay", "proxies", "rules", "proxy-groups"]
created: 2026-07-05T14:30:00Z
updated: 2026-07-05T14:30:00Z
sources:
  - README.zh.md
  - Sources/ChumenMacApp/ProfilesView.swift
  - Sources/ChumenMacApp/ProfileYAMLVisualForms.swift
  - Sources/ChumenMacApp/ProfileYAMLVisualEditor.swift
links:
  - chumen-profile-workflows.en.md
  - chumen-runtime-and-system.zh.md
category: reference
confidence: high
schemaVersion: 1
---

# Chumen 配置与追加覆盖工作流

English version: [chumen-profile-workflows.en.md](chumen-profile-workflows.en.md)

## 配置来源

配置可以来自：

- 新建空配置。
- 导入本地 YAML。
- 导入远程订阅 URL。
- 扫描其他客户端，例如 Clash Verge、ClashX、Mihomo Party 或常见 `.config` 目录。

导入后，Chumen 会复制配置到自己的配置库并按内容去重。配置库索引和配置文件默认受 age 保护。

## 配置页主要操作

- 新建配置：创建空 YAML，然后进入编辑。
- 导入本地：选择本地 YAML 文件。
- 导入订阅：填写订阅 URL 和可选显示名。
- 从客户端导入：扫描本机常见客户端数据目录。
- 编辑：直接编辑完整 YAML。
- 编辑规则：只编辑 `rules` 的追加覆盖。
- 编辑节点：只编辑 `proxies` 的追加覆盖。
- 编辑代理组：只编辑 `proxy-groups` 的追加覆盖。
- 直接更新：重新下载订阅。
- 代理更新：通过当前代理更新订阅。
- 扩展覆盖配置：编辑 Chumen 的 profile appendix。
- 打开文件：打开配置文件位置。
- 删除：从 Chumen 配置库移除该配置。

## 追加覆盖协议

追加覆盖只影响 Chumen 生成的 runtime YAML，不应改写原始订阅文件。

支持 section：

- `rules`
- `proxies`
- `proxy-groups`

操作：

- `prepend`：放到原始列表前。
- `append`：放到原始列表后。
- `delete`：从原始列表删除完整规则行或指定名称。

生效路径：

1. 用户保存追加覆盖。
2. Chumen 下次生成 runtime YAML 时合并原始配置和追加覆盖。
3. 内核运行时可以 reload；内核停止时下次启动生效。

## 添加代理节点

这是配置编辑任务，不要求内核 API 在线。

1. 打开“配置”。
2. 找到目标配置。
3. 点“编辑节点”。
4. 在快捷新增节点里选择 `prepend` 或 `append`。
5. 填名称、节点类型、服务器、端口和协议字段。
6. 节点类型、端口、cipher 等字段应允许手动输入，同时提供常用值菜单。
7. 保存后应用或重载。

常见节点字段：

- 通用：`name`、`type`、`server`、`port`、`udp`。
- `ss`：`cipher`、`password`。
- `vmess`/`vless`：`uuid`、`tls`、`servername`。
- `trojan`/`hysteria2`：`password`、`tls`、`sni`。
- `http`/`socks5`：`username`、`password`。
- 未覆盖的高级字段应通过“额外字段”或高级 YAML 补充。

## 添加代理组

1. 打开“配置”。
2. 找到目标配置并点“编辑代理组”。
3. 选择 `prepend` 或 `append`。
4. 填代理组名称和类型。
5. 添加成员。成员可以来自已有节点、已有代理组、`DIRECT`、`REJECT` 等，也允许手动输入。
6. 对 `url-test`、`fallback`、`load-balance` 等组补充测试 URL、间隔、策略等字段。

代理组决定用户在“代理”页能切换什么。新增节点如果没有加入任何代理组，通常不会被规则使用。

## 添加规则

1. 打开“配置”。
2. 找到目标配置并点“编辑规则”。
3. 选择 `prepend`、`append` 或 `delete`。
4. 填规则类型、匹配内容、目标策略和附加参数。
5. 目标策略优先从当前代理组和内置项里选，也允许手动输入。

常见规则类型：

- `DOMAIN-SUFFIX`
- `DOMAIN`
- `DOMAIN-KEYWORD`
- `IP-CIDR`
- `GEOIP`
- `PROCESS-NAME`
- `MATCH`

规则顺序重要。需要优先生效的规则使用 `prepend`。

## 删除原始项

`delete` 用于从原始配置中移除列表项：

- 删除规则时填写完整规则行。
- 删除节点或代理组时填写名称。

删除是追加覆盖的一部分，仍然不改写原始订阅。

## 保存与应用

- 保存表单只更新 Chumen 管理的配置扩展。
- 应用或 reload 会重新生成 runtime YAML。
- 如果内核运行且 API 可用，可以热重载。
- 如果 API 不可用或内核停止，修改保留在配置库，下次启动时生效。
