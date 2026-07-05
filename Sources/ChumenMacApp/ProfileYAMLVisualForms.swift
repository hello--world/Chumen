import ChumenCore
import SwiftUI

private enum YAMLVisualValue {
    static func bool(_ value: String) -> Bool {
        ["true", "yes", "on", "1"].contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func lines(_ value: String) -> [String] {
        value
            .components(separatedBy: .newlines)
            .map(clean)
            .filter { !$0.isEmpty }
    }

    static func appending(_ item: String, to body: String) -> String {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return item }
        return trimmedBody + "\n" + item
    }

    static func appendKey(_ key: String, value: String, to lines: inout [String]) {
        let value = clean(value)
        guard !value.isEmpty else { return }
        lines.append("  \(key): \(value)")
    }

    static func scalar(_ key: String, in body: String) -> String? {
        let prefix = "\(key):"
        for line in body.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(prefix) else { continue }
            return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    static func list(_ key: String, in body: String) -> [String] {
        let lines = body.components(separatedBy: .newlines)
        let prefix = "\(key):"
        var values: [String] = []
        var isReading = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(prefix) {
                isReading = true
                continue
            }

            if isReading {
                if trimmed.hasPrefix("-") {
                    values.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                } else if !trimmed.isEmpty, !line.hasPrefix(" "), !line.hasPrefix("\t") {
                    break
                }
            }
        }

        return values.filter { !$0.isEmpty }
    }
}

struct YAMLCommonScalarForm: View {
    @EnvironmentObject private var model: AppModel
    let sectionKey: String
    @Binding private var yamlBody: String

    init(sectionKey: String, body: Binding<String>) {
        self.sectionKey = sectionKey
        _yamlBody = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch sectionKey {
            case "mode":
                YAMLPickerField(title: model.t(.mode), options: ["rule", "global", "direct"], selection: $yamlBody)
            case "log-level":
                YAMLPickerField(title: model.t(.logLevel), options: ["silent", "error", "warning", "info", "debug"], selection: $yamlBody)
            case "find-process-mode":
                YAMLPickerField(title: model.t(.processMode), options: ["off", "strict", "always"], selection: $yamlBody)
            case "allow-lan", "ipv6", "unified-delay", "tcp-concurrent":
                Toggle(model.t(.enabled), isOn: Binding(
                    get: { YAMLVisualValue.bool(yamlBody) },
                    set: { yamlBody = $0 ? "true" : "false" }
                ))
                .toggleStyle(.switch)
            default:
                YAMLTextField(title: title(for: sectionKey), text: $yamlBody)
            }
        }
    }

    static func supports(key: String) -> Bool {
        [
            "port",
            "socks-port",
            "mixed-port",
            "redir-port",
            "tproxy-port",
            "external-controller",
            "allow-lan",
            "ipv6",
            "unified-delay",
            "tcp-concurrent",
            "mode",
            "log-level",
            "find-process-mode",
            "secret"
        ].contains(key)
    }

    private func title(for key: String) -> String {
        switch key {
        case "port":
            return "HTTP \(model.t(.portNumber))"
        case "socks-port":
            return "SOCKS \(model.t(.portNumber))"
        case "mixed-port":
            return model.t(.mixedPort)
        case "redir-port":
            return "Redir \(model.t(.portNumber))"
        case "tproxy-port":
            return "TProxy \(model.t(.portNumber))"
        case "external-controller":
            return model.t(.controlAddress)
        case "secret":
            return model.t(.apiSecret)
        default:
            return model.t(.value)
        }
    }
}

struct YAMLRulesShortcutForm: View {
    @EnvironmentObject private var model: AppModel
    @Binding private var yamlBody: String
    @State private var ruleType = "DOMAIN-SUFFIX"
    @State private var ruleValue = ""
    @State private var policy = "DIRECT"
    @State private var noResolve = false

    init(body: Binding<String>) {
        _yamlBody = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t(.quickAddRule))
                .font(.caption.weight(.semibold))

            YAMLPickerField(
                title: model.t(.ruleType),
                options: ["DOMAIN-SUFFIX", "DOMAIN", "DOMAIN-KEYWORD", "IP-CIDR", "GEOIP", "PROCESS-NAME", "MATCH"],
                selection: $ruleType
            )
            YAMLTextField(title: model.t(.matchValue), text: $ruleValue)
            YAMLTextField(title: model.t(.targetPolicy), text: $policy)
            Toggle(model.t(.noResolve), isOn: $noResolve)
                .toggleStyle(.switch)

