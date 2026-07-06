# 05. 新增功能和改代码配方

这一章给你“按步骤改代码”的路线。先从小改动开始，不要一上来新增完整协议。

## 1. 修改前先判断改哪一层

拿到需求时，先判断属于哪层：

| 需求 | 主要改哪里 |
| --- | --- |
| 新增 YAML 字段 | `config/` + `hub/executor/` |
| 新增规则类型 | `rules/` |
| 新增出站协议 | `adapter/outbound/` + `transport/` |
| 新增入站类型 | `listener/inbound/` + `listener/parse.go` |
| 新增 API | `hub/route/` |
| 改 DNS 行为 | `dns/` + `component/resolver/` |
| 改流量调度 | `tunnel/` |
| 改 provider | `adapter/provider/` 或 `rules/provider/` + `component/resource/` |

## 2. 新增配置字段

假设要新增：

```yaml
example-feature: true
```

步骤：

1. 在 `RawConfig` 增加字段和 yaml tag。
2. 如果需要默认值，在 `DefaultRawConfig` 设置。
3. 在对应 parse 函数里转换。
4. 在 `Config` 或子结构里增加运行时字段。
5. 在 `executor.ApplyConfig` 合适位置应用。
6. 如果 API 要展示，修改 `hub/route/configs.go`。
7. 增加测试。

判断问题：

- 这个字段是启动期一次性生效，还是热更新也要生效？
- 生效时是否要关闭旧资源？
- 是否涉及文件路径和安全路径？

## 3. 新增规则类型

假设新增：

```yaml
rules:
  - FOO,bar,PROXY
```

步骤：

1. 在 `rules/common/` 新增 `foo.go`。
2. 实现规则结构体。
3. 实现规则接口需要的方法。
4. 在 `rules/parser.go` 的 switch 增加：

```go
case "FOO":
    parsed, parseErr = RC.NewFOO(payload, target)
```

5. 增加单元测试。

注意：

- 如果规则需要 IP，不要自己直接解析，尽量用 `helper.ResolveIP`。
- 如果规则需要进程，不要每次都查，使用 `helper.FindProcess`。
- 规则解析错误要带上 payload，方便配置排障。

验证：

```sh
go test ./rules/...
```

## 4. 新增出站协议

最小步骤：

1. 在 `adapter/outbound/` 新增协议文件。
2. 定义 Option 结构体。
3. 实现 `constant.ProxyAdapter`。
4. 如果协议复杂，在 `transport/<protocol>/` 写底层实现。
5. 在 `adapter/parser.go` 加 `type` 分支。
6. 增加测试。

必须关心的方法：

```text
Name
Type
Addr
SupportUDP
DialContext
ListenPacketContext
SupportUOT
Unwrap
Close
MarshalJSON
```

建议先参考：

- 简单：`adapter/outbound/direct.go`
- 中等：`adapter/outbound/http.go`
- 复杂：`adapter/outbound/vless.go`

验证：

```sh
go test ./adapter/outbound/...
go test ./transport/<protocol>/...
```

如果有集成测试：

```sh
cd test
make test
```

## 5. 新增入站 listener

如果是 `listeners:` 数组支持的新类型：

1. 在 `listener/inbound/` 新增实现。
2. 实现 `C.InboundListener`。
3. 在 `listener/parse.go` 增加 `type` 分支。
4. `Listen(tunnel)` 里接收连接后调用：
   - TCP：`tunnel.HandleTCPConn`
   - UDP：`tunnel.HandleUDPPacket`
5. 增加测试。

如果是顶层端口字段：

1. 改 `RawConfig`。
2. 改 `General` / `Inbound`。
3. 改 `parseGeneral`。
4. 改 `executor.updateListeners`。
5. 在 `listener/listener.go` 增加 `ReCreateXxx`。

## 6. 新增 API

API 在 `hub/route/`。

步骤：

1. 找到对应 router 文件。
2. 在 router 函数里注册路由。
3. handler 读取运行态数据。
4. 返回 JSON。
5. 写操作要考虑锁、热更新、权限和副作用。

常见文件：

| 文件 | 作用 |
| --- | --- |
| `server.go` | 顶层路由和认证 |
| `configs.go` | 配置查看和更新 |
| `proxies.go` | 代理 |
| `provider.go` | provider |
| `rules.go` | 规则 |
| `connections.go` | 连接 |
| `dns.go` | DNS 查询 |
| `cache.go` | 缓存 |

## 7. 修改 tunnel 要格外谨慎

`tunnel/` 是高风险区。

原因：

- 每条 TCP/UDP 都经过。
- 涉及并发。
- 涉及 NAT 表。
- 涉及 DNS、sniffer、规则、统计。

改之前先回答：

1. 会不会让每条连接多一次 DNS 查询？
2. 会不会让每条连接多一次进程查询？
3. UDP 会话什么时候释放？
4. 出错时连接是否关闭？
5. 是否影响 `direct/global/rule` 三种模式？

## 8. 推荐小白练手任务

从这些开始：

1. 给配置错误补更清楚的错误信息。
2. 给 `rules.ParseRule` 增加测试。
3. 给 `constant/path.go` 的安全路径补测试。
4. 给某个 API 返回增加只读字段。
5. 给文档补一个配置字段流向。

先不要做：

- 新增完整协议。
- 重写 DNS。
- 改 TUN 路由。
- 改 UDP NAT 表。
- 改 provider 更新循环。

## 9. 提交前检查

按修改范围选择：

```sh
go test ./rules/...
go test ./config ./constant
go test ./common/...
go test ./...
```

如果只改文档：

```sh
bin/mihomo-darwin-arm64 -d /private/tmp/mihomo-learning -t -f docs/learning-minimal.yaml
```

再检查工作区：

```sh
git status --short
```
