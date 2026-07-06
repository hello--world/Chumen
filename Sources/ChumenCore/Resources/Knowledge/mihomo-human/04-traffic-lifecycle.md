# 04. TCP/UDP 流量生命周期

这一章讲一条真实流量在 Mihomo 里怎么走。读懂这一章，你就掌握了项目主干。

## 1. 一条 TCP 请求的总体路径

```text
本地应用
  -> listener
  -> Metadata
  -> tunnel.HandleTCPConn
  -> handleTCPConn
  -> preHandleMetadata
  -> sniffer 可选
  -> resolveMetadata
  -> match rules
  -> proxy.DialContext
  -> common/net.Relay
```

对应关键源码：

| 步骤 | 文件 |
| --- | --- |
| listener 接收连接 | `listener/*` |
| 创建 Metadata | `adapter/inbound/`、`listener/*` |
| TCP 入口 | `tunnel/tunnel.go` |
| Metadata 定义 | `constant/metadata.go` |
| 规则匹配 | `tunnel.match`、`rules/` |
| 出站拨号 | `adapter/outbound/*` |
| 双向转发 | `common/net` |

## 2. Metadata 是什么

`Metadata` 在 `constant/metadata.go`。

它是一条连接的“身份证”。

重要字段：

| 字段 | 解释 |
| --- | --- |
| `NetWork` | tcp 或 udp |
| `Type` | 入站类型，例如 HTTP、SOCKS5、TUN |
| `SrcIP` / `SrcPort` | 来源地址 |
| `DstIP` / `DstPort` | 目标 IP 和端口 |
| `Host` | 目标域名 |
| `InName` | 入站名称 |
| `InUser` | 入站用户 |
| `Process` | 进程名 |
| `ProcessPath` | 进程路径 |
| `SpecialProxy` | 指定代理 |
| `SpecialRules` | 指定规则 |
| `SniffHost` | 嗅探出来的域名 |

为什么 Metadata 重要：

- 规则匹配靠它。
- DNS fake-ip 还原靠它。
- 日志输出靠它。
- API 连接信息靠它。
- 出站拨号也要靠它。

## 3. handleTCPConn 细节

`tunnel/tunnel.go` 的 `handleTCPConn` 大致做：

```text
检查 tunnel 状态
关闭保护 defer conn.Close
检查 metadata 是否有效
fixMetadata
preHandleMetadata
如果开启 sniffer，尝试嗅探域名
如果仍然失败，返回
resolveMetadata 选择代理
处理 hosts 映射
retry proxy.DialContext
记录日志
包装统计 tracker
handleSocket 双向转发
```

### fixMetadata

修正目标地址：

- 把 IPv4-mapped IPv6 还原。
- 如果 `Host` 实际是 IP 字符串，就移到 `DstIP`。

### preHandleMetadata

处理 DNS 映射：

- 如果只有 fake-ip，尝试找回域名。
- 如果 hosts 有映射，修正目标。
- 如果 fake-ip 记录丢失，返回错误。

### sniffer

如果开启嗅探，会尝试从 TCP 数据里识别：

- TLS SNI
- HTTP Host
- QUIC 信息

嗅探出来的域名进入 `SniffHost`，规则匹配时 `RuleHost()` 会优先使用它。

## 4. resolveMetadata

这是选择代理的核心函数。

流程：

```text
如果 metadata.SpecialProxy 不为空：
  -> 直接找这个代理

否则：
  -> 处理 hosts
  -> 创建 RuleMatchHelper
  -> 根据 find-process-mode 决定是否查进程
  -> 根据 mode 选择：
       direct -> DIRECT
       global -> GLOBAL
       rule   -> match(metadata, helper)
```

## 5. match 规则匹配

`tunnel.match`：

```text
for rule in getRules(metadata):
  if rule.Match(metadata, helper):
    找到目标代理
    如果代理链里有 PASS：跳过
    如果 UDP 但代理不支持 UDP：跳过
    返回代理和规则

没有命中：返回 DIRECT
```

这解释了几个现象：

- 规则写了但代理名错了，可能继续走后面的规则。
- UDP 命中一个不支持 UDP 的节点，会继续找下一条。
- 没有规则命中时默认直连。

## 6. RuleMatchHelper 为什么重要

规则匹配有些操作很贵：

- DNS 解析
- 查询进程名

所以 Mihomo 不会每条连接都直接做这些操作，而是把能力放进 helper。

规则需要时才调用：

```text
helper.ResolveIP()
helper.FindProcess()
helper.CheckPassRule()
```

这是一种延迟计算。

## 7. 出站拨号

TCP 最终会调用：

```go
proxy.DialContext(ctx, dialMetadata)
```

这个 `proxy` 可能是：

- 具体节点，例如 Shadowsocks。
- 代理组，例如 select。

如果是代理组，它会通过 `Unwrap` 找到实际节点。

拨号成功后：

```text
statistic.NewTCPTracker
handleSocket
  -> common/net.Relay
```

## 8. 一条 UDP 包的总体路径

```text
本地 UDP 包
  -> listener
  -> tunnel.HandleUDPPacket
  -> UDP worker queue
  -> handleUDPConn
  -> natTable
  -> packetSender
  -> resolveMetadata
  -> proxy.ListenPacketContext
  -> handleUDPToRemote
  -> handleUDPToLocal
```

UDP 和 TCP 最大不同：

- TCP 是连接。
- UDP 是一包一包的。
- Mihomo 需要用 NAT 表把多个 UDP 包归到同一个会话。

## 9. UDP worker

`HandleUDPPacket` 会：

1. 初始化 UDP workers。
2. 用 packet key 做 hash。
3. 把包放到某个 worker queue。
4. 如果 queue 满了就 drop。

这样做是为了：

- 并发处理 UDP。
- 同一会话尽量进同一个队列。
- 避免无限堆积。

## 10. natTable 和 packetSender

`natTable` 用于记录 UDP 会话。

如果一个 key 第一次出现：

```text
创建 packetSender
创建远端 PacketConn
启动 handleUDPToLocal
启动 sender.Process
```

之后同一个 key 的包：

```text
直接 sender.Send(packet)
```

`packetSender` 保证：

- UDP 包顺序进入远端连接。
- queue 满了会丢包。
- 会话关闭时会清理队列。
- 回包地址能恢复成原始目标。

## 11. UDP 出站

UDP 最终调用：

```go
proxy.ListenPacketContext(ctx, dialMetadata)
```

这和 TCP 的 `DialContext` 不同。

如果某代理 `SupportUDP()` 为 false，规则匹配时会跳过它。

## 12. 日志怎么看

`tunnel.logMetadata` 会打印类似：

```text
[TCP] source --> target match RULE(payload) using chain
```

例如：

```text
[TCP] 127.0.0.1:50000 --> example.org:443 match DomainSuffix(example.org) using node-a
```

如果 direct mode：

```text
using DIRECT
```

如果 global mode：

```text
using GLOBAL
```

## 13. 本章练习

练习 1：打开 `tunnel/tunnel.go`，只看函数名，找出：

```text
HandleTCPConn
HandleUDPPacket
handleTCPConn
handleUDPConn
resolveMetadata
match
retry
```

练习 2：解释这句话：

```text
listener 不决定走哪个节点，tunnel 才决定。
```

练习 3：查 `constant/metadata.go`，找出 `Host`、`DstIP`、`SniffHost` 的区别。
