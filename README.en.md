# Chumen

Chumen is a native macOS SwiftUI client for starting, controlling, and observing a local `mihomo`
core. The GUI and CLI share the same `ChumenCore` implementation, so most GUI behavior can also be
validated through command-line commands.

Chinese version: [README.zh.md](README.zh.md)

## Project Layout

```text
Package.swift                 Swift Package definition
Sources/ChumenCore            Core control, config generation, subscriptions, system proxy, helper logic
Sources/ChumenMacApp          SwiftUI/AppKit GUI, menu bar, window lifecycle
Sources/ChumenCLI             chumenctl command-line entry point
Sources/ChumenHelper          Privileged helper for TUN scenarios
Packaging/Info.plist          macOS App Bundle metadata
scripts/build_app.sh          Builds debug/release app bundles
scripts/download_mihomo.sh    Downloads the local mihomo core
```

Default runtime data directory:

```text
~/Library/Application Support/io.github.chumen.native-macos
```

Debug packages use a separate identity and runtime data directory:

```text
~/Library/Application Support/io.github.chumen.native-macos.debug
```

Important files:

- `settings.json`: runtime settings such as ports, mode, TUN, DNS, menu bar options, core path, and
  controller secret. Stored with age protection by default.
- `profiles.json`: profile/subscription library index. Stored with age protection by default.
- `profiles/*.yaml`: imported YAML profiles. Stored with age protection by default.
- `chumen-runtime.yaml`: generated runtime config for mihomo. When config protection is enabled, the
  fixed path stores age-protected data and must not leave plaintext runtime config behind.
- `pin-vault.json`: metadata for the PIN-protected age private-key vault.
- `pin-auto-unlock.key`: local random wrapping key used only when app lock is off. It is deleted when
  app lock is enabled.
- `age-identity.json`: local age private key used only when the user disables PIN protection.
- `logs/sidecar.log`: mihomo stdout/stderr and app-side event logs.
- `ipc/*.sock`: Unix socket channels other than the HTTP controller.

## Config Protection, PIN, And App Lock

Chumen's config protection rules are defined in [docs/security-model.en.md](docs/security-model.en.md).

- Config files are encrypted by default to avoid plaintext subscription and node scanning.
- PIN protects the age private key by default, but PIN does not imply app lock.
- App lock is an independent option and is off by default; only when enabled should startup require a
  PIN.
- Local file storage is the default age private-key location; Keychain is optional.
- Continuing without PIN still keeps config files encrypted, but stores the age private key directly
  in the selected location, which weakens local protection.
- AI features may only create reviewable temporary changes and git-like diffs. They must not mutate
  config or runtime state until the user explicitly applies a proposal.

## Development

```bash
swift run Chumen
```

## CLI

`chumenctl` uses the same core code as the GUI. It is useful for validating subscriptions, config
generation, and mihomo API behavior before opening the graphical app.

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

Use an isolated data directory during tests:

```bash
CHUMEN_HOME=/tmp/chumen-test swift run chumenctl settings show
```

## Core

Download the local `mihomo` binary:

```bash
bash ./scripts/download_mihomo.sh
```

The result is written to `bin/chumen-door`, which is not tracked by git. When `corePath` is empty
or the old path is not executable, the GUI and CLI prefer this local binary automatically. Before
starting the core, Chumen creates a managed link using the configured process-name suffix. The
default suffix is `door`, so the default process name is `chumen-door`, distinct from a
system-installed `mihomo` in process lists.

Default ports intentionally avoid common proxy clients:

- mixed: `19881`
- SOCKS: `19882`
- HTTP: `19883`
- controller: `19897`

Debug packages use another default port set so they can run beside release packages:

- mixed: `19981`
- SOCKS: `19982`
- HTTP: `19983`
- controller: `19997`

The debug package also defaults DNS listen to `127.0.0.1:1153` and TUN device to `utun1025`; the release package keeps `127.0.0.1:1053` and `utun1024`.

## Build The App

Daily development builds default to a debug package:

```bash
bash ./scripts/build_app.sh
```

Output:

```text
dist/debug/Chumen.app
```

Use release explicitly for formal packages:

```bash
bash ./scripts/build_app.sh release
```

Release output:

```text
dist/Chumen.app
```

Bundle a specific core binary:

