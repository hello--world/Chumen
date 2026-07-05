import ChumenCore
import SwiftUI

// AI assistant presentation is isolated from ContentView so the app shell only coordinates
// search scheduling and navigation. The assistant is now a fixed right rail: it does not cover page
// controls, can be collapsed by the user, and preserves the review-before-apply security boundary.
struct AIAssistantOverlayView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isPresented: Bool

    let searchResults: [GlobalSearchResult]
    let onSearchChanged: () -> Void
    let onSearchImmediately: () -> Void
    let onClearSearchResults: () -> Void
    let onSubmit: () -> Void
    let onSelectSearchResult: (GlobalSearchResult) -> Void

    // The assistant owns only its text-field focus. Search scheduling and navigation stay outside
    // through callbacks so this view can move between overlay/sidebar presentations safely.
    @FocusState private var aiInputFocused: Bool

    var body: some View {
        aiAssistantPanel
            .onAppear {
                if !model.aiReady {
                    onSearchImmediately()
                }
                if model.settings.ai.usesLocalOllama {
                    model.refreshOllamaModelsIfNeeded()
                }
            }
    }

    private var searchQuery: String {
        model.aiInputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // The panel has three modes in one surface: provider setup, chat, and pending-change review.
    // Keeping them stacked here makes the audit path visible before any AI-proposed config edit is applied.
    private var aiAssistantPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label(model.t(.aiAssistant), systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
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
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.borderless)
                .help(model.t(.aiCloseAssistant))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            aiConfigurationSection
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            Group {
                if model.aiReady {
                    aiMessagesList
                } else {
                    searchResultsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !model.aiPendingChanges.isEmpty {
                Divider()
                aiPendingChangesView
                    .frame(maxHeight: 184)
            }

            Divider()
            aiInputBar
                .padding(12)
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

    // Settings are inline because the fastest local path is Ollama. The user can get value from the
    // assistant without first visiting a separate settings page or exposing an API key.
    private var aiConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Toggle(model.t(.aiAssistant), isOn: $model.settings.ai.isEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: model.settings.ai.isEnabled) {
                        model.scheduleSettingsAutosave()
                    }
                Spacer()
                Text(aiAssistantStatusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(model.aiReady ? Color.green : ChumenStyle.mutedText)
                    .lineLimit(1)
            }

            aiProviderPicker

            if model.settings.ai.usesLocalOllama {
                localOllamaConfiguration
            } else {
                customAIConfiguration
            }

            if model.settings.ai.requiresAPIKey {
                HStack(spacing: 8) {
                    SecureField(model.t(.aiAPIKey), text: $model.aiAPIKeyInput)
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

            Text(model.t(.aiReviewBeforeApply))
                .font(.caption)
                .foregroundStyle(ChumenStyle.mutedText)
        }
    }

    // The provider selector is stateful rather than two loose buttons so users can see which backend
    // is active. Local Ollama is zero-key and discovers models; custom endpoints expose raw fields.
    private var aiProviderPicker: some View {
        Picker(model.t(.aiModelSettings), selection: Binding(
            get: { model.settings.ai.usesLocalOllama ? "ollama" : "custom" },
            set: { provider in
                if provider == "ollama" {
                    model.useLocalOllamaAI()
                } else {
                    model.useCustomAIEndpoint()
                }
            }
        )) {
            Label(model.t(.aiUseLocalOllama), systemImage: "desktopcomputer")
                .tag("ollama")
            Label(model.t(.aiCustomEndpoint), systemImage: "network")
                .tag("custom")
        }
        .pickerStyle(.segmented)
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
                        HStack(spacing: 6) {
                            Text(model.settings.ai.model.isEmpty ? model.t(.aiModelRequired) : model.settings.ai.model)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ChumenStyle.mutedText)
                        }
                        .frame(minHeight: 30, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 145)

                    TextField(model.t(.aiManualModel), text: Binding(
                        get: { model.settings.ai.model },
                        set: { model.setAIModel($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
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

    private func aiFieldRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
                .frame(width: 58, alignment: .leading)
            content()
        }
    }

    private var aiAssistantStatusText: String {
        if model.aiReady {
            return model.settings.ai.usesLocalOllama ? model.t(.aiOllamaReady) : model.t(.aiKeyStored)
        }
        if model.settings.ai.usesLocalOllama &&
            model.settings.ai.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return model.t(.aiModelRequired)
        }
        return model.settings.ai.requiresAPIKey ? model.t(.aiSearchOnly) : model.t(.aiOllamaReady)
    }

    private var aiMessagesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 9) {
                if model.aiMessages.isEmpty {
                    Text(model.t(.aiNoMessages))
                        .font(.callout)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ForEach(model.aiMessages) { message in
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

    private func aiMessageBubble(_ message: ChumenAIChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser {
                Spacer(minLength: 36)
            }
            Text(message.content)
                .font(.callout)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(isUser ? Color.accentColor.opacity(0.14) : ChumenStyle.groupedSurface)
                )
                .frame(maxWidth: 330, alignment: isUser ? .trailing : .leading)
            if !isUser {
                Spacer(minLength: 36)
            }
        }
        .frame(maxWidth: .infinity)
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
