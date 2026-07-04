import Foundation
import Darwin
import ChumenCore

@main
@MainActor
struct ChumenCLI {
    static func main() async {
        do {
            let context = try CLIContext()
            try await run(arguments: Array(CommandLine.arguments.dropFirst()), context: context)
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run(arguments: [String], context: CLIContext) async throws {
        guard let command = arguments.first else {
            printHelp()
            return
        }

        let rest = Array(arguments.dropFirst())
        switch command {
        case "-h", "--help", "help":
            printHelp()
        case "settings":
            try handleSettings(rest, context: context)
        case "profile":
            try await handleProfile(rest, context: context)
        case "config":
            try handleConfig(rest, context: context)
        case "api":
            try await handleAPI(rest, context: context)
        case "proxy":
            try handleProxy(rest, context: context)
        case "run":
            try handleRun(rest, context: context)
        default:
            throw CLIError.usage("unknown command: \(command)")
        }
    }

    private static func handleSettings(_ arguments: [String], context: CLIContext) throws {
        guard let subcommand = arguments.first else {
            printJSON(context.settings)
            return
        }

        var settings = context.settings
        switch subcommand {
        case "show":
            printJSON(settings)
        case "set-core":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-core <path>") }
            settings.corePath = arguments[1]
            try context.settingsStore.save(settings)
            print("corePath=\(settings.corePath)")
        case "set-profile":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-profile <path>") }
            settings.profilePath = arguments[1]
            try context.settingsStore.save(settings)
            print("profilePath=\(settings.profilePath ?? "")")
        case "set-controller":
            guard arguments.count >= 3 else { throw CLIError.usage("settings set-controller <host> <port>") }
            settings.externalControllerHost = arguments[1]
            settings.externalControllerPort = try parsePort(arguments[2], label: "external-controller port")
            try context.settingsStore.save(settings)
            print("externalController=\(settings.externalControllerHost):\(settings.externalControllerPort)")
        case "set-system-proxy-host":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-system-proxy-host <host>") }
            settings.systemProxyHost = arguments[1]
            try context.settingsStore.save(settings)
            print("systemProxyHost=\(settings.systemProxyHost)")
        case "set-ports":
            guard arguments.count >= 4 else { throw CLIError.usage("settings set-ports <mixed> <socks> <http>") }
            settings.mixedPort = try parsePort(arguments[1], label: "mixed port")
            settings.socksPort = try parsePort(arguments[2], label: "socks port")
            settings.httpPort = try parsePort(arguments[3], label: "http port")
            try context.settingsStore.save(settings)
            print("ports mixed=\(settings.mixedPort) socks=\(settings.socksPort) http=\(settings.httpPort)")
        case "set-secret":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-secret <secret>") }
            settings.secret = arguments[1]
            try context.settingsStore.save(settings)
            print("secret updated")
        case "set-mode":
            guard arguments.count >= 2, let mode = ProxyMode(rawValue: arguments[1]) else {
                throw CLIError.usage("settings set-mode <rule|global|direct>")
            }
            settings.mode = mode
            try context.settingsStore.save(settings)
            print("mode=\(mode.rawValue)")
        case "set-allow-lan":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-allow-lan <true|false>") }
            settings.allowLAN = try parseBool(arguments[1])
            try context.settingsStore.save(settings)
            print("allowLAN=\(settings.allowLAN)")
        case "set-ipv6":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-ipv6 <true|false>") }
            settings.ipv6 = try parseBool(arguments[1])
            try context.settingsStore.save(settings)
            print("ipv6=\(settings.ipv6)")
        case "set-unified-delay":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-unified-delay <true|false>") }
            settings.unifiedDelay = try parseBool(arguments[1])
            try context.settingsStore.save(settings)
            print("unifiedDelay=\(settings.unifiedDelay)")
        case "set-log-level":
            guard arguments.count >= 2, let logLevel = CoreLogLevel(rawValue: arguments[1]) else {
                throw CLIError.usage("settings set-log-level <debug|info|warning|error|silent>")
            }
            settings.logLevel = logLevel
            try context.settingsStore.save(settings)
            print("logLevel=\(logLevel.rawValue)")
        case "set-tun":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-tun <true|false> [system|gvisor|mixed]") }
            settings.enableTun = try parseBool(arguments[1])
            if arguments.count >= 3 {
                guard let stack = TunStack(rawValue: arguments[2]) else {
                    throw CLIError.usage("settings set-tun <true|false> [system|gvisor|mixed]")
                }
                settings.tunStack = stack
            }
            try context.settingsStore.save(settings)
            print("enableTun=\(settings.enableTun) tunStack=\(settings.tunStack.rawValue)")
        case "set-dns":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-dns <true|false> [listen] [fake-ip|redir-host]") }
            settings.enableDNS = try parseBool(arguments[1])
            if arguments.count >= 3 {
                settings.dnsListen = arguments[2]
            }
            if arguments.count >= 4 {
                guard let mode = DNSMode(rawValue: arguments[3]) else {
                    throw CLIError.usage("settings set-dns <true|false> [listen] [fake-ip|redir-host]")
                }
                settings.dnsMode = mode
            }
            try context.settingsStore.save(settings)
            print("enableDNS=\(settings.enableDNS) dnsListen=\(settings.dnsListen) dnsMode=\(settings.dnsMode.rawValue)")
        case "set-nameservers":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-nameservers <server1,server2,...>") }
            settings.nameservers = splitList(Array(arguments.dropFirst()).joined(separator: " "))
            try context.settingsStore.save(settings)
            print("nameservers=\(settings.nameservers.joined(separator: ","))")
        case "set-language":
            guard arguments.count >= 2, let language = AppLanguage(rawValue: arguments[1]) else {
                throw CLIError.usage("settings set-language <system|zhHans|en>")
            }
            settings.language = language
            try context.settingsStore.save(settings)
            print("language=\(language.rawValue)")
        case "set-status-bar-visible":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-status-bar-visible <true|false>") }
            settings.showStatusBarItem = try parseBool(arguments[1])
            try context.settingsStore.save(settings)
            print("showStatusBarItem=\(settings.showStatusBarItem)")
        case "set-status-bar-display":
            guard arguments.count >= 2, let mode = StatusBarDisplayMode(rawValue: arguments[1]) else {
                throw CLIError.usage("settings set-status-bar-display <icon-only|app-name|status|speed|stacked-speed|traffic|status-speed|custom>")
            }
            settings.statusBarDisplayMode = mode
            try context.settingsStore.save(settings)
            print("statusBarDisplayMode=\(mode.rawValue)")
        case "set-status-bar-template":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-status-bar-template <template>") }
            settings.statusBarCustomTemplate = Array(arguments.dropFirst()).joined(separator: " ")
            try context.settingsStore.save(settings)
            print("statusBarCustomTemplate=\(settings.statusBarCustomTemplate)")
        case "set-auto-start-core":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-auto-start-core <true|false>") }
            settings.autoStartCoreOnLaunch = try parseBool(arguments[1])
            try context.settingsStore.save(settings)
            print("autoStartCoreOnLaunch=\(settings.autoStartCoreOnLaunch)")
        case "set-proxy-on-start":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-proxy-on-start <true|false>") }
            settings.setSystemProxyOnStart = try parseBool(arguments[1])
            try context.settingsStore.save(settings)
            print("setSystemProxyOnStart=\(settings.setSystemProxyOnStart)")
        case "set-clear-proxy-on-stop":
            guard arguments.count >= 2 else { throw CLIError.usage("settings set-clear-proxy-on-stop <true|false>") }
            settings.clearSystemProxyOnStop = try parseBool(arguments[1])
            try context.settingsStore.save(settings)
            print("clearSystemProxyOnStop=\(settings.clearSystemProxyOnStop)")
        default:
            throw CLIError.usage("unknown settings command: \(subcommand)")
        }
    }

    private static func handleProfile(_ arguments: [String], context: CLIContext) async throws {
        guard let subcommand = arguments.first else {
            throw CLIError.usage("profile <list|show|export|rename|set-url|import-local|import-url|scan-external|import-external|activate|update|delete>")
        }

        var library = context.profileRepository.load()
        switch subcommand {
        case "list":
            printJSON(library)
        case "show":
            guard arguments.count >= 2 else { throw CLIError.usage("profile show <id>") }
            let profile = try findProfile(arguments[1], in: library)
            print(try context.profileRepository.profileContent(profile))
        case "export":
            guard arguments.count >= 3 else { throw CLIError.usage("profile export <id> <target-yaml-path>") }
            let profile = try findProfile(arguments[1], in: library)
            let target = URL(fileURLWithPath: arguments[2])
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try context.profileRepository.profileContent(profile).write(to: target, atomically: true, encoding: .utf8)
            print(target.path)
        case "rename":
            guard arguments.count >= 3 else { throw CLIError.usage("profile rename <id> <name>") }
            let profile = try findProfile(arguments[1], in: library)
            let name = Array(arguments.dropFirst(2)).joined(separator: " ")
            printJSON(try context.profileRepository.rename(profile, name: name, in: &library))
        case "set-url":
            guard arguments.count >= 3 else { throw CLIError.usage("profile set-url <id> <subscription-url|->") }
            let profile = try findProfile(arguments[1], in: library)
            let url = Array(arguments.dropFirst(2)).joined(separator: " ")
            let remoteURL = url == "-" ? nil : url
            printJSON(try context.profileRepository.updateMetadata(
                profile,
                name: profile.name,
                remoteURL: remoteURL,
                in: &library
            ))
        case "import-local":
            guard arguments.count >= 2 else { throw CLIError.usage("profile import-local <yaml-path> [name]") }
            let profile = try context.profileRepository.importLocalProfile(
                from: URL(fileURLWithPath: arguments[1]),
                name: arguments.count >= 3 ? arguments[2] : nil,
                into: &library
            )
            try activateIfFirst(profile, library: library, context: context)
            try await reloadRunningConfigIfAvailable(library: library, context: context)
            printJSON(profile)
        case "import-url":
            guard arguments.count >= 2 else { throw CLIError.usage("profile import-url <url> [name]") }
            let profile = try await context.profileRepository.importRemoteProfile(
                urlString: arguments[1],
                name: arguments.count >= 3 ? arguments[2] : nil,
                into: &library
            )
            try activateIfFirst(profile, library: library, context: context)
            try await reloadRunningConfigIfAvailable(library: library, context: context)
            printJSON(profile)
        case "scan-external":
            printJSON(context.profileRepository.discoverExternalProfiles())
        case "import-external":
            let candidates = context.profileRepository.discoverExternalProfiles()
            let selected: [ExternalProfileCandidate]
            if arguments.count >= 2 {
                let selector = Array(arguments.dropFirst()).joined(separator: " ")
                selected = candidates.filter {
                    $0.id == selector ||
                    $0.filePath == selector ||
                    URL(fileURLWithPath: $0.filePath).lastPathComponent == selector
                }
                guard !selected.isEmpty else {
                    throw CLIError.usage("external profile not found: \(selector)")
                }
            } else {
                selected = candidates
            }
            let summary = try context.profileRepository.importExternalProfiles(selected, into: &library)
            try saveActiveProfileSettings(library: library, context: context)
            try await reloadRunningConfigIfAvailable(library: library, context: context)
            printJSON(summary)
        case "activate":
            guard arguments.count >= 2 else { throw CLIError.usage("profile activate <id>") }
            let profile = try findProfile(arguments[1], in: library)
            library.activeProfileID = profile.id
            try context.profileRepository.save(library)
            var settings = context.settings
            settings.activeProfileID = profile.id
            settings.profilePath = profile.filePath
            try context.settingsStore.save(settings)
            try await reloadRunningConfigIfAvailable(library: library, context: context)
            printJSON(profile)
        case "update":
            guard arguments.count >= 2 else { throw CLIError.usage("profile update <id>") }
            let profile = try findProfile(arguments[1], in: library)
            printJSON(try await context.profileRepository.update(profile, in: &library))
        case "delete":
            guard arguments.count >= 2 else { throw CLIError.usage("profile delete <id>") }
            let profile = try findProfile(arguments[1], in: library)
            try context.profileRepository.delete(profile, from: &library)
            try await reloadRunningConfigIfAvailable(library: library, context: context)
            print("deleted \(profile.id)")
        default:
            throw CLIError.usage("unknown profile command: \(subcommand)")
        }
    }

    private static func handleConfig(_ arguments: [String], context: CLIContext) throws {
        var settings = context.settings
        if let active = context.profileRepository.load().activeProfile {
            settings.activeProfileID = active.id
            settings.profilePath = active.filePath
        }

        switch arguments.first {
        case nil, "generate":
            let runtimeConfigURL = try ChumenConfigurationBuilder.writeRuntimeConfig(settings: settings, paths: context.paths)
            print(runtimeConfigURL.path)
        case "print":
            let protection = ChumenConfigProtection(enabled: settings.protectConfigFiles, corePath: settings.corePath)
            let profile = settings.profilePath.flatMap { try? protection.readText(at: URL(fileURLWithPath: $0)) }
            print(ChumenConfigurationBuilder.runtimeYAML(profileYAML: profile, settings: settings, socketPath: context.paths.externalControllerSocketURL.path))
        default:
            throw CLIError.usage("config <generate|print>")
        }
    }

    private static func handleAPI(_ arguments: [String], context: CLIContext) async throws {
        guard let subcommand = arguments.first else {
            throw CLIError.usage("api <version|logs|traffic|memory|configs|patch-config|reload-config|restart-kernel|upgrade|upgrade-ui|upgrade-geo|groups|group|delay-group|proxies|proxy-info|delay|select|clear-proxy|proxy-providers|proxy-provider-info|proxy-provider-proxy|rule-providers|rules|disable-rules|connections|dns-query|storage-get|storage-put|storage-delete|flush-fakeip|flush-dns|gc|raw>")
        }

        let client = try context.client()
        switch subcommand {
        case "version":
            printJSON(try await client.version())
        case "traffic":
            printJSON(try await client.traffic())
        case "memory":
            printJSON(try await client.memory())
        case "logs":
            guard let baseURL = context.settings.controllerBaseURL else {
                throw ChumenError.invalidControllerURL
            }
            let level = arguments.count >= 2 ? arguments[1] : context.settings.logLevel.rawValue
            let seconds = arguments.count >= 3 ? try parsePositiveInt(arguments[2], label: "seconds") : 5
            let structured = arguments.count >= 4 ? try parseBool(arguments[3]) : false
            let stream = MihomoLogStream()
            stream.start(baseURL: baseURL, secret: context.settings.secret, level: level, structured: structured) { text in
                print(text, terminator: "")
                fflush(stdout)
            }
            try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            stream.stop()
        case "flush-fakeip":
            try await client.flushFakeIPCache()
            print("fake-ip cache flushed")
        case "flush-dns":
            try await client.flushDNSCache()
            print("dns cache flushed")
        case "configs":
            printJSON(try await client.configs())
        case "patch-config":
            guard arguments.count >= 2 else { throw CLIError.usage("api patch-config '<json-object>'") }
            guard case let .object(patch) = try parseJSON(arguments.dropFirst().joined(separator: " ")) else {
                throw CLIError.usage("api patch-config body must be a JSON object")
            }
            try await client.patchConfigs(patch)
            print("config patched")
        case "reload-config":
            let path: String
            let payload: String
            if arguments.count >= 2 {
                path = arguments[1]
                payload = ""
            } else {
                var settings = context.settingsStore.load()
                if let active = context.profileRepository.load().activeProfile {
                    settings.activeProfileID = active.id
                    settings.profilePath = active.filePath
                }
                // Intent: chumenctl is often a separate process from the GUI that started mihomo,
                // so it does not own that process-local age secret. For no-path reloads we keep the
                // generated YAML in memory and send it through mihomo's controller payload instead
                // of writing a plaintext temp file or producing an undecryptable age file.
                let protection = ChumenConfigProtection(enabled: settings.protectConfigFiles, corePath: settings.corePath)
                let profileYAML: String?
                if let profilePath = settings.profilePath, !profilePath.isEmpty {
                    profileYAML = try protection.readText(at: URL(fileURLWithPath: profilePath))
                } else {
                    profileYAML = nil
                }
                payload = ChumenConfigurationBuilder.runtimeYAML(
                    profileYAML: profileYAML,
                    settings: settings,
                    socketPath: context.paths.externalControllerSocketURL.path
                )
                path = ""
            }
            let force = arguments.count >= 3 ? try parseBool(arguments[2]) : true
            try await client.reloadConfig(path: path, payload: payload, force: force)
            print("config reloaded")
        case "restart-kernel":
            let path = arguments.count >= 2 ? arguments[1] : ""
            try await client.restartKernel(path: path)
            print("kernel restart requested")
        case "update-config-geo":
            let path = arguments.count >= 2 ? arguments[1] : ""
            try await client.updateConfigGeo(path: path)
            print("config geo updated")
        case "upgrade":
            let channel = arguments.count >= 2 ? arguments[1] : nil
            let force = arguments.count >= 3 ? try parseBool(arguments[2]) : false
            try await client.upgrade(channel: channel, force: force)
            print("upgrade requested")
        case "upgrade-ui":
            try await client.upgradeUI()
            print("web ui upgrade requested")
        case "upgrade-geo":
            let path = arguments.count >= 2 ? arguments[1] : ""
            try await client.upgradeGeo(path: path)
            print("geo upgrade requested")
        case "mode":
            guard arguments.count >= 2, let mode = ProxyMode(rawValue: arguments[1]) else {
                throw CLIError.usage("api mode <rule|global|direct>")
            }
            try await client.setMode(mode)
            print("mode=\(mode.rawValue)")
        case "groups":
            printJSON(try await client.policyGroups())
        case "group":
            guard arguments.count >= 2 else { throw CLIError.usage("api group <group-name>") }
            printJSON(try await client.policyGroup(name: arguments[1]))
        case "delay-group":
            guard arguments.count >= 2 else { throw CLIError.usage("api delay-group <group-name> [url] [timeout-ms] [expected]") }
            let url = arguments.count >= 3 ? arguments[2] : "https://www.gstatic.com/generate_204"
            let timeout = arguments.count >= 4 ? try parsePositiveInt(arguments[3], label: "timeout") : 5000
            let expected = arguments.count >= 5 ? arguments[4] : nil
            printJSON(try await client.delayGroup(name: arguments[1], url: url, timeout: timeout, expected: expected))
        case "proxies":
            let response = try await client.proxies()
            let groups = response.proxies.values.filter(\.isGroup).map(ProxyGroupSnapshot.init(proxy:)).sorted { $0.name < $1.name }
            printJSON(groups)
        case "proxy-info":
            guard arguments.count >= 2 else { throw CLIError.usage("api proxy-info <proxy-or-group-name>") }
            printJSON(try await client.proxy(name: arguments[1]))
        case "delay":
            guard arguments.count >= 2 else { throw CLIError.usage("api delay <proxy-name> [url] [timeout-ms]") }
            let url = arguments.count >= 3 ? arguments[2] : "https://www.gstatic.com/generate_204"
            let timeout = arguments.count >= 4 ? try parsePositiveInt(arguments[3], label: "timeout") : 5000
            printJSON(try await client.delayProxy(name: arguments[1], url: url, timeout: timeout))
        case "select":
            guard arguments.count >= 3 else { throw CLIError.usage("api select <group> <node>") }
            try await client.selectProxy(group: arguments[1], name: arguments[2])
            print("\(arguments[1])=\(arguments[2])")
        case "clear-proxy":
            guard arguments.count >= 2 else { throw CLIError.usage("api clear-proxy <group>") }
            try await client.clearProxySelection(group: arguments[1])
            print("cleared \(arguments[1])")
        case "proxy-providers":
            let providers = try await client.proxyProviders().providers.values.sorted { $0.name < $1.name }
            printJSON(providers)
        case "proxy-provider-info":
            guard arguments.count >= 2 else { throw CLIError.usage("api proxy-provider-info <name>") }
            printJSON(try await client.proxyProvider(name: arguments[1]))
        case "proxy-provider-proxy":
            guard arguments.count >= 3 else { throw CLIError.usage("api proxy-provider-proxy <provider> <proxy>") }
            printJSON(try await client.proxyProviderProxy(provider: arguments[1], proxy: arguments[2]))
        case "rule-providers":
            let providers = try await client.ruleProviders().providers.values.sorted { $0.name < $1.name }
            printJSON(providers)
        case "update-proxy-provider":
            guard arguments.count >= 2 else { throw CLIError.usage("api update-proxy-provider <name>") }
            try await client.updateProxyProvider(name: arguments[1])
            print("updated proxy provider \(arguments[1])")
        case "healthcheck-proxy-provider":
            guard arguments.count >= 2 else { throw CLIError.usage("api healthcheck-proxy-provider <name>") }
            try await client.healthcheckProxyProvider(name: arguments[1])
            print("healthchecked proxy provider \(arguments[1])")
        case "healthcheck-provider-proxy":
            guard arguments.count >= 3 else { throw CLIError.usage("api healthcheck-provider-proxy <provider> <proxy> [url] [timeout-ms]") }
            let url = arguments.count >= 4 ? arguments[3] : "https://www.gstatic.com/generate_204"
            let timeout = arguments.count >= 5 ? try parsePositiveInt(arguments[4], label: "timeout") : 5000
            printJSON(try await client.healthcheckProxyProviderProxy(provider: arguments[1], proxy: arguments[2], url: url, timeout: timeout))
        case "update-rule-provider":
            guard arguments.count >= 2 else { throw CLIError.usage("api update-rule-provider <name>") }
            try await client.updateRuleProvider(name: arguments[1])
            print("updated rule provider \(arguments[1])")
        case "rule-provider-info":
            guard arguments.count >= 2 else { throw CLIError.usage("api rule-provider-info <name>") }
            printJSON(try await client.ruleProvider(name: arguments[1]))
        case "connections":
            printJSON(try await client.connections())
        case "close":
            guard arguments.count >= 2 else { throw CLIError.usage("api close <connection-id>") }
            try await client.closeConnection(id: arguments[1])
            print("closed \(arguments[1])")
        case "close-all":
            try await client.closeAllConnections()
            print("closed all")
        case "rules":
            printJSON(try await client.rules())
        case "disable-rules":
            guard arguments.count >= 2 else { throw CLIError.usage("api disable-rules '<json-object>' | <index=true,index=false>") }
            try await client.disableRules(try parseRuleDisableMap(Array(arguments.dropFirst()).joined(separator: " ")))
            print("rules updated")
        case "dns-query":
            guard arguments.count >= 2 else { throw CLIError.usage("api dns-query <name> [A|AAAA|TXT|...]") }
            printJSON(try await client.dnsQuery(name: arguments[1], type: arguments.count >= 3 ? arguments[2] : "A"))
        case "storage-get":
            guard arguments.count >= 2 else { throw CLIError.usage("api storage-get <key>") }
            printJSON(try await client.storage(key: arguments[1]))
        case "storage-put":
            guard arguments.count >= 3 else { throw CLIError.usage("api storage-put <key> '<json>'") }
            try await client.putStorage(key: arguments[1], value: try parseJSON(Array(arguments.dropFirst(2)).joined(separator: " ")))
            print("storage written")
        case "storage-delete":
            guard arguments.count >= 2 else { throw CLIError.usage("api storage-delete <key>") }
            try await client.deleteStorage(key: arguments[1])
            print("storage deleted")
        case "gc":
            try await client.debugGC()
            print("gc requested")
        case "raw":
            guard arguments.count >= 3 else { throw CLIError.usage("api raw <GET|POST|PUT|PATCH|DELETE> <path> [body]") }
            let body = arguments.count >= 4 ? Data(Array(arguments.dropFirst(3)).joined(separator: " ").utf8) : nil
            let response = try await client.raw(path: arguments[2], method: arguments[1].uppercased(), body: body)
            if response.body.isEmpty {
                print("HTTP \(response.statusCode)")
            } else {
                print(response.body)
            }
        default:
            throw CLIError.usage("unknown api command: \(subcommand)")
        }
    }

    private static func handleProxy(_ arguments: [String], context: CLIContext) throws {
        guard let subcommand = arguments.first else {
            throw CLIError.usage("proxy <status|on|off>")
        }

        let manager = SystemProxyManager(host: context.settings.systemProxyHost, port: context.settings.mixedPort)
        switch subcommand {
        case "status":
            printJSON(try manager.currentState())
        case "on":
            try manager.enable()
            print("system proxy enabled")
        case "off":
            try manager.disable()
            print("system proxy disabled")
        default:
            throw CLIError.usage("unknown proxy command: \(subcommand)")
        }
    }

    private static func handleRun(_ arguments: [String], context: CLIContext) throws -> Never {
        var settings = context.settings
        if let active = context.profileRepository.load().activeProfile {
            settings.activeProfileID = active.id
            settings.profilePath = active.filePath
        }

        let manager = CoreProcessManager(paths: context.paths)
        manager.onLog = { text in
            print(text, terminator: "")
            fflush(stdout)
        }
        try manager.start(settings: settings)
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        let signalQueue = DispatchQueue(label: "io.github.chumen.cli.signals")
        let interruptSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue)
        let terminateSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: signalQueue)
        let stopAndExit: @Sendable () -> Void = {
            manager.stop(waitForExit: true)
            print("\nchumenctl stopped.")
            fflush(stdout)
            exit(0)
        }
        interruptSource.setEventHandler(handler: stopAndExit)
        terminateSource.setEventHandler(handler: stopAndExit)
        interruptSource.resume()
        terminateSource.resume()

        print("chumenctl running. Press Ctrl-C to stop.")
        withExtendedLifetime([interruptSource, terminateSource]) {
            RunLoop.current.run()
        }
        fatalError("unreachable")
    }

