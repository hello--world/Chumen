# Chumen

Chumen 是一个 macOS 原生 SwiftUI 客户端，用来启动、控制和观察本机 `mihomo` 内核。GUI 和 CLI 共享同一套 `ChumenCore`，因此界面里的核心能力都可以通过命令行验证。

English version: [README.en.md](README.en.md)

## 项目结构

```text
Package.swift                 Swift Package 定义
Sources/ChumenCore            内核交互、配置生成、订阅管理、系统代理、特权 helper
Sources/ChumenMacApp          SwiftUI/AppKit GUI、状态栏菜单、窗口生命周期
Sources/ChumenCLI             chumenctl 命令行入口
Sources/ChumenHelper          TUN 场景下使用的特权 helper
Packaging/Info.plist          macOS App Bundle 元数据
scripts/build_app.sh          构建 dist/Chumen.app
scripts/download_mihomo.sh    下载本地 mihomo 内核
```

运行数据默认放在：

```text
~/Library/Application Support/io.github.chumen.native-macos
```

主要文件：

- `settings.json`：端口、模式、TUN、DNS、状态栏、内核路径、controller secret 等运行设置；默认以 age 加密保存。
- `profiles.json`：订阅/配置库索引；默认以 age 加密保存。
- `profiles/*.yaml`：导入后的实际 YAML 配置；默认以 age 加密保存。
- `chumen-runtime.yaml`：启动 mihomo 前生成的最终运行配置；开启配置保护时固定路径里保存的是 age 保护数据，不应留下明文运行配置。
- `pin-vault.json`：PIN 保护的 age 私钥保险箱元数据。
- `pin-auto-unlock.key`：默认不锁应用时用于自动解锁 PIN 保险箱的本地随机包装密钥；开启应用锁屏后会删除。
- `age-identity.json`：仅在用户关闭 PIN 保护时使用的本地 age 私钥文件。
- `logs/sidecar.log`：内核 stdout/stderr 和应用侧事件日志。
- `ipc/*.sock`：HTTP controller 以外的 Unix socket 通道。

## 配置保护、PIN 和应用锁屏

Chumen 的配置保护规则以 [docs/security-model.zh.md](docs/security-model.zh.md) 为准。

- 配置文件默认加密保存，目标是避免订阅和节点被明文扫描、误分享或随手打开看到。
- PIN 默认参与保护 age 私钥，但不等于应用锁屏。
- 应用锁屏是独立选项，默认关闭；只有开启后，启动时才必须输入 PIN。
- 默认不把 age 私钥存到 Keychain；本地文件是默认路径，Keychain 是可选路径。
- 不用 PIN 也可以继续，配置仍会加密，但 age 私钥会直接保存在所选位置，本机保护更弱。
- AI 功能只能生成待审核的临时修改和 diff，用户显式应用前不得直接改配置或运行状态。

## 开发运行

```bash
swift run Chumen
```

## 命令行

`chumenctl` 使用和 GUI 完全相同的核心代码，适合先验证订阅、配置生成和 mihomo API，再打开图形界面。

```bash
swift run chumenctl --help
swift run chumenctl settings show
swift run chumenctl profile import-local /path/to/profile.yaml MyProfile
swift run chumenctl config generate
swift run chumenctl api version
swift run chumenctl api configs
swift run chumenctl api logs info 5
swift run chumenctl api traffic
swift run chumenctl api memory
swift run chumenctl api proxies
swift run chumenctl api delay DIRECT
swift run chumenctl api select "Auto Group" "Node A"
swift run chumenctl api proxy-providers
swift run chumenctl api connections
swift run chumenctl api dns-query example.com A
swift run chumenctl api raw GET /version
```

隔离测试时可以用独立数据目录，避免污染真实配置：

```bash
CHUMEN_HOME=/tmp/chumen-test swift run chumenctl settings show
```

## 内核

下载本地 `mihomo`：

```bash
bash ./scripts/download_mihomo.sh
```

下载结果写入 `bin/chumen-door`。该目录不进 git；当 `corePath` 为空或旧路径不可执行时，GUI 和 CLI 会自动优先查找这个文件。Chumen 启动内核前会按设置里的进程名后缀创建托管链接，默认后缀是 `door`，因此默认进程名是 `chumen-door`，方便在进程列表里和系统安装的 `mihomo` 区分。

默认端口刻意避开常见代理客户端：

- mixed：`19881`
- SOCKS：`19882`
- HTTP：`19883`
- controller：`19897`

## 构建 App

日常开发默认打 debug 包：

```bash
bash ./scripts/build_app.sh
```

产物路径：

```text
dist/debug/Chumen.app
```

阶段性正式包显式使用 release：

```bash
bash ./scripts/build_app.sh release
```

正式包产物路径：

