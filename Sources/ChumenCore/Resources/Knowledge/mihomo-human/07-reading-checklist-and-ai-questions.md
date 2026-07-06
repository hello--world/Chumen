# 07. 学习自检、源码定位和 AI 提问方式

前面 6 章解决“看懂项目”的主线问题。本章解决另一个问题：你怎么判断自己真的看懂了，以及怎么让 AI 智能体继续帮你查源码、补知识库、回答问题。

这章不要求你背代码。目标是让你有一套稳定的检查方法。

## 1. 学习闭环

每次学习一个模块，都按这个顺序走：

```text
先用一句话说清模块职责
  -> 找到入口函数
  -> 找到核心数据结构
  -> 找到它被谁调用
  -> 找到它调用谁
  -> 用最小配置或最小测试验证
  -> 把结论写回文档或知识库
```

例子：学习 `rules`。

```text
职责：把规则字符串解析成 Rule 对象，并在流量进入 tunnel 后参与匹配。
入口：config.parseRules、rules.ParseRule
核心结构：constant.Rule、rules/common/*
上游：config.ParseRawConfig
下游：tunnel.match
验证：写一条 DOMAIN-SUFFIX 规则，运行配置测试和流量测试
```

## 2. 每章读完要能回答什么

| 文档 | 读完后至少要能回答 |
| --- | --- |
| `01` | 我怎么编译、怎么用最小配置跑起来、`-d` 和 `-f` 是什么 |
| `02` | 程序从 `main.go` 到 `executor.ApplyConfig` 的启动顺序是什么 |
| `03` | 一个 YAML 字段如何从 `RawConfig` 变成运行时状态 |
| `04` | 一条 TCP/UDP 流量如何经过 listener、Metadata、tunnel、rules、adapter |
| `05` | 新增规则、出站、入站、API、配置字段时要改哪些文件 |
| `06` | 配置错误、端口不监听、规则不生效、UDP/DNS/provider/API 问题怎么排查 |

如果这些问题答不上来，先不要读协议细节，回到对应章节。

## 3. 源码定位速查

| 你想知道 | 先看 |
| --- | --- |
| 程序怎么启动 | `main.go` |
| 配置怎么解析 | `config/config.go` |
| 默认值在哪里 | `config.DefaultRawConfig` |
| 配置怎么应用 | `hub/hub.go`、`hub/executor/executor.go` |
| API 路由在哪里 | `hub/route/server.go` 和 `hub/route/*.go` |
| 入站端口怎么创建 | `listener/listener.go` |
| `listeners:` 怎么解析 | `listener/parse.go` |
| 出站代理怎么解析 | `adapter/parser.go` |
| 代理组怎么解析 | `adapter/outboundgroup/parser.go` |
| provider 怎么加载 | `adapter/provider/`、`rules/provider/`、`component/resource/` |
| 规则怎么解析 | `rules/parser.go`、`rules/common/` |
| 规则怎么匹配 | `tunnel/tunnel.go` |
| TCP/UDP 怎么转发 | `tunnel/tunnel.go`、`tunnel/connection.go` |
| DNS 怎么工作 | `dns/`、`component/resolver/`、`component/fakeip/` |
| 安全路径怎么判断 | `constant/path.go` |

## 4. 新手最容易误判的地方

| 误判 | 正确理解 |
| --- | --- |
| `proxies` 就是全部代理 | 运行时还包括 proxy group、provider 生成的代理、内置 DIRECT/REJECT/GLOBAL 等 |
| 改 YAML 就一定热更新 | 要看字段是否在 API patch、SIGHUP 或 `executor.ApplyConfig` 路径里被重新应用 |
| DNS 只影响域名解析 | fake-ip、hosts、nameserver-policy、respect-rules 都会影响后续规则匹配和连接目标 |
| 规则一定逐条匹配到 MATCH | UDP 场景下如果代理不支持 UDP，`tunnel.match` 可能继续找下一条可用规则 |
| listener 和 adapter 是一类东西 | listener 是入口，adapter 是出口，中间靠 Metadata 和 tunnel 连接 |
| provider 只是下载文件 | provider 还涉及 vehicle、缓存、过滤、健康检查、更新周期和运行时注入 |
| API 只是查询状态 | 部分 API 会修改运行态，例如切换 select 组、patch 配置、更新 provider、关闭连接 |

## 5. 怎么向 AI 提问

不建议这样问：

```text
这个项目怎么运行？
```

更好的问法：

```text
请基于 omx_wiki/index.md，解释 Mihomo 从 main.go 到 executor.ApplyConfig 的启动链路，并列出每一步对应源码文件。
```

不建议这样问：

```text
规则系统在哪？
```

更好的问法：

```text
请基于 omx_wiki/runtime-flows.md 和 omx_wiki/source-map.md，说明一条 DOMAIN-SUFFIX 规则从 YAML 解析到 tunnel.match 命中的完整路径。
```

不建议这样问：

```text
我想加一个功能。
```

更好的问法：

```text
我要新增一个 YAML 字段 example-feature，请基于 omx_wiki/config-field-index.md 和 omx_wiki/development-recipes.md，列出需要改的结构体、parse 函数、executor 更新点和测试方式。
```

## 6. 给 AI 的上下文顺序

如果你要把项目交给 AI 智能体回答问题，优先提供这些文件：

```text
omx_wiki/index.md
omx_wiki/source-map.md
omx_wiki/runtime-flows.md
omx_wiki/config-reference.md
omx_wiki/config-field-index.md
omx_wiki/api-route-map.md
omx_wiki/development-recipes.md
omx_wiki/debugging-playbook.md
```

如果问题和构建、测试、CI 有关，再加：

```text
omx_wiki/build-test-matrix.md
```

如果问题是“文档有没有漏”，再加：

```text
omx_wiki/documentation-audit.md
```

## 7. 这套文档的边界

这套文档重点覆盖项目主干，不试图替代完整协议手册。

已经重点覆盖：

- 启动流程
- 配置解析
- 运行时配置应用
- listener 入站
- adapter 出站
- rules 路由
- tunnel 转发
- DNS 主路径
- provider 主路径
- API 主路由
- 构建、测试、调试入口

没有逐项展开：

- 每个出站协议的握手细节
- 每个 DNS 上游协议的底层实现
- 每个平台的 TUN/TPROXY 系统调用细节
- 每个配置字段的完整用户手册
- 每个 REST API 的请求和响应 JSON schema

这些不是遗漏，而是学习文档的刻意边界。如果你要深入某一块，就按 `omx_wiki/source-map.md` 找源码，再把新结论追加到 AI 知识库。

## 8. 最终自检清单

读完人读版后，试着不用 AI 回答：

1. `bin/mihomo-darwin-arm64 -t -f config.yaml` 为什么不会真正启动代理？
2. `mixed-port` 从 YAML 到监听端口经过哪些函数？
3. `listeners:` 和顶层 `mixed-port` 的创建路径有什么不同？
4. 一个 proxy group 为什么既在 `proxies` 里表现为代理，又会拥有 provider 逻辑？
5. `MATCH,DIRECT` 放在第一条规则会发生什么？
6. UDP 代理不支持时，为什么规则匹配可能继续向下走？
7. `external-controller` 开启后，路由是在哪里挂载的？
8. provider 更新失败时，应该先看哪三个目录？
9. 安全路径错误应该看哪个文件？
10. 新增一个 API endpoint 应该改哪些文件，怎么验证？

这些题如果能答出 7 个以上，你已经可以开始小范围改代码。