    private static func activateIfFirst(_ profile: ProxyProfile, library: ProfileLibrary, context: CLIContext) throws {
        guard library.activeProfileID == profile.id else { return }
        var settings = context.settings
        settings.activeProfileID = profile.id
        settings.profilePath = profile.filePath
        try context.settingsStore.save(settings)
    }

    private static func saveActiveProfileSettings(library: ProfileLibrary, context: CLIContext) throws {
        guard let active = library.activeProfile else { return }
        var settings = context.settings
        settings.activeProfileID = active.id
        settings.profilePath = active.filePath
        try context.settingsStore.save(settings)
    }

    private static func reloadRunningConfigIfAvailable(library: ProfileLibrary, context: CLIContext) async throws {
        var settings = context.settingsStore.load()
        if let active = library.activeProfile {
            settings.activeProfileID = active.id
            settings.profilePath = active.filePath
        } else {
            settings.activeProfileID = nil
            settings.profilePath = nil
        }
        try context.settingsStore.save(settings)
        guard let url = settings.controllerBaseURL else { return }
        // Keep CLI-triggered hot reloads fileless. The running core may have been started by the GUI
        // with a process-local age secret that this chumenctl invocation cannot recover.
        let protection = ChumenConfigProtection(enabled: settings.protectConfigFiles, corePath: settings.corePath)
        let profileYAML: String?
        if let profilePath = settings.profilePath, !profilePath.isEmpty {
            profileYAML = try protection.readText(at: URL(fileURLWithPath: profilePath))
        } else {
            profileYAML = nil
        }
        let payload = ChumenConfigurationBuilder.runtimeYAML(
            profileYAML: profileYAML,
            settings: settings,
            socketPath: context.paths.externalControllerSocketURL.path
        )
        do {
            try await MihomoClient(baseURL: url, secret: settings.secret)
                .reloadConfig(payload: payload, force: true)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain,
               [
                NSURLErrorCannotConnectToHost,
                NSURLErrorCannotFindHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorTimedOut
               ].contains(nsError.code) {
                return
            }
            throw error
        }
    }

