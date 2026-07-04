import SwiftUI

// The global search overlay owns the transient search presentation: input focus, scope chips,
// and result rows. ContentView stays responsible only for navigation and search scheduling so
// future visual tweaks do not require editing the app shell.
struct GlobalSearchOverlayView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var text: String
    @Binding var scope: GlobalSearchScope

    let results: [GlobalSearchResult]
    let shouldShowResults: Bool
    let onAppear: () -> Void
    let onDismiss: () -> Void
    let onClear: () -> Void
    let onTextChanged: () -> Void
    let onSubmit: () -> Void
    let onScopeSelected: (GlobalSearchScope) -> Void
    let onSelectResult: (GlobalSearchResult) -> Void

    // Focus stays inside the overlay instead of ContentView. This avoids cross-file focus rings and
    // lets the overlay reclaim focus after clear/scope actions without exposing UI internals.
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = proxy.size.width < 760 ? 16 : 24
            let panelWidth = max(320, proxy.size.width - horizontalPadding * 2)

            ZStack(alignment: .top) {
                // Nearly-transparent dismiss layer keeps clicks outside the panel predictable while
                // preserving the visual appearance of the underlying app.
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onDismiss()
                    }

                // The search field visually replaces the header row. A non-hit-testing cover avoids
                // accidental header interactions without making the whole window feel modal.
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(ChumenStyle.pageBackground)
                        .frame(height: 96)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(ChumenStyle.border)
                                .frame(height: 1)
                        }
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 8) {
                    overlayInput

                    if shouldShowResults {
                        resultsPanel
                    }
                }
                .frame(width: panelWidth)
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            DispatchQueue.main.async {
                searchFocused = true
                onAppear()
            }
        }
        .onExitCommand {
            onDismiss()
        }
    }

    // Search input is kept as a large overlay control rather than reusing the compact header field:
    // after activation the user needs enough width for Chinese input, command-like queries, and
    // visible composition text.
    private var overlayInput: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(ChumenStyle.mutedText)

            TextField(model.t(.globalSearchPlaceholder), text: $text)
                .textFieldStyle(.plain)
                .font(.title3.weight(.medium))
                .focused($searchFocused)
                .autocorrectionDisabled(true)
                .onChange(of: text) {
                    onTextChanged()
                }
                .onSubmit {
                    onSubmit()
                }

            if !text.isEmpty {
                Button {
                    onClear()
                    DispatchQueue.main.async {
                        searchFocused = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ChumenStyle.mutedText)
                .help(model.t(.clear))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.55))
        )
        .shadow(color: ChumenStyle.softShadow.opacity(3), radius: 20, y: 12)
    }

    // Result panel is capped by height, not item count display. The engine decides result count;
    // this view only guarantees the panel stays usable on small macOS windows.
    private var resultsPanel: some View {
        let resultListHeight = results.isEmpty ? 92 : min(360, max(160, CGFloat(results.count) * 58))

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.t(.searchResults))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
                Spacer()
                Text("\(scopeTitle(scope)) · \(results.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ChumenStyle.mutedText)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(GlobalSearchScope.allCases) { item in
                        scopeButton(item)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 9)
            }

            Divider()

            if results.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text(model.t(.noSearchResults))
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
                .frame(maxWidth: .infinity, minHeight: resultListHeight)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { result in
                            resultRow(result)
                            if result.id != results.last?.id {
                                Divider()
                                    .padding(.leading, 42)
                            }
                        }
                    }
                }
                .frame(height: resultListHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .shadow(color: ChumenStyle.softShadow.opacity(2.5), radius: 18, y: 10)
    }

    // Scope chips are presentation-only filters. Selecting a scope calls back to ContentView so the
    // active query is rebuilt using the same debounced task pipeline as normal typing.
    private func scopeButton(_ item: GlobalSearchScope) -> some View {
        let isSelected = scope == item

        return Button {
            scope = item
            onScopeSelected(item)
            DispatchQueue.main.async {
                searchFocused = true
            }
        } label: {
            Label(scopeTitle(item), systemImage: item.systemImage)
                .font(.caption.weight(isSelected ? .semibold : .medium))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.12) : ChumenStyle.controlFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.28) : ChumenStyle.border.opacity(0.55))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(scopeTitle(item))
    }

    // Titles live here because they are presentation labels. GlobalSearchEngine works with captured
    // labels only and should not know about AppModel localization.
    private func scopeTitle(_ item: GlobalSearchScope) -> String {
        switch item {
        case .all: model.t(.all)
        case .settings: model.t(.appSettings)
        case .core: model.t(.coreSettings)
        case .dashboard: model.t(.dashboard)
        case .profiles: model.t(.profiles)
        case .proxies: model.t(.proxies)
        case .providers: model.t(.providers)
        case .rules: model.t(.rules)
        case .connections: model.t(.connections)
        case .logs: model.t(.logs)
        }
    }

    // Rows are intentionally generic: every result, whether setting, profile, node, rule, or log,
    // navigates through the same callback and does not mutate app state directly.
    private func resultRow(_ result: GlobalSearchResult) -> some View {
        Button {
            onSelectResult(result)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: result.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(result.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(result.subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ChumenStyle.mutedText)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(scopeTitle(result.scope))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ChumenStyle.mutedText)
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(ChumenStyle.controlFill)
                            )
                    }

                    if !result.detail.isEmpty {
                        Text(result.detail)
                            .font(.caption)
                            .foregroundStyle(ChumenStyle.mutedText)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