            Button {
                appendRule()
            } label: {
                Label(model.t(.addRule), systemImage: "plus")
            }
            .disabled(ruleValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ruleType != "MATCH")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    private func appendRule() {
        let value = ruleValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = policy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "DIRECT" : policy.trimmingCharacters(in: .whitespacesAndNewlines)
        var line = ruleType == "MATCH"
            ? "- MATCH,\(target)"
            : "- \(ruleType),\(value),\(target)"
        if noResolve, ruleType != "MATCH" {
            line += ",no-resolve"
        }
        yamlBody = YAMLVisualValue.appending(line, to: yamlBody)
        ruleValue = ""
    }
}

struct YAMLNodeShortcutForm: View {
    @EnvironmentObject private var model: AppModel
    @Binding private var yamlBody: String
    @State private var nodeName = ""
    @State private var nodeType = "ss"
    @State private var server = ""
    @State private var port = ""
    @State private var username = ""
    @State private var password = ""
    @State private var uuid = ""
    @State private var cipher = "auto"
    @State private var sni = ""
    @State private var udp = true
    @State private var tls = false

    init(body: Binding<String>) {
        _yamlBody = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t(.quickAddNode))
                .font(.caption.weight(.semibold))

            YAMLTextField(title: model.t(.name), text: $nodeName)
            YAMLPickerField(title: model.t(.nodeType), options: ["ss", "vmess", "trojan", "hysteria2", "http", "socks5"], selection: $nodeType)
            HStack(spacing: 8) {
                YAMLTextField(title: model.t(.server), text: $server)
                YAMLTextField(title: model.t(.portNumber), text: $port)
                    .frame(width: 100)
            }
            YAMLTextField(title: model.t(.username), text: $username)
            YAMLTextField(title: model.t(.password), text: $password)
            YAMLTextField(title: "UUID", text: $uuid)
            YAMLTextField(title: model.t(.cipher), text: $cipher)
            YAMLTextField(title: "SNI", text: $sni)
            HStack {
                Toggle("UDP", isOn: $udp)
                Toggle("TLS", isOn: $tls)
            }
            .toggleStyle(.switch)

            Button {
                appendNode()
            } label: {
                Label(model.t(.addNode), systemImage: "plus")
            }
            .disabled(nodeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    private func appendNode() {
        var lines = [
            "- name: \(YAMLVisualValue.clean(nodeName))",
            "  type: \(nodeType)",
            "  server: \(YAMLVisualValue.clean(server))"
        ]
        YAMLVisualValue.appendKey("port", value: port, to: &lines)
        YAMLVisualValue.appendKey("username", value: username, to: &lines)
        YAMLVisualValue.appendKey("password", value: password, to: &lines)
        YAMLVisualValue.appendKey("uuid", value: uuid, to: &lines)
        YAMLVisualValue.appendKey("cipher", value: cipher, to: &lines)
        YAMLVisualValue.appendKey("sni", value: sni, to: &lines)
        lines.append("  udp: \(udp ? "true" : "false")")
        if tls {
            lines.append("  tls: true")
        }
        yamlBody = YAMLVisualValue.appending(lines.joined(separator: "\n"), to: yamlBody)
        nodeName = ""
        server = ""
        port = ""
        username = ""
        password = ""
        uuid = ""
        sni = ""
    }
}

struct YAMLProxyGroupShortcutForm: View {
    @EnvironmentObject private var model: AppModel
    @Binding private var yamlBody: String
    @State private var groupName = ""
    @State private var groupType = "select"
    @State private var members = "DIRECT"
    @State private var testURL = "http://www.gstatic.com/generate_204"
    @State private var interval = "300"
    @State private var strategy = "consistent-hashing"

    init(body: Binding<String>) {
        _yamlBody = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t(.quickAddGroup))
                .font(.caption.weight(.semibold))

            YAMLTextField(title: model.t(.name), text: $groupName)
            YAMLPickerField(title: model.t(.groupType), options: ["select", "url-test", "fallback", "load-balance"], selection: $groupType)
            YAMLTextField(title: model.t(.groupMembers), text: $members)
            if groupType != "select" {
                YAMLTextField(title: model.t(.testURL), text: $testURL)
                YAMLTextField(title: model.t(.intervalSeconds), text: $interval)
            }
            if groupType == "load-balance" {
                YAMLPickerField(title: model.t(.strategy), options: ["consistent-hashing", "round-robin"], selection: $strategy)
            }