    private static func findProfile(_ id: String, in library: ProfileLibrary) throws -> ProxyProfile {
        guard let profile = library.profiles.first(where: { $0.id == id }) else {
            throw CLIError.usage("profile not found: \(id)")
        }
        return profile
    }

    private static func printHelp() {
        print(
            """
            chumenctl - Chumen command line controller

            Commands:
              settings show
              settings set-core <path>
              settings set-profile <path>
              settings set-controller <host> <port>
              settings set-system-proxy-host <host>
              settings set-ports <mixed> <socks> <http>
              settings set-secret <secret>
              settings set-mode <rule|global|direct>
              settings set-allow-lan <true|false>
              settings set-ipv6 <true|false>
              settings set-unified-delay <true|false>
              settings set-log-level <debug|info|warning|error|silent>
              settings set-tun <true|false> [system|gvisor|mixed]
              settings set-dns <true|false> [listen] [fake-ip|redir-host]
              settings set-nameservers <server1,server2,...>
              settings set-language <system|zhHans|en>
              settings set-status-bar-visible <true|false>
              settings set-status-bar-display <icon-only|app-name|status|speed|stacked-speed|traffic|status-speed|custom>
              settings set-status-bar-template <template>
              settings set-auto-start-core <true|false>
              settings set-proxy-on-start <true|false>
              settings set-clear-proxy-on-stop <true|false>
              profile list
              profile show <id>
              profile export <id> <target-yaml-path>
              profile rename <id> <name>
              profile set-url <id> <subscription-url|->
              profile import-local <yaml-path> [name]
              profile import-url <url> [name]
              profile scan-external
              profile import-external [candidate-id|yaml-path|filename]
              profile activate <id>
              profile update <id>
              profile delete <id>
              config generate
              config print
              api version
              api logs [debug|info|warning|error] [seconds] [structured]
              api traffic
              api memory
              api configs
              api patch-config '<json-object>'
              api reload-config [path] [force]
              api restart-kernel [path]
              api update-config-geo [path]
              api upgrade [channel] [force]
              api upgrade-ui
              api upgrade-geo [path]
              api mode <rule|global|direct>
              api groups
              api group <group-name>
              api delay-group <group-name> [url] [timeout-ms] [expected]
              api proxies
              api proxy-info <proxy-or-group-name>
              api delay <proxy-name> [url] [timeout-ms]
              api select <group> <node>
              api clear-proxy <group>
              api proxy-providers
              api proxy-provider-info <name>
              api proxy-provider-proxy <provider> <proxy>
              api rule-providers
              api update-proxy-provider <name>
              api healthcheck-proxy-provider <name>
              api healthcheck-provider-proxy <provider> <proxy> [url] [timeout-ms]
              api update-rule-provider <name>
              api rule-provider-info <name>
              api connections
              api close <connection-id>
              api close-all
              api rules
              api disable-rules '<json-object>' | <index=true,index=false>
              api dns-query <name> [type]
              api storage-get <key>
              api storage-put <key> '<json>'
              api storage-delete <key>
              api flush-fakeip
              api flush-dns
              api gc
              api raw <method> <path> [body]
              proxy status
              proxy on
              proxy off
              run
            """
        )
    }