```bash
CHUMEN_CORE_PATH="$PWD/bin/chumen-door" bash ./scripts/build_app.sh
CHUMEN_CORE_PATH="$PWD/bin/chumen-door" bash ./scripts/build_app.sh release
```

## Features

- Profile library: import local YAML, import remote subscriptions, update, enable, and delete.
- Config editing: built-in YAML editor in GUI; show/export/rename/set-url from CLI.
- Runtime config generation: merge user YAML and override Chumen-owned ports, mode, secret,
  controller, Unix sockets, TUN, DNS, listeners, allow-lan, IPv6, unified-delay, log-level,
  external UI, CORS, hosts, and appended YAML blocks.
- Core process: start, stop, restart, auto-run at launch, and capture stdout/stderr logs.
- Dashboard: runtime status, current profile, mode, total traffic, current speed, proxy/direct
  observed split, memory, system proxy, and TUN state.
- Proxies: group list, node selection, node delay, group delay, and fixed-selection clearing.
- Provider: proxy/rule provider lists, update, health check, and provider-node checks.
- Connections and rules: connection list, close connection, close all connections, rule list,
  disable/enable rules.
- Core tools: config patch/reload, kernel restart, Geo/UI update, fake-IP/DNS cache flush, DNS
  query, storage get/put/delete, debug GC, and raw API.
- Live streams: logs, traffic, memory, and connections WebSocket streams with manual refresh fallbacks.
- Menu bar: configurable display mode for icon, status, one-line speed, two-line up/down speed,
  total traffic, or custom template.
- System proxy: toggles macOS system proxy through `networksetup`.
- TUN: writes TUN config and can use the privileged helper when required.
- Window lifecycle: closing the window hides the Dock icon and keeps the menu bar item; reopening from
  the menu bar restores the Dock icon.
- Languages: Simplified Chinese, English, or follow system.

## mihomo Interaction

The GUI and CLI share `ChumenCore`; most core interaction lives in `MihomoClient`:

- Status: `/version`, `/logs`, `/configs`, `/traffic`, `/memory`, `/connections`, `/rules`
- Runtime control: patch configs, reload config, restart kernel, set mode, close one connection,
  close all connections
- Proxy control: proxy list, group detail, node selection, fixed-selection clearing, node delay,
  group delay
- Provider: proxy/rule provider list, detail, update, health check, provider-node detail and checks
- Cache / DNS / storage: fake-IP flush, DNS flush, DNS query, storage get/put/delete
- Maintenance: Geo update, core upgrade request, UI upgrade request, debug GC
- Escape hatch: `api raw <method> <path> [body]` for controller endpoints that are not yet typed

The controller secret never uses a fixed default. When settings are created for the first time, when
the secret is missing, or when the old placeholder `set-your-secret` is detected, Chumen generates a
random secret, stores it locally, and writes it into the next generated `chumen-runtime.yaml`. GUI
and CLI read the same local setting.

## TUN And Privileged Helper

Normal proxy mode starts `mihomo` as the current user. TUN usually needs higher privileges on macOS,
so Chumen can install and use `ChumenHelper`:

- Helper path: `/Library/PrivilegedHelperTools/io.github.chumen.native-macos.helper`
- LaunchDaemon path: `/Library/LaunchDaemons/io.github.chumen.native-macos.helper.plist`
- The helper accepts start/stop/ping through a local Unix socket.
- When Chumen exits, it stops the mihomo process it started and cleans system proxy state according
  to settings.

## Import From Other Clients

Import scans common client data directories, detects runnable YAML configs, and tries to preserve
subscription URLs:

- Clash Verge Rev / Dev
- ClashX
- Mihomo Party
- common `.config` directories

Imported YAML is copied into Chumen's data directory and deduplicated by content fingerprint.

## Verification

```bash
swift build
swift build --build-tests
swift test
swift build -c release
```

After packaging, also verify:

```bash
codesign --verify --deep --strict --verbose=2 dist/Chumen.app
/usr/libexec/PlistBuddy -c 'Print :CFBundleName' \
  -c 'Print :CFBundleDisplayName' \
  -c 'Print :CFBundleExecutable' \
  -c 'Print :CFBundleIdentifier' \
  dist/Chumen.app/Contents/Info.plist
```
