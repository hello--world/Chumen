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

private func orderedUniqueValues(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .filter { seen.insert($0).inserted }
}

private enum YAMLSectionPatchBody {
    static let operations = ["prepend", "append", "delete"]

    static func bucket(_ operation: String, in body: String) -> String {
        var currentOperation: String?
        var linesByOperation: [String: [String]] = [:]
        let normalizedLines = unindented(body.components(separatedBy: .newlines))

        for line in normalizedLines.components(separatedBy: .newlines) {
            if let key = ChumenConfigurationBuilder.topLevelKey(in: line), operations.contains(key) {
                currentOperation = key
                let inline = inlineValue(in: line)
                if inline.isEmpty || inline == "[]" {
                    linesByOperation[key] = linesByOperation[key] ?? []
                } else {
                    linesByOperation[key, default: []].append(contentsOf: inlineListItems(inline))
                }
                continue
            }

            if let currentOperation {
                linesByOperation[currentOperation, default: []].append(line)
            }
        }

        return unindented(linesByOperation[operation] ?? [])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func replacing(_ operation: String, in body: String, with value: String) -> String {
        var buckets = Dictionary(uniqueKeysWithValues: operations.map { ($0, bucket($0, in: body)) })
        buckets[operation] = value
        return render(prepend: buckets["prepend"] ?? "", append: buckets["append"] ?? "", delete: buckets["delete"] ?? "")
    }

    static func appendingItem(_ item: String, operation: String, in body: String) -> String {
        let normalized = normalizedListItem(item)
        guard !normalized.isEmpty else { return body }
        let current = bucket(operation, in: body)
        let updated = YAMLVisualValue.appending(normalized, to: current)
        return replacing(operation, in: body, with: updated)
    }

    private static func normalizedListItem(_ item: String) -> String {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.hasPrefix("-") ? trimmed : "- \(trimmed)"
    }

    private static func render(prepend: String, append: String, delete: String) -> String {
        operations.map { operation in
            let value: String
            switch operation {
            case "prepend": value = prepend
            case "append": value = append
            default: value = delete
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "\(operation): []" }
            return "\(operation):\n\(indented(trimmed, spaces: 2))"
        }
        .joined(separator: "\n")
    }

    private static func inlineValue(in line: String) -> String {
        guard let colon = line.firstIndex(of: ":") else { return "" }
        return String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    }

    private static func inlineListItems(_ value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else {
            return ["- \(trimmed)"]
        }
        return trimmed.dropFirst().dropLast()
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r\"'")) }
            .filter { !$0.isEmpty }
            .map { "- \($0)" }
    }

    private static func unindented(_ lines: [String]) -> String {
        let indents = lines
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { indentation(of: $0) }
            .filter { $0 > 0 }
        guard let commonIndent = indents.min() else {
            return lines.joined(separator: "\n")
        }
        return lines.map { removeLeadingSpaces(commonIndent, from: $0) }.joined(separator: "\n")
    }

    private static func indented(_ text: String, spaces: Int) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return text.components(separatedBy: .newlines)
            .map { $0.isEmpty ? "" : prefix + $0 }
            .joined(separator: "\n")
    }

    private static func indentation(of line: String) -> Int {
        var count = 0
        for character in line {
            if character == " " {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    private static func removeLeadingSpaces(_ count: Int, from line: String) -> String {
        var index = line.startIndex
        var removed = 0
        while removed < count, index < line.endIndex, line[index] == " " {
            index = line.index(after: index)
            removed += 1
        }
        return String(line[index...])
    }
}

private enum SectionPatchOperation: String, CaseIterable, Identifiable {
    case prepend
    case append
    case delete

    var id: String { rawValue }

    var titleKey: L10n.Key {
        switch self {
        case .prepend: .prependAppend
        case .append: .appendAppend
        case .delete: .deleteOriginalItems
        }
    }

    var systemImage: String {
        switch self {
        case .prepend: "text.insert"
        case .append: "text.append"
        case .delete: "trash"
        }
    }

    var color: Color {
        switch self {
        case .prepend: .blue
        case .append: .green
        case .delete: .red
        }
    }
}

private struct YAMLSectionPatchQuickAddForm: View {
    @EnvironmentObject private var model: AppModel
    let kind: ProfileSectionEditorKind
    let onAdd: (SectionPatchOperation, String) -> Void

    @State private var operation: SectionPatchOperation = .prepend
    @State private var ruleType = "DOMAIN-SUFFIX"
    @State private var matchValue = ""
    @State private var policy = "DIRECT"
    @State private var extraRuleOption = ""
    @State private var itemName = ""
    @State private var proxyType = "vless"
    @State private var server = ""
    @State private var port = "443"
    @State private var username = ""
    @State private var password = ""
    @State private var uuid = ""
    @State private var cipher = "auto"
    @State private var sni = ""
    @State private var udp = true
    @State private var tls = true
    @State private var extraYAMLLines = ""
    @State private var groupType = "select"
    @State private var selectedMember = "DIRECT"
    @State private var memberList: [String] = ["DIRECT"]

    private let ruleTypes = [
        "DOMAIN-SUFFIX",
        "DOMAIN",
        "DOMAIN-KEYWORD",
        "IP-CIDR",
        "IP-CIDR6",
        "GEOIP",
        "GEOSITE",
        "PROCESS-NAME",
        "MATCH"
    ]
    private let proxyTypes = ["vless", "vmess", "trojan", "ss", "socks5", "http", "hysteria2", "direct"]
    private let groupTypes = ["select", "url-test", "fallback", "load-balance"]
    private let commonPorts = ["443", "80", "8080", "7890", "1080", "8388"]
    private let ssCiphers = [
        "2022-blake3-aes-128-gcm",
        "2022-blake3-aes-256-gcm",
        "aes-128-gcm",
        "aes-256-gcm",
        "chacha20-ietf-poly1305"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Label(model.t(quickAddTitleKey), systemImage: "square.and.pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                operationPicker
            }

            switch kind {
            case .rules:
                ruleForm
            case .proxies:
                proxyForm
            case .proxyGroups:
                proxyGroupForm
            }

            HStack(spacing: 8) {
                generatedPreview
                Button {
                    addGeneratedItem()
                } label: {
                    Label(model.t(.addGeneratedItem), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(generatedItem == nil)
            }
        }
        .padding(10)
        .background(ChumenStyle.groupedSurface.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(ChumenStyle.border.opacity(0.7))
        )
    }

    private var operationPicker: some View {
        HStack(spacing: 5) {
            ForEach(SectionPatchOperation.allCases) { item in
                Button {
                    operation = item
                } label: {
                    Label(model.t(item.titleKey), systemImage: item.systemImage)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .foregroundStyle(operation == item ? item.color : ChumenStyle.mutedText)
                        .background(
                            (operation == item ? item.color.opacity(0.14) : Color.clear),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder((operation == item ? item.color : ChumenStyle.border).opacity(0.45))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickAddTitleKey: L10n.Key {
        switch kind {
        case .rules: .quickAddRule
        case .proxies: .quickAddNode
        case .proxyGroups: .quickAddGroup
        }
    }

    private var ruleForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                pickerField(model.t(.ruleType), selection: $ruleType, values: ruleTypes)
                    .frame(width: 145)
                if ruleType != "MATCH" {
                    textField(model.t(.matchValue), text: $matchValue, placeholder: "example.com / 1.1.1.1/32")
                        .frame(minWidth: 160)
                }
                pickerField(model.t(.targetPolicy), selection: $policy, values: rulePolicyOptions)
                    .frame(width: 160)
            }
            textField(model.t(.optionalArgs), text: $extraRuleOption, placeholder: "no-resolve")
        }
    }

    private var rulePolicyOptions: [String] {
        let fixed = ["DIRECT", "REJECT", "REJECT-DROP", "PASS"]
        let runtimeGroups = model.proxyGroups
            .map(\.name)
            .map(clean)
            .filter { !$0.isEmpty }
        return uniqueValues([policy, "DIRECT"] + runtimeGroups + fixed)
    }

    private var proxyForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                textField(model.t(.name), text: $itemName, placeholder: "us-1")
                pickerField(model.t(.nodeType), selection: $proxyType, values: proxyTypes)
                    .frame(width: 112)
            }
            if operation != .delete, proxyType != "direct" {
                HStack(alignment: .top, spacing: 8) {
                    textField(model.t(.server), text: $server, placeholder: "example.com")
                    pickerField(model.t(.portNumber), selection: $port, values: orderedUniqueValues([port] + commonPorts))
                        .frame(width: 82)
                }
                proxyCredentialFields
                HStack {
                    Toggle("UDP", isOn: $udp)
                    if supportsTLS {
                        Toggle("TLS", isOn: $tls)
                    }
                }
                .toggleStyle(.switch)
                DisclosureGroup(model.t(.extraYAMLFields)) {
                    multilineField(model.t(.extraYAMLFields), text: $extraYAMLLines, minHeight: 48)
                }
                .font(.caption.weight(.medium))
            }
        }
    }

    @ViewBuilder
    private var proxyCredentialFields: some View {
        switch proxyType {
        case "ss":
            pickerField(model.t(.cipher), selection: $cipher, values: ssCiphers)
            textField(model.t(.password), text: $password, placeholder: "password")
        case "vmess", "vless":
            textField("UUID", text: $uuid, placeholder: "uuid")
            if supportsTLS {
                textField("SNI", text: $sni, placeholder: "server name")
            }
        case "trojan", "hysteria2":
            textField(model.t(.password), text: $password, placeholder: "password")
            textField("SNI", text: $sni, placeholder: "server name")
        case "http", "socks5":
            HStack(alignment: .top, spacing: 8) {
                textField(model.t(.username), text: $username, placeholder: model.t(.username))
                textField(model.t(.password), text: $password, placeholder: model.t(.password))
            }
        default:
            EmptyView()
        }
    }

    private var supportsTLS: Bool {
        ["vless", "vmess", "trojan", "hysteria2"].contains(proxyType)
    }

    private var proxyGroupForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                textField(model.t(.name), text: $itemName, placeholder: "Auto")
                if operation != .delete {
                    pickerField(model.t(.groupType), selection: $groupType, values: groupTypes)
                        .frame(width: 122)
                }
            }
            if operation != .delete {
                memberPicker
            }
        }
    }

    private var memberPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t(.groupMembers))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
            HStack(spacing: 8) {
                Picker("", selection: $selectedMember) {
                    ForEach(availableProxyMembers, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                .labelsHidden()
                .controlSize(.small)

                Button {
                    addSelectedMember()
                } label: {
                    Label(model.t(.addGeneratedItem), systemImage: "plus")
                }
                .controlSize(.small)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(memberList, id: \.self) { member in
                        Button {
                            memberList.removeAll { $0 == member }
                        } label: {
                            Label(member, systemImage: "xmark")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
        }
    }

    private var availableProxyMembers: [String] {
        let runtime = model.proxyGroups.flatMap { [$0.name] + $0.options }
        return orderedUniqueValues(["DIRECT", "REJECT", "PASS"] + runtime)
    }

    private var generatedPreview: some View {
        HStack(spacing: 6) {
            Text(model.t(.generatedItem))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
            Text(generatedItem ?? model.t(.fillRequiredFields))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(generatedItem == nil ? ChumenStyle.mutedText : Color.primary)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(ChumenStyle.surface.opacity(0.42), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var generatedItem: String? {
        switch kind {
        case .rules:
            generatedRuleItem
        case .proxies:
            generatedProxyItem
        case .proxyGroups:
            generatedProxyGroupItem
        }
    }

    private var generatedRuleItem: String? {
        let type = clean(ruleType)
        let target = clean(policy)
        guard !type.isEmpty, !target.isEmpty else { return nil }
        var parts = [type]
        if type != "MATCH" {
            let value = clean(matchValue)
            guard !value.isEmpty else { return nil }
            parts.append(value)
        }
        parts.append(target)
        let option = clean(extraRuleOption)
        if !option.isEmpty {
            parts.append(option)
        }
        return "- \(parts.joined(separator: ","))"
    }

    private var generatedProxyItem: String? {
        let name = clean(itemName)
        guard !name.isEmpty else { return nil }
        if operation == .delete {
            return "- \(name)"
        }

        var lines = [
            "- name: \(name)",
            "  type: \(clean(proxyType))"
        ]
        if proxyType != "direct" {
            let host = clean(server)
            let portValue = clean(port)
            guard !host.isEmpty, !portValue.isEmpty else { return nil }
            lines.append("  server: \(host)")
            lines.append("  port: \(portValue)")
            appendProxyProtocolFields(to: &lines)
        }
        lines.append(contentsOf: normalizedExtraLines(prefix: "  "))
        return lines.joined(separator: "\n")
    }

    private var generatedProxyGroupItem: String? {
        let name = clean(itemName)
        guard !name.isEmpty else { return nil }
        if operation == .delete {
            return "- \(name)"
        }

        let memberValues = memberList
        guard !memberValues.isEmpty else { return nil }
        var lines = [
            "- name: \(name)",
            "  type: \(clean(groupType))",
            "  proxies:"
        ]
        lines.append(contentsOf: memberValues.map { "    - \($0)" })
        lines.append(contentsOf: normalizedExtraLines(prefix: "  "))
        return lines.joined(separator: "\n")
    }

    private func addGeneratedItem() {
        guard let item = generatedItem else { return }
        onAdd(operation, item)
        clearPrimaryFields()
    }

    private func clearPrimaryFields() {
        switch kind {
        case .rules:
            matchValue = ""
            extraRuleOption = ""
        case .proxies:
            itemName = ""
            server = ""
            port = "443"
            username = ""
            password = ""
            uuid = ""
            sni = ""
            extraYAMLLines = ""
        case .proxyGroups:
            itemName = ""
            memberList = ["DIRECT"]
            selectedMember = "DIRECT"
            extraYAMLLines = ""
        }
    }

    private func appendProxyProtocolFields(to lines: inout [String]) {
        switch proxyType {
        case "ss":
            YAMLVisualValue.appendKey("cipher", value: cipher, to: &lines)
            YAMLVisualValue.appendKey("password", value: password, to: &lines)
        case "vmess", "vless":
            YAMLVisualValue.appendKey("uuid", value: uuid, to: &lines)
            if supportsTLS {
                lines.append("  tls: \(tls ? "true" : "false")")
                YAMLVisualValue.appendKey("servername", value: sni, to: &lines)
            }
        case "trojan", "hysteria2":
            YAMLVisualValue.appendKey("password", value: password, to: &lines)
            lines.append("  tls: \(tls ? "true" : "false")")
            YAMLVisualValue.appendKey("sni", value: sni, to: &lines)
        case "http", "socks5":
            YAMLVisualValue.appendKey("username", value: username, to: &lines)
            YAMLVisualValue.appendKey("password", value: password, to: &lines)
        default:
            break
        }
        lines.append("  udp: \(udp ? "true" : "false")")
    }

    private func addSelectedMember() {
        let value = clean(selectedMember)
        guard !value.isEmpty, !memberList.contains(value) else { return }
        memberList.append(value)
    }

    private func textField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
        }
    }

    private func pickerField(_ title: String, selection: Binding<String>, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
            Picker("", selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text(value).tag(value)
                }
            }
            .labelsHidden()
            .controlSize(.small)
        }
    }

    private func multilineField(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
            TextEditor(text: text)
                .font(.system(.caption2, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .background(ChumenStyle.surface.opacity(0.35), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(ChumenStyle.border.opacity(0.7))
                )
        }
    }

    private func normalizedExtraLines(prefix: String) -> [String] {
        extraYAMLLines
            .components(separatedBy: .newlines)
            .map(clean)
            .filter { !$0.isEmpty }
            .map { prefix + $0 }
    }

    private func uniqueValues(_ values: [String]) -> [String] {
        orderedUniqueValues(values)
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct YAMLSectionPatchForm: View {
    @EnvironmentObject private var model: AppModel
    let kind: ProfileSectionEditorKind
    @Binding private var yamlBody: String

    init(kind: ProfileSectionEditorKind, body: Binding<String>) {
        self.kind = kind
        _yamlBody = body
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                YAMLSectionPatchQuickAddForm(kind: kind) { operation, item in
                    yamlBody = YAMLSectionPatchBody.appendingItem(item, operation: operation.rawValue, in: yamlBody)
                }

                Label(model.t(.advancedBuckets), systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)

                patchBucket(
                    operation: "prepend",
                    title: model.t(.prependAppend),
                    hint: model.t(.patchPrependHint),
                    color: .blue
                )
                patchBucket(
                    operation: "append",
                    title: model.t(.appendAppend),
                    hint: model.t(.patchAppendHint),
                    color: .green
                )
                patchBucket(
                    operation: "delete",
                    title: model.t(.deleteOriginalItems),
                    hint: kind == .rules ? model.t(.patchDeleteRuleHint) : model.t(.patchDeleteNameHint),
                    color: .red
                )
            }
            .padding(2)
        }
    }

    private func patchBucket(operation: String, title: String, hint: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(operation)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(color.opacity(0.88))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.10), in: Capsule())
                Spacer()
                Text("\(itemCount(for: operation))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
            }

            Text(hint)
                .font(.caption2)
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(2)

            TextEditor(text: bucketBinding(operation))
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: operation == "delete" ? 74 : 118)
                .background(ChumenStyle.groupedSurface.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(color.opacity(0.24))
                )
        }
        .padding(10)
        .background(color.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.18))
        )
    }

    private func bucketBinding(_ operation: String) -> Binding<String> {
        Binding(
            get: { YAMLSectionPatchBody.bucket(operation, in: yamlBody) },
            set: { yamlBody = YAMLSectionPatchBody.replacing(operation, in: yamlBody, with: $0) }
        )
    }

    private func itemCount(for operation: String) -> Int {
        YAMLSectionPatchBody.bucket(operation, in: yamlBody)
            .components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") }
            .count
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
            case "port", "socks-port", "mixed-port", "redir-port", "tproxy-port":
                YAMLPickerField(
                    title: title(for: sectionKey),
                    options: orderedUniqueValues([yamlBody, "7890", "7897", "7898", "7899", "1080", "8080"]),
                    selection: $yamlBody
                )
            case "external-controller":
                YAMLPickerField(
                    title: model.t(.controlAddress),
                    options: orderedUniqueValues([yamlBody, "127.0.0.1:9090", "127.0.0.1:19897", "0.0.0.0:9090"]),
                    selection: $yamlBody
                )
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
            YAMLPickerField(title: model.t(.targetPolicy), options: policyOptions, selection: $policy)
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

    private var policyOptions: [String] {
        orderedUniqueValues([policy, "DIRECT"] + model.proxyGroups.map(\.name) + ["REJECT", "REJECT-DROP", "PASS"])
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
    @State private var nodeType = "vless"
    @State private var server = ""
    @State private var port = "443"
    @State private var username = ""
    @State private var password = ""
    @State private var uuid = ""
    @State private var cipher = "auto"
    @State private var sni = ""
    @State private var udp = true
    @State private var tls = true

    private let commonPorts = ["443", "80", "8080", "7890", "1080", "8388"]
    private let nodeTypes = ["vless", "vmess", "trojan", "ss", "socks5", "http", "hysteria2", "direct"]
    private let ssCiphers = [
        "2022-blake3-aes-128-gcm",
        "2022-blake3-aes-256-gcm",
        "aes-128-gcm",
        "aes-256-gcm",
        "chacha20-ietf-poly1305"
    ]

    init(body: Binding<String>) {
        _yamlBody = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t(.quickAddNode))
                .font(.caption.weight(.semibold))

            YAMLTextField(title: model.t(.name), text: $nodeName)
            YAMLPickerField(title: model.t(.nodeType), options: nodeTypes, selection: $nodeType)
            if nodeType != "direct" {
                HStack(spacing: 8) {
                    YAMLTextField(title: model.t(.server), text: $server)
                    YAMLPickerField(title: model.t(.portNumber), options: orderedUniqueValues([port] + commonPorts), selection: $port)
                        .frame(width: 110)
                }
                protocolFields
                HStack {
                    Toggle("UDP", isOn: $udp)
                    if supportsTLS {
                        Toggle("TLS", isOn: $tls)
                    }
                }
                .toggleStyle(.switch)
            }

            Button {
                appendNode()
            } label: {
                Label(model.t(.addNode), systemImage: "plus")
            }
            .disabled(nodeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (nodeType != "direct" && server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    @ViewBuilder
    private var protocolFields: some View {
        switch nodeType {
        case "ss":
            YAMLPickerField(title: model.t(.cipher), options: ssCiphers, selection: $cipher)
            YAMLTextField(title: model.t(.password), text: $password)
        case "vmess", "vless":
            YAMLTextField(title: "UUID", text: $uuid)
            if supportsTLS {
                YAMLTextField(title: "SNI", text: $sni)
            }
        case "trojan", "hysteria2":
            YAMLTextField(title: model.t(.password), text: $password)
            YAMLTextField(title: "SNI", text: $sni)
        case "http", "socks5":
            YAMLTextField(title: model.t(.username), text: $username)
            YAMLTextField(title: model.t(.password), text: $password)
        default:
            EmptyView()
        }
    }

    private var supportsTLS: Bool {
        ["vless", "vmess", "trojan", "hysteria2"].contains(nodeType)
    }

    private func appendNode() {
        var lines = [
            "- name: \(YAMLVisualValue.clean(nodeName))",
            "  type: \(nodeType)"
        ]
        if nodeType != "direct" {
            lines.append("  server: \(YAMLVisualValue.clean(server))")
            YAMLVisualValue.appendKey("port", value: port, to: &lines)
            appendProtocolFields(to: &lines)
        }
        yamlBody = YAMLVisualValue.appending(lines.joined(separator: "\n"), to: yamlBody)
        nodeName = ""
        server = ""
        port = "443"
        username = ""
        password = ""
        uuid = ""
        sni = ""
    }

    private func appendProtocolFields(to lines: inout [String]) {
        switch nodeType {
        case "ss":
            YAMLVisualValue.appendKey("cipher", value: cipher, to: &lines)
            YAMLVisualValue.appendKey("password", value: password, to: &lines)
        case "vmess", "vless":
            YAMLVisualValue.appendKey("uuid", value: uuid, to: &lines)
            if supportsTLS {
                lines.append("  tls: \(tls ? "true" : "false")")
                YAMLVisualValue.appendKey("servername", value: sni, to: &lines)
            }
        case "trojan", "hysteria2":
            YAMLVisualValue.appendKey("password", value: password, to: &lines)
            lines.append("  tls: \(tls ? "true" : "false")")
            YAMLVisualValue.appendKey("sni", value: sni, to: &lines)
        case "http", "socks5":
            YAMLVisualValue.appendKey("username", value: username, to: &lines)
            YAMLVisualValue.appendKey("password", value: password, to: &lines)
        default:
            break
        }
        lines.append("  udp: \(udp ? "true" : "false")")
    }
}

struct YAMLProxyGroupShortcutForm: View {
    @EnvironmentObject private var model: AppModel
    @Binding private var yamlBody: String
    @State private var groupName = ""
    @State private var groupType = "select"
    @State private var selectedMember = "DIRECT"
    @State private var members: [String] = ["DIRECT"]
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
            groupMemberPicker
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

    private var groupMemberPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t(.groupMembers))
                .font(.caption2.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
            HStack(spacing: 8) {
                YAMLPickerField(title: "", options: availableMembers, selection: $selectedMember)
                Button {
                    addSelectedMember()
                } label: {
                    Label(model.t(.addGeneratedItem), systemImage: "plus")
                }
                .controlSize(.small)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(members, id: \.self) { member in
                        Button {
                            members.removeAll { $0 == member }
                        } label: {
                            Label(member, systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
        }
    }

    private var availableMembers: [String] {
        let runtime = model.proxyGroups.flatMap { [$0.name] + $0.options }
        return orderedUniqueValues(["DIRECT", "REJECT", "PASS"] + runtime)
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
        for name in members.isEmpty ? ["DIRECT"] : members {
            lines.append("    - \(name)")
        }
        yamlBody = YAMLVisualValue.appending(lines.joined(separator: "\n"), to: yamlBody)
        groupName = ""
    }

    private func addSelectedMember() {
        let value = YAMLVisualValue.clean(selectedMember)
        guard !value.isEmpty, !members.contains(value) else { return }
        members.append(value)
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