    private static func printJSON<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func parsePort(_ value: String, label: String) throws -> Int {
        guard let port = Int(value), (1...65535).contains(port) else {
            throw CLIError.usage("\(label) must be an integer between 1 and 65535")
        }
        return port
    }

    private static func parsePositiveInt(_ value: String, label: String) throws -> Int {
        guard let number = Int(value), number > 0 else {
            throw CLIError.usage("\(label) must be a positive integer")
        }
        return number
    }

    private static func parseBool(_ value: String) throws -> Bool {
        switch value.lowercased() {
        case "true", "yes", "1", "on":
            return true
        case "false", "no", "0", "off":
            return false
        default:
            throw CLIError.usage("boolean value must be true or false")
        }
    }

    private static func splitList(_ value: String) -> [String] {
        value
            .split { character in
                character == "," || character == "\n"
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func parseJSON(_ value: String) throws -> MihomoJSONValue {
        guard let data = value.data(using: .utf8) else {
            throw CLIError.usage("invalid UTF-8 JSON")
        }
        do {
            return try JSONDecoder().decode(MihomoJSONValue.self, from: data)
        } catch {
            throw CLIError.usage("invalid JSON: \(error.localizedDescription)")
        }
    }

    private static func parseRuleDisableMap(_ value: String) throws -> [String: Bool] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") {
            guard let data = trimmed.data(using: .utf8) else {
                throw CLIError.usage("invalid UTF-8 JSON")
            }
            return try JSONDecoder().decode([String: Bool].self, from: data)
        }

        var result: [String: Bool] = [:]
        for part in splitList(trimmed) {
            let pieces = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else {
                throw CLIError.usage("disable-rules expects index=true pairs")
            }
            result[pieces[0]] = try parseBool(pieces[1])
        }
        return result
    }
}

private struct CLIContext {
    let paths: ChumenPaths
    let settingsStore: ChumenSettingsStore
    let settings: ChumenRuntimeSettings
    let profileRepository: ProfileRepository

    @MainActor
    init() throws {
        let paths = try ChumenPaths.defaultPaths()
        self.paths = paths
        self.settingsStore = ChumenSettingsStore(paths: paths)
        self.settings = settingsStore.load()
        self.profileRepository = ProfileRepository(paths: paths, protectConfigFiles: settings.protectConfigFiles, corePath: settings.corePath)
    }

    func client() throws -> MihomoClient {
        guard let url = settings.controllerBaseURL else {
            throw ChumenError.invalidControllerURL
        }
        return MihomoClient(baseURL: url, secret: settings.secret)
    }
}

private enum CLIError: LocalizedError {
    case usage(String)

    var errorDescription: String? {
        switch self {
        case let .usage(message):
            return message
        }
    }
}
