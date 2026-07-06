import ChumenCore
import Foundation
import SwiftUI
import Textual

// AI assistant presentation is isolated from ContentView so the app shell only coordinates
// search scheduling and navigation. The assistant can be embedded in the dashboard workspace
// without owning routing, and it preserves the review-before-apply security boundary.
struct AIAssistantOverlayView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isPresented: Bool

    let searchResults: [GlobalSearchResult]
    @ObservedObject var markdownCache: AIAssistantMarkdownCache
    let onSearchChanged: () -> Void
    let onSearchImmediately: () -> Void
    let onClearSearchResults: () -> Void
    let onSubmit: () -> Void
    let onSelectSearchResult: (GlobalSearchResult) -> Void

    // The assistant owns only its text-field focus. Search scheduling and navigation stay outside
    // through callbacks so this view can move between overlay/sidebar presentations safely.
    @FocusState private var aiInputFocused: Bool
    @State private var aiAdvancedConfigExpanded = false

    var body: some View {
        aiAssistantPanel
            .onAppear {
                model.appendAppLog(
                    "ai assistant appear; ready=\(model.aiReady); provider=\(String(describing: model.settings.ai.provider)); " +
                        "messages=\(model.aiMessages.count); pendingChanges=\(model.aiPendingChanges.count)"
                )
                if !model.aiReady {
                    onSearchImmediately()
                    aiAdvancedConfigExpanded = true
                }
                if model.settings.ai.usesLocalOllama {
                    model.refreshOllamaModelsIfNeeded()
                }
                markdownCache.prepare(messages: model.aiMessages, log: model.appendAppLog)
            }
            .onChange(of: model.aiMessages) { _, messages in
                markdownCache.prepare(messages: messages, log: model.appendAppLog)
            }
    }

    private var searchQuery: String {
        model.aiInputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // The panel has three modes in one surface: provider setup, chat, and pending-change review.
    // Keeping them stacked here makes the audit path visible before any AI-proposed config edit is applied.
    private var aiAssistantPanel: some View {
        VStack(spacing: 0) {
            aiAssistantHeader

            Divider()

            GeometryReader { proxy in
                let inspectorWidth = min(CGFloat(360), max(CGFloat(308), proxy.size.width * 0.28))
                if proxy.size.width >= 980 {
                    HStack(spacing: 0) {
                        aiConversationColumn
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Divider()

                        aiInspectorColumn
                            .frame(width: inspectorWidth)
                    }
                } else {
                    VStack(spacing: 0) {
                        aiConversationColumn
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Divider()

                        aiInspectorColumn
                            .frame(maxWidth: .infinity, maxHeight: 230)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChumenStyle.surface)
        .onChange(of: model.aiInputText) {
            if !model.aiReady {
                onSearchChanged()
            }
        }
        .onChange(of: model.aiReady) {
            if !model.aiReady {
                onSearchImmediately()
            }
        }
    }

    private var aiAssistantHeader: some View {
        HStack(spacing: 8) {
            Label(model.t(.aiAssistant), systemImage: "sparkles")
                .font(.headline.weight(.semibold))
            Text(aiAssistantStatusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(model.aiReady ? Color.green : ChumenStyle.mutedText)
                .lineLimit(1)
            Spacer()
            Button {
                model.clearAIMessages()
                onClearSearchResults()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(model.t(.aiClearChat))

            Button {
                aiInputFocused = false
                isPresented = false
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help(model.t(.aiCloseAssistant))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // Chat owns the primary space. The input bar is pinned to the bottom of this column so model
    // setup or pending diffs in the inspector can never push the command field out of view.
    private var aiConversationColumn: some View {
        VStack(spacing: 0) {
            Group {
                if model.aiReady {
                    aiMessagesList
                } else {
                    searchResultsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            aiInputBar
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChumenStyle.surface)
    }

    // The right column is an inspector, not another dashboard. It holds controls that users may need
    // while chatting, plus review artifacts; runtime facts stay in the AI prompt and top command bar.
    private var aiInspectorColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                aiConfigurationSection

                if !model.aiPendingChanges.isEmpty {
                    aiPendingChangesView
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ChumenStyle.groupedSurface.opacity(0.34))
    }

    // Settings are inline because the fastest local path is Ollama. The user can get value from the
    // assistant without first visiting a separate settings page or exposing an API key.
    private var aiConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            aiAssistantEnableRow
            aiConfigurationCard
            Text(model.t(.aiReviewBeforeApply))
                .font(.caption2)
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aiAssistantEnableRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.t(.aiModelSettings))
                    .font(.callout.weight(.semibold))
                Text(aiActiveModelSummary)
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $model.settings.ai.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .onChange(of: model.settings.ai.isEnabled) {
                    model.scheduleSettingsAutosave()
                }
        }
    }

    // The setup controls are grouped as one compact inspector card. This keeps the fixed rail from
    // looking like a settings page while still making the active backend and model editable in place.
    private var aiConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            aiProviderPicker

            Divider()

            DisclosureGroup(isExpanded: $aiAdvancedConfigExpanded) {
                VStack(alignment: .leading, spacing: 9) {
                    if model.settings.ai.usesLocalOllama {
                        localOllamaConfiguration
                    } else if model.settings.ai.usesCodexWebAPI {
                        codexWebAPIConfiguration
                    } else if model.settings.ai.usesCodexAgent {
                        codexAgentConfiguration
                    } else {
                        customAIConfiguration
                    }

                    if model.settings.ai.requiresAPIKey || model.settings.ai.acceptsOptionalAPIKey {
                        aiAPIKeyConfiguration
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.t(.aiModel))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text(aiActiveModelSummary)
                            .font(.caption2)
                            .foregroundStyle(ChumenStyle.mutedText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.groupedSurface.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .controlSize(.small)
    }

    private var aiActiveModelSummary: String {
        let provider: String
        switch model.settings.ai.provider {
        case .localOllama:
            provider = model.t(.aiUseLocalOllama)
        case .codexWebAPI:
            provider = model.t(.aiUseCodexWebAPI)
        case .codexAgent:
            provider = model.t(.aiUseCodexAgent)
        case .customEndpoint:
            provider = model.t(.aiCustomEndpoint)
        }
        let modelName = model.settings.ai.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.settings.ai.usesCodexAgent, modelName.isEmpty {
            return "\(model.t(.aiCodexReady)) · \(model.t(.aiCodexDefaultModelShort))"
        }
        return modelName.isEmpty ? "\(provider) · \(model.t(.aiModelRequired))" : "\(provider) · \(modelName)"
    }

    // The provider selector is stateful rather than two loose buttons so users can see which backend
    // is active. Local Ollama is zero-key and discovers models; custom endpoints expose raw fields.
    private var aiProviderPicker: some View {
        Picker(model.t(.aiModelSettings), selection: Binding(
            get: { model.settings.ai.provider.rawValue },
            set: { provider in
                if provider == ChumenAIProvider.localOllama.rawValue {
                    model.useLocalOllamaAI()
                } else if provider == ChumenAIProvider.codexWebAPI.rawValue {
                    model.useCodexWebAPIAI()
                } else {
                    model.useCustomAIEndpoint()
                }
            }
        )) {
            Label(model.t(.aiUseLocalOllama), systemImage: "desktopcomputer")
                .tag(ChumenAIProvider.localOllama.rawValue)
            Label(model.t(.aiUseCodexWebAPI), systemImage: "sparkles")
                .tag(ChumenAIProvider.codexWebAPI.rawValue)
            Label(model.t(.aiCustomEndpoint), systemImage: "network")
                .tag(ChumenAIProvider.customEndpoint.rawValue)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var localOllamaConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            aiFieldRow(model.t(.aiBaseURL)) {
                HStack(spacing: 8) {
                    TextField(model.t(.aiBaseURL), text: $model.settings.ai.baseURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: model.settings.ai.baseURL) {
                            model.scheduleSettingsAutosave()
                        }

                    Button {
                        model.refreshOllamaModels()
                    } label: {
                        Image(systemName: model.aiOllamaModelsLoading ? "hourglass" : "arrow.clockwise")
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.aiOllamaModelsLoading)
                    .help(model.t(.aiRefreshModels))
                }
            }

            aiFieldRow(model.t(.aiModel)) {
                HStack(spacing: 8) {
                    TextField(model.t(.aiManualModel), text: Binding(
                        get: { model.settings.ai.model },
                        set: { model.setAIModel($0) }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Menu {
                        if model.aiOllamaModels.isEmpty {
                            Button(model.t(.aiNoLocalModels)) {}
                                .disabled(true)
                        } else {
                            ForEach(model.aiOllamaModels, id: \.self) { modelName in
                                Button {
                                    model.setAIModel(modelName)
                                } label: {
                                    Label(
                                        modelName,
                                        systemImage: model.settings.ai.model == modelName ? "checkmark" : "circle"
                                    )
                                }
                            }
                        }

                        Divider()

                        Button {
                            model.refreshOllamaModels()
                        } label: {
                            Label(model.t(.aiRefreshModels), systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Label(model.t(.aiSelectModel), systemImage: "list.bullet")
                            .lineLimit(1)
                            .frame(minWidth: 54)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.aiOllamaModelsLoading && model.aiOllamaModels.isEmpty)
                }
            }
        }
    }

    private var customAIConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            aiFieldRow(model.t(.aiBaseURL)) {
                TextField(model.t(.aiBaseURL), text: $model.settings.ai.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: model.settings.ai.baseURL) {
                        model.scheduleSettingsAutosave()
                    }
            }
            aiFieldRow(model.t(.aiModel)) {
                TextField(model.t(.aiModel), text: Binding(
                    get: { model.settings.ai.model },
                    set: { model.setAIModel($0) }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var codexWebAPIConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            aiFieldRow(model.t(.aiBaseURL)) {
                TextField(model.t(.aiBaseURL), text: $model.settings.ai.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: model.settings.ai.baseURL) {
                        model.scheduleSettingsAutosave()
                    }
            }
            aiFieldRow(model.t(.aiModel)) {
                TextField(model.t(.aiModel), text: Binding(
                    get: { model.settings.ai.model },
                    set: { model.setAIModel($0) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 7) {
                Image(systemName: "checkmark.shield")
                    .foregroundStyle(Color.green)
                Text(model.t(.aiCodexWebAPIHint))
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var codexAgentConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            aiFieldRow(model.t(.aiModel)) {
                TextField(model.t(.aiCodexModelPlaceholder), text: Binding(
                    get: { model.settings.ai.model },
                    set: { model.setAIModel($0) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 7) {
                Image(systemName: "checkmark.shield")
                    .foregroundStyle(Color.green)
                Text(model.t(.aiCodexNoKeyRequired))
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 7) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(Color.accentColor)
                Text(model.t(.aiCodexMCPInherited))
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var aiAPIKeyConfiguration: some View {
        VStack(alignment: .leading, spacing: 6) {
            aiFieldRow(model.settings.ai.acceptsOptionalAPIKey ? model.t(.aiCodexAccessKey) : model.t(.aiAPIKey)) {
                HStack(spacing: 8) {
                    SecureField(
                        model.settings.ai.acceptsOptionalAPIKey ? model.t(.aiCodexAccessKey) : model.t(.aiAPIKey),
                        text: $model.aiAPIKeyInput
                    )
                    .textFieldStyle(.roundedBorder)
                    Button(model.t(.aiSaveKey)) {
                        model.saveAIAPIKey()
                    }
                    .buttonStyle(.bordered)
                    Button(model.t(.aiClearKey)) {
                        model.clearAIAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.aiAPIKeyStored)
                }
            }

            if model.settings.ai.acceptsOptionalAPIKey {
                Text(model.t(.aiCodexAccessKeyHint))
                    .font(.caption2)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func aiFieldRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 66, alignment: .leading)
            content()
        }
    }

    private var aiAssistantStatusText: String {
        if model.aiReady {
            if model.settings.ai.usesLocalOllama {
                return model.t(.aiOllamaReady)
            }
            if model.settings.ai.usesCodexAgent || model.settings.ai.usesCodexWebAPI {
                return model.t(.aiCodexReady)
            }
            return model.t(.aiKeyStored)
        }
        if model.settings.ai.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return model.t(.aiModelRequired)
        }
        if model.settings.ai.usesCodexAgent {
            return model.t(.aiCodexUnavailable)
        }
        if model.settings.ai.usesCodexWebAPI {
            return model.t(.aiCodexUnavailable)
        }
        return model.settings.ai.requiresAPIKey ? model.t(.aiSearchOnly) : model.t(.aiOllamaReady)
    }

    private var aiMessagesList: some View {
        let visibleMessages = recentAIMessages

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 9) {
                if model.aiMessages.isEmpty {
                    Text(model.t(.aiNoMessages))
                        .font(.callout)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ForEach(visibleMessages) { message in
                        aiMessageBubble(message)
                    }
                }

                if !model.aiStatusText.isEmpty {
                    Text(model.aiStatusText)
                        .font(.caption)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
        }
    }

    private var recentAIMessages: [ChumenAIChatMessage] {
        AIAssistantRendering.visibleMessages(from: model.aiMessages)
    }

    private func aiMessageBubble(_ message: ChumenAIChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser {
                Spacer(minLength: 36)
            }
            aiMessageContent(message)
                .font(.callout)
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(isUser ? Color.accentColor.opacity(0.14) : ChumenStyle.groupedSurface)
                )
                .frame(maxWidth: isUser ? 520 : 700, alignment: isUser ? .trailing : .leading)
            if !isUser {
                Spacer(minLength: 14)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func aiMessageContent(_ message: ChumenAIChatMessage) -> some View {
        if let document = markdownCache.document(for: message) {
            StructuredText(
                document.source,
                parser: CachedAIMarkdownParser(attributedString: document.attributedString)
            )
            .textual.structuredTextStyle(.gitHub)
            .textual.textSelection(.enabled)
        } else {
            Text(message.content)
        }
    }

    // When AI is disabled or incomplete, the assistant intentionally remains useful as search.
    // This avoids a dead assistant rail and lets users learn the command surface before adding a key.
    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.t(.searchResults))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
                Spacer()
                Text("\(searchResults.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ChumenStyle.mutedText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            if !GlobalSearchEngine.isSearchableQuery(searchQuery) {
                Text(model.t(.aiSearchOnly))
                    .font(.callout)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                Label(model.t(.noSearchResults), systemImage: "magnifyingglass")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults) { result in
                            Button {
                                onSelectSearchResult(result)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: result.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 20, height: 20)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(result.title)
                                            .font(.callout.weight(.semibold))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text(result.detail.isEmpty ? result.subtitle : result.detail)
                                            .font(.caption)
                                            .foregroundStyle(ChumenStyle.mutedText)
                                            .lineLimit(2)
                                            .truncationMode(.middle)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if result.id != searchResults.last?.id {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
            }
        }
    }

    // AI proposals are staged here instead of applied immediately. The app must preserve a
    // human-review step for config edits because they can change network routing and credentials.
    private var aiPendingChangesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.t(.aiPendingChanges))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
                Spacer()
                Text("\(model.aiPendingChanges.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ChumenStyle.mutedText)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.aiPendingChanges) { change in
                        aiProposedChangeRow(change)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .background(ChumenStyle.groupedSurface.opacity(0.45))
    }

    // Each proposed change shows a small diff-like preview. The model may suggest multiple edits,
    // so every row keeps its own accept/reject actions instead of a single blind "apply all" path.
    private func aiProposedChangeRow(_ change: ChumenAIProposedChange) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(change.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    if !change.detail.isEmpty {
                        Text(change.detail)
                            .font(.caption)
                            .foregroundStyle(ChumenStyle.mutedText)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }

            if !change.diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.t(.aiDiff))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ChumenStyle.mutedText)
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(change.diff)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(Color.primary)
                            .padding(8)
                    }
                    .frame(maxHeight: 86)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(ChumenStyle.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(ChumenStyle.border.opacity(0.75))
                    )
                }
            }

            HStack(spacing: 8) {
                Spacer()
                Button(model.t(.aiDismissChange)) {
                    model.dismissAIProposedChange(change)
                }
                .buttonStyle(.bordered)
                Button(model.t(.aiApplyChange)) {
                    model.applyAIProposedChange(change)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }

    // The input bar switches between search and chat based on provider readiness. The send button
    // follows the same mode so keyboard submit and button click cannot diverge.
    private var aiInputBar: some View {
        HStack(spacing: 8) {
            TextField(model.t(.aiAskPlaceholder), text: $model.aiInputText)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($aiInputFocused)
                .autocorrectionDisabled(true)
                .onSubmit {
                    onSubmit()
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(ChumenStyle.groupedSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .strokeBorder(ChumenStyle.border)
                )

            Button {
                onSubmit()
            } label: {
                Image(systemName: model.aiReady ? "paperplane.fill" : "magnifyingglass")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.aiInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.aiIsSending)
            .help(model.aiReady ? model.t(.aiSend) : model.t(.aiUseAsSearch))
        }
    }
}
