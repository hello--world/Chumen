import ChumenCore
import SwiftUI

struct YAMLSectionPreviewView: View {
    @EnvironmentObject private var model: AppModel
    let preview: YAMLSectionPreviewData
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(preview.title, systemImage: preview.systemImage)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(preview.totalCount) \(model.t(.entries))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
            }

            if isLoading {
                Spacer()
                ProgressView(model.t(.loadingPreview))
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if preview.items.isEmpty {
                Spacer()
                Label(model.t(.noPreviewItems), systemImage: "list.bullet.rectangle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(preview.items) { item in
                            YAMLSectionPreviewRow(item: item)
                        }

                        if preview.isLimited {
                            Text(model.t(.previewLimited))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(ChumenStyle.mutedText)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .padding(10)
    }
}

private struct YAMLSectionPreviewRow: View {
    let item: YAMLSectionPreviewItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(item.badge)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.badgeColor)
                .frame(width: 54, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.primary)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !item.secondary.isEmpty {
                    Text(item.secondary)
                        .font(.caption2)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(ChumenStyle.groupedSurface.opacity(0.48), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct YAMLSectionPreviewData: Equatable, Sendable {
    static let previewLimit = 360
    static let empty = YAMLSectionPreviewData(
        key: "",
        title: "",
        systemImage: "list.bullet.rectangle",
        totalCount: 0,
        items: [],
        isLimited: false
    )

    let key: String
    let title: String
    let systemImage: String
    let totalCount: Int
    let items: [YAMLSectionPreviewItem]
    let isLimited: Bool

    static func placeholder(for key: String) -> YAMLSectionPreviewData {
        YAMLSectionPreviewData(
            key: key,
            title: key,
            systemImage: systemImage(for: key),
            totalCount: 0,
            items: [],
            isLimited: false
        )
    }

    static func make(key: String, body: String) -> YAMLSectionPreviewData {
        let normalizedKey = key.lowercased()
        let builder: PreviewBuilder

        if normalizedKey == ProfileSectionEditorKind.rules.yamlKey {
            builder = makeRulesPreview(body)
        } else if normalizedKey == ProfileSectionEditorKind.proxies.yamlKey {
            builder = makeNamedYAMLListPreview(body, fallbackBadge: "proxy")
        } else if normalizedKey == ProfileSectionEditorKind.proxyGroups.yamlKey {
            builder = makeNamedYAMLListPreview(body, fallbackBadge: "group")
        } else {
            builder = makeGenericPreview(body)
        }

        return YAMLSectionPreviewData(
            key: key,
            title: key,
            systemImage: systemImage(for: key),
            totalCount: builder.totalCount,
            items: builder.items,
            isLimited: builder.totalCount > builder.items.count
        )
    }

    private static func makeRulesPreview(_ body: String) -> PreviewBuilder {
        var builder = PreviewBuilder()
        body.enumerateLines { line, _ in
            let trimmed = stripListMarker(line)
            guard !trimmed.isEmpty else { return }

            let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false).map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
            guard parts.count >= 2 else { return }

            builder.totalCount += 1
            guard builder.items.count < previewLimit else { return }
            let policy = parts.dropFirst(2).joined(separator: ", ")
            builder.items.append(
                YAMLSectionPreviewItem(
                    badge: parts[0],
                    primary: parts[1],
                    secondary: policy,
                    role: .rule
                )
            )
        }
        return builder
    }

    private static func makeNamedYAMLListPreview(_ body: String, fallbackBadge: String) -> PreviewBuilder {
        var builder = PreviewBuilder()
        var currentName = ""
        var currentType = fallbackBadge
        var currentDetails: [String] = []

        func flush() {
            guard !currentName.isEmpty else { return }
            builder.totalCount += 1
            if builder.items.count < previewLimit {
                builder.items.append(
                    YAMLSectionPreviewItem(
                        badge: currentType,
                        primary: currentName,
                        secondary: currentDetails.joined(separator: "  "),
                        role: fallbackBadge == "group" ? .group : .node
                    )
                )
            }
            currentName = ""
            currentType = fallbackBadge
            currentDetails = []
        }

        body.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") {
                let value = stripListMarker(trimmed)
                if value.hasPrefix("name:") {
                    flush()
                    currentName = value.dropYAMLKey("name")
                } else if value.hasPrefix("{") {
                    flush()
                    let inline = parseInlineMap(value)
                    if let name = inline["name"], !name.isEmpty {
                        currentName = name
                        currentType = inline["type"] ?? fallbackBadge
                        currentDetails = [inline["server"], inline["port"]].compactMap { $0 }
                        flush()
                    }
                }
                return
            }

            if trimmed.hasPrefix("type:") {
                currentType = trimmed.dropYAMLKey("type")
            } else if trimmed.hasPrefix("server:") {
                let server = trimmed.dropYAMLKey("server")
                if !server.isEmpty {
                    currentDetails.append(server)
                }
            } else if trimmed.hasPrefix("port:") {
                let port = trimmed.dropYAMLKey("port")
                if !port.isEmpty {
                    currentDetails.append(port)
                }
            } else if trimmed.hasPrefix("strategy:") {
                let strategy = trimmed.dropYAMLKey("strategy")
                if !strategy.isEmpty {
                    currentDetails.append(strategy)
                }
            }
        }
        flush()
        return builder
    }

    private static func makeGenericPreview(_ body: String) -> PreviewBuilder {
        var builder = PreviewBuilder()
        body.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return }
            builder.totalCount += 1
            guard builder.items.count < previewLimit else { return }

            let keyAndValue = splitYAMLKeyValue(trimmed)
            builder.items.append(
                YAMLSectionPreviewItem(
                    badge: keyAndValue.key,
                    primary: keyAndValue.value.isEmpty ? trimmed : keyAndValue.value,
                    secondary: "",
                    role: .generic
                )
            )
        }
        return builder
    }

    static func systemImage(for key: String) -> String {
        switch key.lowercased() {
        case ProfileSectionEditorKind.rules.yamlKey:
            return ProfileSectionEditorKind.rules.systemImage
        case ProfileSectionEditorKind.proxies.yamlKey:
            return ProfileSectionEditorKind.proxies.systemImage
        case ProfileSectionEditorKind.proxyGroups.yamlKey:
            return ProfileSectionEditorKind.proxyGroups.systemImage
        case "dns":
            return "server.rack"
        case "hosts":
            return "network"
        default:
            return "list.bullet.rectangle"
        }
    }

    private static func stripListMarker(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("-") else { return trimmed }
        return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private static func splitYAMLKeyValue(_ line: String) -> (key: String, value: String) {
        guard let colon = line.firstIndex(of: ":") else {
            return ("item", line)
        }
        let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
        let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        return (key.isEmpty ? "item" : key, value)
    }

    private static func parseInlineMap(_ value: String) -> [String: String] {
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
        var result: [String: String] = [:]
        for pair in trimmed.split(separator: ",") {
            guard let colon = pair.firstIndex(of: ":") else { continue }
            let key = String(pair[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(pair[pair.index(after: colon)...])
                .trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
            if !key.isEmpty {
                result[key] = value
            }
        }
        return result
    }

    private struct PreviewBuilder {
        var totalCount = 0
        var items: [YAMLSectionPreviewItem] = []
    }
}

struct YAMLSectionPreviewItem: Identifiable, Equatable, Sendable {
    enum Role: Sendable {
        case rule
        case node
        case group
        case generic
    }

    let id = UUID()
    let badge: String
    let primary: String
    let secondary: String
    let role: Role

    var badgeColor: Color {
        switch role {
        case .rule:
            return .purple
        case .node:
            return .blue
        case .group:
            return .orange
        case .generic:
            return ChumenStyle.mutedText
        }
    }
}

private extension String {
    func dropYAMLKey(_ key: String) -> String {
        let prefix = "\(key):"
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }
}
