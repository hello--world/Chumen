# Mihomo 小白学习知识库

这套文档是给人读的，不假设你已经懂代理内核、Go 网络编程或这个项目的历史。目标是让你能一步步从“能跑起来”走到“能定位问题、能小范围改代码”。

## 先明确学习目标

你读完后应该能回答：

1. Mihomo 是什么，它在一条网络请求里负责哪一段。
2. `main.go` 启动后会调用哪些模块。
3. YAML 配置如何变成运行时对象。
4. 入站 listener、规则 rules、出站 adapter、核心 tunnel 分别干什么。
5. 一条 TCP 或 UDP 流量在源码里怎么走。
6. 新增一个规则、出站协议、入站 listener 或 API 应该改哪些文件。
7. 出问题时先看日志、配置、API、源码的哪一层。

## 学习顺序

建议按章节顺序读，不要一开始读协议细节。

| 顺序 | 文档 | 目标 |
| --- | --- | --- |
| 1 | [01-first-run-and-mental-model.md](01-first-run-and-mental-model.md) | 会编译、会运行、知道整体模型 |
| 2 | [02-source-map-and-startup.md](02-source-map-and-startup.md) | 看懂目录和启动调用链 |
| 3 | [03-config-to-runtime.md](03-config-to-runtime.md) | 看懂配置字段如何生效 |
| 4 | [04-traffic-lifecycle.md](04-traffic-lifecycle.md) | 看懂 TCP/UDP 如何被转发 |
| 5 | [05-development-recipes.md](05-development-recipes.md) | 学会按配方做小改动 |
| 6 | [06-debugging-and-faq.md](06-debugging-and-faq.md) | 学会定位常见问题 |
| 7 | [07-reading-checklist-and-ai-questions.md](07-reading-checklist-and-ai-questions.md) | 自检学习成果，并学会让 AI 基于知识库回答 |
| 8 | [08-tun-and-macos-native-networking.md](08-tun-and-macos-native-networking.md) | 看懂 Mihomo TUN 与 macOS 原生 NetworkExtension 的区别 |

## 你需要的前置知识

最低要求：

- 会在终端执行命令。
- 大概知道 YAML 是配置文件格式。
- 大概知道 HTTP、SOCKS、TCP、UDP 是网络相关概念。
- 会读一点 Go 代码，不会也没关系，本文档会告诉你先看哪里。

暂时不要求：

- 不要求会写代理协议。
- 不要求懂 TUN、TPROXY、iptables。
- 不要求懂所有加密和握手细节。
- 不要求先读完 `transport/`。

## 最重要的心智模型

把 Mihomo 想成一个“流量分拣中心”：

```text
本地应用
  -> 入站入口 listener
  -> 统一流量上下文 Metadata
  -> 核心调度 tunnel
  -> 规则匹配 rules
  -> 出站代理 adapter
  -> 远端网络
```

你刚开始只需要抓住四个词：

- `listener`：流量从哪里进来。
- `Metadata`：这条流量的目标、来源、协议、进程等信息。
- `rules`：根据 Metadata 判断走哪个代理。
- `adapter`：真正把流量拨出去。

## 建议读源码时使用的路线

第一轮只读这些文件：

```text
main.go
config/config.go
hub/hub.go
hub/executor/executor.go
listener/listener.go
adapter/parser.go
rules/parser.go
tunnel/tunnel.go
```

第二轮再读：

```text
constant/metadata.go
constant/adapters.go
constant/tunnel.go
listener/parse.go
adapter/adapter.go
adapter/outboundgroup/parser.go
dns/server.go
dns/service.go
component/resolver/resolver.go
```

第三轮按你的目标选：

- 想懂配置：继续读 `config/config.go`。
- 想懂规则：读 `rules/common/`。
- 想懂代理协议：读 `adapter/outbound/` 再读 `transport/`。
- 想懂 API：读 `hub/route/`。
- 想懂 DNS：读 `dns/` 和 `component/resolver/`。
- 想懂 TUN 和 macOS 原生 VPN：读 [08-tun-and-macos-native-networking.md](08-tun-and-macos-native-networking.md)，再读 `listener/sing_tun/`。

## 和 AI 知识库的关系

人读版帮助你理解，AI 版帮助智能体回答问题和追加知识。

AI 版在：

```text
omx_wiki/index.md
```

如果你问 AI “这个项目某个功能在哪里实现”，AI 应该优先查 `omx_wiki/index.md`，再按索引进入对应页面。

## 这套文档不做什么

为了让小白能抓住主线，这套文档不会逐行解释每个协议、每个配置字段、每个 REST 响应结构。

它优先讲：

- 主启动链路
- 配置进入运行态的路径
- TCP/UDP 流量主路径
- 常见扩展和调试方法
- 如何继续借助 AI 知识库查源码

如果你要深入某个协议、某个 API JSON schema 或某个平台的透明代理细节，先看 [07-reading-checklist-and-ai-questions.md](07-reading-checklist-and-ai-questions.md)，再让 AI 按 `omx_wiki/index.md` 的路由去补充知识库。
