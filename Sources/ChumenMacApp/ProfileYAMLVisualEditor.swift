import ChumenCore
import SwiftUI

struct LiveYAMLCodeEditor: View {
    @EnvironmentObject private var model: AppModel
    @Binding var text: String
    @Binding var sections: [YAMLTopLevelSection]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            YAMLVisualEditor(text: $text, sections: $sections)
                .frame(minWidth: 460, idealWidth: 500, maxWidth: .infinity, minHeight: 510)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label(model.t(.codeEditor), systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)

                YAMLTextView(text: $text)
                    .frame(minWidth: 480, minHeight: 510)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct YAMLVisualEditor: View {
    @EnvironmentObject private var model: AppModel
    @Binding var text: String
    @Binding var sections: [YAMLTopLevelSection]
    @State private var selectedIndex: Int?
    @State private var draftKey = ""
    @State private var draftBody = ""
    @State private var isLoadingDraft = false
    @State private var isCommittingFromVisual = false
    @State private var selectedBodyIsLarge = false
    @State private var selectedPreview = YAMLSectionPreviewData.empty
    @State private var selectedPreviewIsLoading = false
    @State private var parseTask: Task<Void, Never>?
    @State private var visualCommitTask: Task<Void, Never>?
    @State private var previewTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(model.t(.visualEditor), systemImage: "slider.horizontal.3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(commonSectionTemplates, id: \.key) { template in
                        Button {
                            addSection(key: template.key, body: template.body)
                        } label: {
                            Label(template.title, systemImage: template.systemImage)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .labelStyle(.titleAndIcon)
                .padding(.bottom, 2)
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(model.t(.topLevelKey))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ChumenStyle.mutedText)
                        Spacer()
                        Button {
                            addSection()
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.borderless)
                        .help(model.t(.addSection))
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            if sections.isEmpty {
                                Label(model.t(.addSection), systemImage: "plus")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(ChumenStyle.mutedText)
                                    .padding(10)
                            } else {
                                ForEach(sections.indices, id: \.self) { index in
                                    sectionButton(sections[index], index: index)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ChumenStyle.groupedSurface.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .frame(width: 150)

                VStack(alignment: .leading, spacing: 8) {
                    selectedSectionForm()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ChumenStyle.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(ChumenStyle.border)
                        )

                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            deleteSelectedSection()
                        } label: {
                            Label(model.t(.deleteSection), systemImage: "trash")
                        }
                        .disabled(selectedIndex == nil)
                    }
                }
            }
        }
        .onAppear {
            if sections.isEmpty, !text.isEmpty {
                scheduleSectionSync(immediate: true)
            } else {
                syncDraftWithSections()
            }
        }
        .onChange(of: textChangeToken) {
            guard !isCommittingFromVisual else { return }
            scheduleSectionSync(immediate: false)
        }
        .onChange(of: sectionKeys) {
            syncDraftWithSections()
        }
        .onChange(of: draftKey) {
            commitDraftToText()
        }
        .onChange(of: draftBody) {
            commitDraftToText()
            guard selectedBodyIsLarge, !isLoadingDraft else { return }
            schedulePreview(for: YAMLTopLevelSection(key: draftKey, body: draftBody))
        }
        .onDisappear {
            parseTask?.cancel()
            parseTask = nil
            visualCommitTask?.cancel()
            visualCommitTask = nil
            previewTask?.cancel()
            previewTask = nil
        }
    }

    private static let visualBodyEditLimit = 160_000
    private static let visualImmediateCommitLimit = 700_000
    private static let parseDebounceNanoseconds: UInt64 = 700_000_000
    private static let visualCommitDebounceNanoseconds: UInt64 = 450_000_000

    private var sectionKeys: [String] {
        sections.map(\.key)
    }

    private var textChangeToken: String {
        let length = text.utf16.count
        guard length <= Self.visualImmediateCommitLimit else {
            return "large:\(length)"
        }
        return text
    }

    private var commonSectionTemplates: [(key: String, title: String, systemImage: String, body: String)] {
        [
            (
                key: "mixed-port",
                title: model.t(.mixedPort),
                systemImage: "network",
                body: "7890"
            ),
            (
                key: "allow-lan",
                title: model.t(.allowLAN),
                systemImage: "switch.2",
                body: "false"
            ),
            (
                key: "mode",
                title: model.t(.mode),
                systemImage: "point.3.connected.trianglepath.dotted",
                body: "rule"
            ),
            (
                key: "log-level",
                title: model.t(.logLevel),
                systemImage: "text.alignleft",
                body: "info"
            ),
            (
                key: ProfileSectionEditorKind.rules.yamlKey,
                title: model.t(.editRules),
                systemImage: ProfileSectionEditorKind.rules.systemImage,
                body: "- DOMAIN,example.com,DIRECT"
            ),
            (
                key: ProfileSectionEditorKind.proxies.yamlKey,
                title: model.t(.editNodes),
                systemImage: ProfileSectionEditorKind.proxies.systemImage,
                body: "- name: example\n  type: http\n  server: 127.0.0.1\n  port: 7890"
            ),
            (
                key: ProfileSectionEditorKind.proxyGroups.yamlKey,
                title: model.t(.editProxyGroups),
                systemImage: ProfileSectionEditorKind.proxyGroups.systemImage,
                body: "- name: Auto\n  type: select\n  proxies:\n    - DIRECT"
            ),
            (
                key: "dns",
                title: model.t(.dns),
                systemImage: "server.rack",
                body: "enable: true\nlisten: 127.0.0.1:1053\nenhanced-mode: fake-ip\nnameserver:\n  - 223.5.5.5\n  - 119.29.29.29"
            ),
            (
                key: "hosts",
                title: "hosts",
                systemImage: "network",
                body: "example.com: 127.0.0.1"
            )
        ]
    }

    @ViewBuilder
    private func selectedSectionForm() -> some View {
        if selectedIndex == nil {
            VStack(spacing: 8) {
                Label(model.t(.selectSectionToEdit), systemImage: "cursorarrow.click")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let key = draftKey.lowercased()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sectionFormHeader()

                    if YAMLCommonScalarForm.supports(key: key) {
                        YAMLCommonScalarForm(sectionKey: key, body: $draftBody)
                    } else if key == ProfileSectionEditorKind.rules.yamlKey {
                        YAMLRulesShortcutForm(body: $draftBody)
                        YAMLSectionPreviewView(preview: currentPreviewData(), isLoading: selectedBodyIsLarge && selectedPreviewIsLoading)
                            .frame(minHeight: 190)
                    } else if key == ProfileSectionEditorKind.proxies.yamlKey {
                        YAMLNodeShortcutForm(body: $draftBody)
                        YAMLSectionPreviewView(preview: currentPreviewData(), isLoading: selectedBodyIsLarge && selectedPreviewIsLoading)
                            .frame(minHeight: 190)
                    } else if key == ProfileSectionEditorKind.proxyGroups.yamlKey {
                        YAMLProxyGroupShortcutForm(body: $draftBody)
                        YAMLSectionPreviewView(preview: currentPreviewData(), isLoading: selectedBodyIsLarge && selectedPreviewIsLoading)
                            .frame(minHeight: 190)
                    } else if key == "dns" {
                        YAMLDNSShortcutForm(body: $draftBody)
                    } else if key == "hosts" {
                        YAMLHostsShortcutForm(body: $draftBody)
                        YAMLSectionPreviewView(preview: currentPreviewData(), isLoading: selectedBodyIsLarge && selectedPreviewIsLoading)
                            .frame(minHeight: 190)
                    } else if selectedBodyIsLarge {
                        YAMLSectionPreviewView(preview: selectedPreview, isLoading: selectedPreviewIsLoading)
                            .frame(minHeight: 320)
                    } else {
                        YAMLAdvancedSectionForm(key: $draftKey, body: $draftBody)
                    }
                }
                .padding(10)
            }
        }
    }

    private func sectionFormHeader() -> some View {
        HStack(spacing: 8) {
            Label(draftKey, systemImage: YAMLSectionPreviewData.systemImage(for: draftKey))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(model.t(.formEditor))
                .font(.caption2.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
        }
    }

    private func currentPreviewData() -> YAMLSectionPreviewData {
        if selectedBodyIsLarge {
            return selectedPreview
        }
        return YAMLSectionPreviewData.make(key: draftKey, body: draftBody)
    }

    private func sectionButton(_ section: YAMLTopLevelSection, index: Int) -> some View {
        Button {
            selectSection(at: index, from: sections)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.text.square")
                    .foregroundStyle(ChumenStyle.mutedText)
                Text(section.key)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selectedIndex == index ? Color.accentColor.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func addSection() {
        addSection(key: "profile", body: "")
    }

    private func addSection(key baseKey: String, body: String) {
        if sections.isEmpty, !text.isEmpty {
            let section = YAMLTopLevelSection(key: baseKey, body: body)
            let insertion = YAMLTopLevelSection.render([section])
            let separator = text.isEmpty ? "" : "\n\n"
            setTextFromVisual(text + separator + insertion)
            scheduleSectionSync(immediate: true)
            return
        }

        var updatedSections = sections
        let key = uniqueKey(base: baseKey, in: updatedSections)
        updatedSections.append(YAMLTopLevelSection(key: key, body: body))
        sections = updatedSections
        commitSectionsToText(updatedSections, debounce: false)
        selectSection(at: updatedSections.count - 1, from: updatedSections)
    }

    private func deleteSelectedSection() {
        guard let selectedIndex else { return }
        var updatedSections = sections
        guard updatedSections.indices.contains(selectedIndex) else { return }
        updatedSections.remove(at: selectedIndex)
        sections = updatedSections
        commitSectionsToText(updatedSections, debounce: false)

        if updatedSections.isEmpty {
            clearDraft()
        } else {
            selectSection(at: min(selectedIndex, updatedSections.count - 1), from: updatedSections)
        }
    }

    private func syncDraftWithSections() {
        guard !sections.isEmpty else {
            clearDraft()
            return
        }

        let index = selectedIndex.flatMap { sections.indices.contains($0) ? $0 : nil } ?? 0
        selectSection(at: index, from: sections)
    }

    private func selectSection(at index: Int, from sections: [YAMLTopLevelSection]) {
        guard sections.indices.contains(index) else {
            clearDraft()
            return
        }

        isLoadingDraft = true
        selectedIndex = index
        draftKey = sections[index].key
        selectedBodyIsLarge = sections[index].body.utf16.count > Self.visualBodyEditLimit
        draftBody = sections[index].body
        if selectedBodyIsLarge {
            schedulePreview(for: sections[index])
        } else {
            previewTask?.cancel()
            selectedPreview = .empty
            selectedPreviewIsLoading = false
        }
        DispatchQueue.main.async {
            isLoadingDraft = false
        }
    }

    private func clearDraft() {
        isLoadingDraft = true
        selectedIndex = nil
        draftKey = ""
        draftBody = ""
        selectedBodyIsLarge = false
        selectedPreview = .empty
        selectedPreviewIsLoading = false
        previewTask?.cancel()
        DispatchQueue.main.async {
            isLoadingDraft = false
        }
    }

    private func commitDraftToText() {
        guard !isLoadingDraft else { return }
        guard let selectedIndex else { return }
        var updatedSections = sections
        guard updatedSections.indices.contains(selectedIndex) else { return }

        let key = sanitizedKey(draftKey)
        guard !key.isEmpty else { return }

        updatedSections[selectedIndex].key = key
        updatedSections[selectedIndex].body = draftBody
        sections = updatedSections
        commitSectionsToText(updatedSections, debounce: true)
    }

    private func setTextFromVisual(_ yaml: String) {
        parseTask?.cancel()
        isCommittingFromVisual = true
        text = yaml
        DispatchQueue.main.async {
            isCommittingFromVisual = false
        }
    }

    private func commitSectionsToText(_ updatedSections: [YAMLTopLevelSection], debounce: Bool) {
        guard text.utf16.count > Self.visualImmediateCommitLimit || debounce else {
            setTextFromVisual(YAMLTopLevelSection.render(updatedSections))
            return
        }

        visualCommitTask?.cancel()
        visualCommitTask = Task { @MainActor in
            if debounce {
                try? await Task.sleep(nanoseconds: Self.visualCommitDebounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            let yaml = await Task.detached(priority: .utility) {
                YAMLTopLevelSection.render(updatedSections)
            }.value
            guard !Task.isCancelled else { return }
            setTextFromVisual(yaml)
        }
    }

    private func scheduleSectionSync(immediate: Bool) {
        parseTask?.cancel()
        let snapshot = text
        parseTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(nanoseconds: Self.parseDebounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            let parsed = await Task.detached(priority: .utility) {
                YAMLTopLevelSection.parse(snapshot)
            }.value
            guard !Task.isCancelled else { return }
            sections = parsed
            syncDraftWithSections()
        }
    }

    private func schedulePreview(for section: YAMLTopLevelSection) {
        selectedPreviewIsLoading = true
        selectedPreview = YAMLSectionPreviewData.placeholder(for: section.key)
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            let preview = await Task.detached(priority: .utility) {
                YAMLSectionPreviewData.make(key: section.key, body: section.body)
            }.value
            guard !Task.isCancelled else { return }
            selectedPreview = preview
            selectedPreviewIsLoading = false
        }
    }

    private func sanitizedKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
    }

    private func uniqueKey(base: String, in sections: [YAMLTopLevelSection]) -> String {
        let keys = Set(sections.map(\.key))
        guard keys.contains(base) else { return base }

        var index = 2
        while keys.contains("\(base)-\(index)") {
            index += 1
        }
        return "\(base)-\(index)"
    }
}
