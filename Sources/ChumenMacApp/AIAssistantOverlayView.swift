import ChumenCore
import SwiftUI

// AI assistant presentation is isolated from ContentView so the app shell only coordinates
// visibility, search scheduling, and navigation. The assistant still reads AppModel directly
// because settings, messages, and pending changes are one feature surface.
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
    // through callbacks so this view can be redesigned without changing app state routing.
    @FocusState private var aiInputFocused: Bool

    var body: some View {
        aiAssistantLayer
    }

    private var searchQuery: String {
        model.aiInputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // The layer is full-size only for positioning. It does not own hit-testing outside the button or
    // panel, so normal app interactions continue unless the panel itself is open.
    private var aiAssistantLayer: some View {
        GeometryReader { proxy in
            VStack {
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    if isPresented {
                        aiAssistantPanel
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottomTrailing)))
                    } else {
                        aiFloatingButton
                    }
                }
                .padding(.trailing, proxy.size.width < 760 ? 14 : 20)
                .padding(.bottom, 18)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    // This is deliberately a floating command affordance, not another tab. AI is a cross-page tool:
    // it can search current app data or propose edits regardless of the selected page.
    private var aiFloatingButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                isPresented = true
            }
            DispatchQueue.main.async {
                aiInputFocused = true
                if !model.aiReady {
                    onSearchImmediately()
                }
            }
        } label: {
            Label(model.t(.aiAssistant), systemImage: "sparkles")
                .font(.callout.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(Color.accentColor)
                )
                .foregroundStyle(.white)
                .shadow(color: ChumenStyle.softShadow.opacity(5), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
        .help(model.t(.aiOpenAssistant))
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
                    withAnimation(.easeOut(duration: 0.14)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
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
        .frame(width: 420, height: 590)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .shadow(color: ChumenStyle.softShadow.opacity(6), radius: 24, y: 12)
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
        VStack(alignment: .leading, spacing: 8) {
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

            HStack(spacing: 8) {
                Button {
                    model.useLocalOllamaAI()
                } label: {
                    Label(model.t(.aiUseLocalOllama), systemImage: "desktopcomputer")
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)

                Text(model.settings.ai.usesLocalOllama ? model.t(.aiOllamaNoKeyRequired) : model.t(.aiRemoteAPI))
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                TextField(model.t(.aiBaseURL), text: $model.settings.ai.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: model.settings.ai.baseURL) {
                        model.scheduleSettingsAutosave()
                    }
                TextField(model.t(.aiModel), text: $model.settings.ai.model)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 132)
                    .onChange(of: model.settings.ai.model) {
                        model.scheduleSettingsAutosave()
                    }
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

    private var aiAssistantStatusText: String {
        if model.aiReady {
            return model.settings.ai.usesLocalOllama ? model.t(.aiOllamaReady) : model.t(.aiKeyStored)
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
    // This avoids a dead floating button and lets users learn the command surface before adding a key.
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
