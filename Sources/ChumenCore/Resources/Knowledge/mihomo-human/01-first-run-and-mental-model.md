# 01. 先跑起来，并建立整体模型

这一章只做三件事：

1. 编译项目。
2. 用最小配置验证程序能解析配置。
3. 建立“请求如何穿过 Mihomo”的心智模型。

## 1. 编译

项目是 Go 项目，根目录有：

```text
go.mod
Makefile
main.go
```

最直接的编译命令：

```sh
go build -tags with_gvisor
```

更推荐先用 Makefile，因为它会写入版本和构建时间：

```sh
make darwin-arm64
```

在当前 macOS arm64 机器上，这会生成：

```text
bin/mihomo-darwin-arm64
```

检查版本：

```sh
bin/mihomo-darwin-arm64 -v
```

你应该看到类似：

```text
Mihomo Meta <version> darwin arm64 with go<version> <build-time>
Use tags: with_gvisor
```

## 2. 最小配置

学习阶段不要直接用 `docs/config.yaml`，它是完整参考模板，里面有很多示例和占位路径。

先用：

```text
docs/learning-minimal.yaml
```

内容：

```yaml
mixed-port: 10801
allow-lan: false
mode: rule
log-level: info

rules:
  - MATCH,DIRECT
```

它表示：

- 本机开一个 mixed 代理端口 `10801`。
- 不允许局域网访问。
- 使用 rule 模式。
- 所有流量都匹配 `MATCH,DIRECT`，也就是直连。

验证配置：

```sh
bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -t -f docs/learning-minimal.yaml
```

重点看最后一行是否是：

```text
configuration file .../docs/learning-minimal.yaml test is successful
```

## 3. 为什么命令里要带 `-d`

`-d` 是配置目录。默认目录通常是：

```text
$HOME/.config/mihomo
```

如果你在权限受限环境、沙箱、CI 或某些工具里运行，默认目录可能不能写。

所以学习阶段推荐显式指定：

```sh
-d /private/tmp/mihomo-learning
```

这能减少很多和源码无关的权限问题。

## 4. 运行程序

运行最小配置：

```sh
bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -f docs/learning-minimal.yaml
```

你应该能看到初始化日志。此时本机 `127.0.0.1:10801` 会监听 mixed 代理。

mixed 的意思是同一个端口可以处理：

- HTTP 代理请求
- SOCKS 代理请求

## 5. 第一张流程图

最小配置下，一条请求大概这样走：

```text
浏览器或 curl
  -> 127.0.0.1:10801
  -> mixed listener
  -> tunnel
  -> rules
  -> MATCH,DIRECT
  -> DIRECT 出站
  -> 目标网站
```

把每一层翻译成人话：

| 层 | 人话解释 | 主要源码 |
| --- | --- | --- |
| 应用 | 浏览器、curl、系统代理产生请求 | 不在本项目 |
| mixed listener | 接住本地请求，识别 HTTP 或 SOCKS | `listener/mixed/` |
| Metadata | 记录这条请求要去哪里 | `constant/metadata.go` |
| tunnel | 核心调度，决定怎么转发 | `tunnel/tunnel.go` |
| rules | 判断该走哪个代理 | `rules/` |
| DIRECT | 直接连接目标 | `adapter/outbound/direct.go` |

## 6. 最小配置对应源码

配置：

```yaml
mixed-port: 10801
mode: rule
rules:
  - MATCH,DIRECT
```

大致流向：

```text
mixed-port
  -> config.parseGeneral
  -> executor.updateListeners
  -> listener.ReCreateMixed

mode
  -> config.parseGeneral
  -> executor.updateGeneral
  -> tunnel.SetMode

rules
  -> config.parseRules
  -> rules.ParseRule
  -> tunnel.UpdateRules
```

你不用马上看懂每行代码，但要知道“配置不是直接生效的”，它会先变成 Go 结构体，再由 executor 应用到运行模块。

## 7. 新手最容易混淆的几个词

### 入站和出站

入站是本地流量进入 Mihomo：

```text
浏览器 -> Mihomo
```

出站是 Mihomo 把流量发出去：

```text
Mihomo -> 目标网站或代理服务器
```

### listener 和 adapter

`listener` 管“进来”。

`adapter` 管“出去”。

### rule 和 mode

`mode` 是全局模式：

- `direct`：全部直连。
- `global`：全部走 GLOBAL。
- `rule`：按规则走。

`rule` 是具体规则：

```text
DOMAIN-SUFFIX,google.com,PROXY
MATCH,DIRECT
```

### proxy 和 proxy group

proxy 是一个具体节点，例如 `node-a`。

proxy group 是一组节点，例如：

```yaml
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - node-a
      - DIRECT
```

规则的目标可以是具体 proxy，也可以是 proxy group。

## 8. 本章练习

练习 1：修改 `docs/learning-minimal.yaml` 的端口：

```yaml
mixed-port: 10802
```

再运行：

```sh
bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -t -f docs/learning-minimal.yaml
```

练习 2：把日志改成 debug：

```yaml
log-level: debug
```

观察启动日志有什么变化。

练习 3：打开源码，找到这些函数：

```text
main.go                 -> main
config/config.go        -> ParseRawConfig
hub/executor/executor.go -> ApplyConfig
listener/listener.go    -> ReCreateMixed
tunnel/tunnel.go        -> handleTCPConn
```

先不用看懂全部，只要能定位到它们。