```text
dist/Chumen.app
```

把指定内核打进 App Bundle：

```bash
CHUMEN_CORE_PATH="$PWD/bin/chumen-door" bash ./scripts/build_app.sh
CHUMEN_CORE_PATH="$PWD/bin/chumen-door" bash ./scripts/build_app.sh release
```

## 功能

- 配置库：本地 YAML 导入、远程订阅导入、订阅更新、启用、删除。
- 配置编辑：GUI 内置 YAML 编辑器，CLI 支持 show/export/rename/set-url。
- 运行配置生成：合并用户 YAML，并覆盖 Chumen 自己负责的端口、模式、secret、controller、Unix socket、TUN、DNS、监听器、allow-lan、IPv6、unified-delay、log-level、external UI、CORS、hosts 和 YAML 追加段。
- 内核进程：启动、停止、重启、启动时自动运行、stdout/stderr 日志捕获。
- 仪表板：运行状态、当前配置、模式、累计流量、当前速率、代理/直连累计分流、内存、系统代理、TUN 状态。
- 代理：代理组列表、节点选择、单节点延迟、组延迟、清除固定选择。
- Provider：proxy/rule provider 列表、更新、健康检查、provider 内节点检查。
- 连接和规则：连接列表、关闭连接、关闭全部连接、规则列表、规则禁用/启用。
- 内核工具：配置 patch/reload、kernel restart、Geo/UI 更新、fake-IP/DNS cache flush、DNS query、storage get/put/delete、debug GC、raw API。
- 实时流：logs、traffic、memory、connections WebSocket 流，失败时保留手动刷新入口。
- 状态栏：可隐藏/显示，可配置显示模式，可显示应用图标、状态、单行速率、上下行双行速率、累计流量或自定义模板。
- 系统代理：通过 macOS `networksetup` 开关系统代理。
- TUN：支持写入 TUN 配置，并在需要时通过特权 helper 启动内核。
- 窗口生命周期：关闭窗口后 Dock 隐藏，状态栏保留；从状态栏打开窗口时恢复 Dock 显示。
- 语言：简体中文 / English / 跟随系统。

## 与 mihomo 的交互

GUI 和 CLI 共用 `ChumenCore`，核心交互集中在 `MihomoClient`：

- 运行状态：`/version`、`/logs`、`/configs`、`/traffic`、`/memory`、`/connections`、`/rules`
- 运行控制：patch configs、reload config、restart kernel、set mode、关闭连接、关闭全部连接
- 代理控制：代理列表、代理/策略组详情、选择节点、清除固定选择、节点延迟、组延迟
- Provider：proxy/rule provider 列表、详情、更新、健康检查、provider 内节点详情与健康检查
- 缓存 / DNS / storage：fake-IP flush、DNS flush、DNS query、storage get/put/delete
- 维护：Geo update、core upgrade 请求、UI upgrade 请求、debug GC
- 兜底：`api raw <method> <path> [body]`，用于还没封装成类型化方法的 controller 端点

controller secret 不使用固定默认值。首次创建设置、缺失 secret，或检测到旧占位值 `set-your-secret` 时，Chumen 会生成随机 secret，保存到本地 `settings.json`，并写入下一次生成的 `chumen-runtime.yaml`。GUI 和 CLI 都从同一个本地设置读取 secret。

## TUN 和特权 helper

普通代理模式直接用当前用户启动 `mihomo`。开启 TUN 时，macOS 通常需要更高权限，因此 Chumen 会安装并使用 `ChumenHelper`：

- helper 安装到 `/Library/PrivilegedHelperTools/io.github.chumen.native-macos.helper`
- helper 的 LaunchDaemon 是 `/Library/LaunchDaemons/io.github.chumen.native-macos.helper.plist`
- helper 通过本地 Unix socket 接收 start/stop/ping
- 退出 Chumen 时会停止由 Chumen 启动的 mihomo，并按设置清理系统代理

## 从其他客户端导入

配置导入逻辑会扫描常见客户端的数据目录，识别可运行的 YAML 配置，并尽量保留订阅 URL：

- Clash Verge Rev / Dev
- ClashX
- Mihomo Party
- 常见 `.config` 目录

导入时会复制 YAML 到 Chumen 自己的数据目录，并用内容指纹去重，避免重复导入同一个配置。

## 验证

```bash
swift build
swift build --build-tests
swift test
swift build -c release
```

打包后建议继续确认：

```bash
codesign --verify --deep --strict --verbose=2 dist/Chumen.app
/usr/libexec/PlistBuddy -c 'Print :CFBundleName' \
  -c 'Print :CFBundleDisplayName' \
  -c 'Print :CFBundleExecutable' \
  -c 'Print :CFBundleIdentifier' \
  dist/Chumen.app/Contents/Info.plist
```
