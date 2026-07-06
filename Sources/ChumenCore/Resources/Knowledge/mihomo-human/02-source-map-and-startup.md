# 02. 目录地图和启动流程

这一章解决两个问题：

1. 这么多目录分别干什么。
2. 程序从 `main.go` 启动后到底走了哪些关键函数。

## 1. 先看顶层目录

| 路径 | 作用 | 新手读法 |
| --- | --- | --- |
| `main.go` | 程序入口 | 第一个读 |
| `config/` | YAML 配置解析 | 第二个读 |
| `hub/` | 应用配置、API、运行控制 | 和 config 一起读 |
| `hub/executor/` | 把配置分发到各模块 | 很重要 |
| `listener/` | 入站监听 | 先读 `listener/listener.go` |
| `adapter/` | 出站代理统一封装 | 先读 `adapter/parser.go` |
| `rules/` | 规则解析和匹配 | 先读 `rules/parser.go` |
| `tunnel/` | TCP/UDP 核心转发 | 最核心 |
| `dns/` | DNS 服务 | 后面读 |
| `component/` | 功能组件 | 遇到再读 |
| `constant/` | 接口、枚举、Metadata | 配合源码读 |
| `common/` | 通用工具 | 遇到再读 |
| `transport/` | 协议底层 | 不要一开始读 |
| `test/` | 协议集成测试 | 会跑后再看 |

## 2. 不建议一开始读 transport

`transport/` 里是具体协议细节，比如 VMess、VLESS、Hysteria、TUIC。

这些代码会涉及：

- 加密
- 握手
- 复用
- QUIC
- WebSocket
- TLS
- 协议兼容

新手先读这里会很容易迷路。你应该先看：

```text
配置怎么解析
流量怎么进入
规则怎么选代理
代理怎么被调用
```

等主链路懂了，再进入协议细节。

## 3. main.go 做了什么

`main.go` 可以分成几段：

1. 注册命令行参数。
2. 设置 DNS 默认 resolver 防误用。
3. 处理特殊子命令。
4. 处理版本输出。
5. 确定配置目录和配置文件。
6. 初始化配置目录。
7. 测试配置或启动运行。
8. 注册 updater。
9. 执行 post-up。
10. 等待系统信号。
11. 退出时清理。

## 4. 命令行参数

常用参数：

| 参数 | 作用 |
| --- | --- |
| `-d` | 配置目录 |
| `-f` | 配置文件路径 |
| `-config` | base64 编码配置字符串 |
| `-v` | 打印版本 |
| `-t` | 测试配置后退出 |
| `-ext-ui` | 覆盖 Web UI 目录 |
| `-ext-ctl` | 覆盖 RESTful API 地址 |
| `-secret` | 覆盖 API secret |
| `-post-up` | 启动后执行脚本 |
| `-post-down` | 退出前执行脚本 |

例子：

```sh
bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -t -f docs/learning-minimal.yaml
```

含义：

- 用 `/private/tmp/mihomo-learning` 当运行目录。
- 只测试配置。
- 配置文件是 `docs/learning-minimal.yaml`。

## 5. 特殊子命令

如果第一个参数是下面这些，程序不会进入正常代理启动流程：

| 子命令 | 进入函数 | 用途 |
| --- | --- | --- |
| `convert-ruleset` | `provider.ConvertMain` | 转换规则集 |
| `generate` | `generator.Main` | 生成密钥或辅助信息 |
| `age` | `age.Main` | age 加解密相关 |

这就是为什么 `main.go` 前面会先判断：

```text
os.Args[1] == "convert-ruleset"
os.Args[1] == "generate"
os.Args[1] == "age"
```

## 6. 正常启动调用链

最重要的调用链：

```text
main.go
  -> config.Init
  -> hub.Parse
    -> executor.Parse / executor.ParseWithBytes
      -> config.Parse
        -> UnmarshalRawConfig
        -> ParseRawConfig
    -> hub.ApplyConfig
      -> applyRoute
      -> executor.ApplyConfig
```

你可以把它拆成三层：

| 层 | 做什么 |
| --- | --- |
| `main.go` | 准备参数和生命周期 |
| `config` | 把 YAML 变成 `Config` |
| `executor` | 把 `Config` 应用到运行模块 |

## 7. config.Init 做什么

`config/initial.go`：

1. 如果配置目录不存在，就创建。
2. 如果配置文件不存在，就创建一个默认 `config.yaml`。

默认写入内容很小：

```yaml
mixed-port: 7890
```

所以第一次运行时，如果没指定 `-f`，它会尝试使用默认配置。

## 8. hub.Parse 做什么

`hub/hub.go`：

```text
Parse
  -> 如果传入 configBytes：executor.ParseWithBytes
  -> 否则：executor.Parse
  -> 应用命令行 option 覆盖
  -> ApplyConfig
```

命令行 option 包括：

- external UI
- external controller
- Unix socket
- Windows named pipe
- secret

这说明命令行参数可以覆盖 YAML 里的某些 controller 配置。

## 9. hub.ApplyConfig 做什么

```text
ApplyConfig
  -> applyRoute(cfg)
  -> executor.ApplyConfig(cfg, true)
```

`applyRoute` 管 API：

```text
Controller 配置
  -> route.SetUIPath
  -> route.ReCreateServer
```

`executor.ApplyConfig` 管核心运行态：

```text
代理
规则
DNS
入站
TUN
NTP
iptables
provider
profile
updater
```

## 10. executor.ApplyConfig 的顺序

这是很重要的一段：

```text
log.SetLevel
tunnel.OnSuspend
更新证书
updateExperimental
updateUsers
updateProxies
updateRules
updateSniffer
updateHosts
updateGeneral
updateNTP
updateDNS
updateListeners
updateTun
updateIPTables
updateTunnels
tunnel.OnInnerLoading
initInnerTcp
loadProvider
updateProfile
loadProvider(ruleProviders)
runtime.GC
tunnel.OnRunning
updateUpdater
resolver.ResetConnection
```

先不用背下来，只要知道：

1. 先暂停 tunnel。
2. 更新所有运行模块。
3. 加载 provider。
4. 最后进入 running。

## 11. tunnel 状态

`tunnel/status.go` 里有三个状态：

| 状态 | 含义 |
| --- | --- |
| `suspend` | 暂停，普通流量不处理 |
| `inner` | 只允许内部流量 |
| `running` | 正常运行 |

`executor.ApplyConfig` 里切换状态，是为了配置热更新时减少不一致。

## 12. SIGHUP 热更新

`main.go` 监听：

| 信号 | 行为 |
| --- | --- |
| `SIGINT` / `SIGTERM` | 退出 |
| `SIGHUP` | 重新执行 `hub.Parse` |

这意味着修改配置后可以用 SIGHUP 触发重新加载。

但要注意，是否完全无感取决于各模块的 `ReCreate` 逻辑。

## 13. 本章练习

练习 1：在源码里找到这些函数：

```text
main.go: main
hub/hub.go: Parse
hub/hub.go: ApplyConfig
hub/executor/executor.go: ApplyConfig
config/config.go: ParseRawConfig
```

练习 2：画出你自己的启动流程图，只写函数名。

练习 3：思考一个问题：

```text
为什么不是 config.Parse 直接启动 listener，而是要经过 hub/executor？
```

答案方向：

- 配置解析和运行态应用分离。
- 便于测试配置。
- 便于热更新。
- 便于 API 或命令行覆盖配置。