            Button {
                appendGroup()
            } label: {
                Label(model.t(.addGroup), systemImage: "plus")
            }
            .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    private func appendGroup() {
        var lines = [
            "- name: \(YAMLVisualValue.clean(groupName))",
            "  type: \(groupType)"
        ]
        if groupType != "select" {
            YAMLVisualValue.appendKey("url", value: testURL, to: &lines)
            YAMLVisualValue.appendKey("interval", value: interval, to: &lines)
        }
        if groupType == "load-balance" {
            lines.append("  strategy: \(strategy)")
        }
        lines.append("  proxies:")
        let proxyNames = members
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for name in proxyNames.isEmpty ? ["DIRECT"] : proxyNames {
            lines.append("    - \(name)")
        }
        yamlBody = YAMLVisualValue.appending(lines.joined(separator: "\n"), to: yamlBody)
        groupName = ""
    }
}

struct YAMLDNSShortcutForm: View {
    @EnvironmentObject private var model: AppModel
    @Binding private var yamlBody: String
    @State private var enabled = true
    @State private var listen = "127.0.0.1:1053"
    @State private var enhancedMode = "fake-ip"
    @State private var nameservers = "223.5.5.5\n119.29.29.29"
    @State private var fallbackServers = ""
    @State private var didLoad = false

    init(body: Binding<String>) {
        _yamlBody = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t(.dnsSettings))
                .font(.caption.weight(.semibold))

            Toggle(model.t(.enabled), isOn: $enabled)
                .toggleStyle(.switch)
            YAMLTextField(title: model.t(.listenAddress), text: $listen)
            YAMLPickerField(title: model.t(.enhancedMode), options: ["fake-ip", "redir-host", "normal"], selection: $enhancedMode)
            YAMLMultilineField(title: model.t(.nameserver), text: $nameservers)
            YAMLMultilineField(title: model.t(.fallback), text: $fallbackServers)

            Button {
                applyDNS()
            } label: {
                Label(model.t(.applySettings), systemImage: "checkmark")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            loadExisting()
        }
    }

    private func loadExisting() {
        enabled = YAMLVisualValue.bool(YAMLVisualValue.scalar("enable", in: yamlBody) ?? "true")
        listen = YAMLVisualValue.scalar("listen", in: yamlBody) ?? listen
        enhancedMode = YAMLVisualValue.scalar("enhanced-mode", in: yamlBody) ?? enhancedMode
        let existingNameservers = YAMLVisualValue.list("nameserver", in: yamlBody)
        if !existingNameservers.isEmpty {
            nameservers = existingNameservers.joined(separator: "\n")
        }
        let existingFallback = YAMLVisualValue.list("fallback", in: yamlBody)
        if !existingFallback.isEmpty {
            fallbackServers = existingFallback.joined(separator: "\n")
        }
    }

    private func applyDNS() {
        var lines = [
            "enable: \(enabled ? "true" : "false")",
            "listen: \(YAMLVisualValue.clean(listen))",
            "enhanced-mode: \(enhancedMode)",
            "nameserver:"
        ]
        for server in YAMLVisualValue.lines(nameservers) {
            lines.append("  - \(server)")
        }
        let fallback = YAMLVisualValue.lines(fallbackServers)
        if !fallback.isEmpty {
            lines.append("fallback:")
            for server in fallback {
                lines.append("  - \(server)")
            }
        }
        yamlBody = lines.joined(separator: "\n")
    }
}

struct YAMLHostsShortcutForm: View {
    @EnvironmentObject private var model: AppModel
    @Binding private var yamlBody: String
    @State private var domain = ""
    @State private var address = ""

    init(body: Binding<String>) {
        _yamlBody = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t(.quickAddHost))
                .font(.caption.weight(.semibold))

            YAMLTextField(title: model.t(.domain), text: $domain)
            YAMLTextField(title: model.t(.address), text: $address)
            Button {
                appendHost()
            } label: {
                Label(model.t(.addHost), systemImage: "plus")
            }
            .disabled(domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    private func appendHost() {
        yamlBody = YAMLVisualValue.appending("\(YAMLVisualValue.clean(domain)): \(YAMLVisualValue.clean(address))", to: yamlBody)
        domain = ""
        address = ""
    }
}

struct YAMLAdvancedSectionForm: View {
    @EnvironmentObject private var model: AppModel
    @Binding var key: String
    @Binding var bodyText: String

    init(key: Binding<String>, body: Binding<String>) {
        _key = key
        _bodyText = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.t(.advancedYAML))
                .font(.caption.weight(.semibold))
            YAMLTextField(title: model.t(.topLevelKey), text: $key)
            TextEditor(text: $bodyText)
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 260)
                .background(ChumenStyle.groupedSurface.opacity(0.35), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

private struct YAMLTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct YAMLMultilineField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
            TextEditor(text: $text)
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(height: 74)
                .background(ChumenStyle.groupedSurface.opacity(0.35), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(ChumenStyle.border.opacity(0.7))
                )
        }
    }
}

private struct YAMLPickerField: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
