import ChumenCore
import SwiftUI
import UniformTypeIdentifiers

private enum ChumenStyle {
    static let radius: CGFloat = 8
    static let accent = Color(red: 0.02, green: 0.48, blue: 0.38)
    static let pageBackground = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .textBackgroundColor)
    static let groupedSurface = Color(nsColor: .controlBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.30)
    static let mutedText = Color(nsColor: .secondaryLabelColor)
    static let softShadow = Color.black.opacity(0.025)
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var choosingCore = false
    @State private var choosingProfile = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            TabView {
                DashboardView()
                    .tabItem { Label(model.t(.dashboard), systemImage: "gauge.with.dots.needle.50percent") }
                ProfilesView(choosingProfile: $choosingProfile)
                    .tabItem { Label(model.t(.profiles), systemImage: "doc.text") }
                ProxiesView()
                    .tabItem { Label(model.t(.proxies), systemImage: "point.3.connected.trianglepath.dotted") }
                ProvidersView()
                    .tabItem { Label(model.t(.providers), systemImage: "tray.full") }
                ConnectionsView()
                    .tabItem { Label(model.t(.connections), systemImage: "link") }
                RulesView()
                    .tabItem { Label(model.t(.rules), systemImage: "list.bullet.rectangle") }
                LogsView()
                    .tabItem { Label(model.t(.logs), systemImage: "text.alignleft") }
                CoreToolsView()
                    .tabItem { Label(model.t(.coreTools), systemImage: "terminal") }
                SettingsView(choosingCore: $choosingCore)
                    .tabItem { Label(model.t(.settings), systemImage: "gearshape") }
            }
            .padding(.top, 8)
        }
        .background(ChumenStyle.pageBackground)
        .fileImporter(isPresented: $choosingCore, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.chooseCore(url)
            }
        }
        .fileImporter(isPresented: $choosingProfile, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.importLocalProfile(url)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(ChumenStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                            .fill((model.isRunning ? Color.green : ChumenStyle.accent).opacity(0.06))
                    )
                Image(systemName: model.isRunning ? "bolt.horizontal.fill" : "bolt.horizontal")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(model.isRunning ? .green : ChumenStyle.accent)
            }
            .frame(width: 48, height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .strokeBorder(ChumenStyle.border)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Chumen")
                    .font(.system(size: 25, weight: .semibold))
                HStack(spacing: 8) {
                    runtimeBadge
                    Text(model.activeProfile?.name ?? "-")
                        .font(.callout)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 20)

            HStack(spacing: 22) {
                headerStat(
                    title: "API",
                    value: model.apiText,
                    icon: "globe",
                    accent: model.apiText == model.t(.apiNotTested) ? ChumenStyle.mutedText : .blue
                )
                headerStat(
                    title: model.t(.systemProxy),
                    value: model.systemProxyStateText,
                    icon: model.systemProxyEnabled ? "checkmark.shield" : "shield",
                    accent: model.systemProxyEnabled ? .green : ChumenStyle.mutedText
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 15)
        .background(ChumenStyle.pageBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ChumenStyle.border)
                .frame(height: 1)
        }
    }

    private var runtimeBadge: some View {
        Label(model.isRunning ? model.t(.running) : model.t(.stopped), systemImage: model.isRunning ? "checkmark.circle.fill" : "pause.circle.fill")
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(model.isRunning ? .green : ChumenStyle.mutedText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(ChumenStyle.groupedSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .strokeBorder((model.isRunning ? Color.green.opacity(0.35) : ChumenStyle.border))
            )
    }

    private func headerStat(title: String, value: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: 360, alignment: .trailing)
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                commandPanel
                metricsGrid
            }
            .padding(20)
            .frame(maxWidth: 1280, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ChumenStyle.pageBackground)
    }

    private var commandPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                            .fill(commandAccent.opacity(0.10))
                        Image(systemName: commandIcon)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(commandAccent)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(commandTitle)
                                .font(.headline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            Text(commandBadge)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(commandAccent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(commandAccent.opacity(0.10))
                                )
                        }

                        Text(commandSubtitle)
                            .font(.caption)
                            .foregroundStyle(ChumenStyle.mutedText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(minWidth: 300, maxWidth: 580, alignment: .leading)

                Spacer(minLength: 16)

                HStack(spacing: 8) {
                    Text(model.t(.mode))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(ChumenStyle.mutedText)
                    modePicker
                        .frame(width: 270)
                }
            }

            Divider()

            HStack(spacing: 8) {
                    Button {
                        model.start()
                    } label: {
                        Label(model.t(.start), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .labelStyle(.titleAndIcon)
                    .help(model.t(.start))
                    .disabled(model.isRunning || model.isCoreTransitioning)

                    Button {
                        model.stop()
                    } label: {
                        Label(model.t(.stop), systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .labelStyle(.titleAndIcon)
                    .help(model.t(.stop))
                    .disabled(!model.isRunning || model.isCoreTransitioning)

                    Button {
                        model.restart()
                    } label: {
                        Label(model.t(.restart), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .labelStyle(.titleAndIcon)
                    .help(model.t(.restart))
                    .disabled(model.isCoreTransitioning)

                    Button {
                        Task { await model.refreshAll() }
                    } label: {
                        Label(model.t(.refresh), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .labelStyle(.titleAndIcon)
                    .help(model.t(.refresh))

                    Button {
                        model.toggleSystemProxy()
                    } label: {
                        Label(model.systemProxyEnabled ? model.t(.disableProxy) : model.t(.enableProxy), systemImage: "network")
                    }
                    .buttonStyle(.bordered)
                    .labelStyle(.titleAndIcon)
                    .help(model.systemProxyEnabled ? model.t(.disableProxy) : model.t(.enableProxy))

                    Button {
                        model.setTunEnabled(!model.settings.enableTun)
                    } label: {
                        Label(model.settings.enableTun ? model.t(.disableTun) : model.t(.enableTun), systemImage: "shield.lefthalf.filled")
                    }
                    .buttonStyle(.bordered)
                    .labelStyle(.titleAndIcon)
                    .help(tunHelpText)
                    .tint(tunAccent)
                    .disabled(model.isCoreTransitioning)

                Spacer(minLength: 0)
            }
            .controlSize(.large)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .shadow(color: ChumenStyle.softShadow, radius: 6, x: 0, y: 2)
    }

    private var commandTitle: String {
        if !model.isRunning {
            return model.t(.coreNotRunning)
        }
        if isAPIUnavailable {
            return model.t(.apiUnavailable)
        }
        if isAPINotTested {
            return model.t(.running)
        }
        return model.t(.apiConnected)
    }

    private var commandSubtitle: String {
        if !model.isRunning {
            let failure = commandFailureText
            if !failure.isEmpty {
                return failure
            }
            return "\(model.t(.coreNotRunningHint)) \(model.t(.activeProfile)): \(model.activeProfile?.name ?? "-")"
        }
        if isAPIUnavailable {
            return "\(model.t(.apiUnavailableHint)) \(controllerAddress)"
        }
        if isAPINotTested {
            return model.t(.apiNotTestedHint)
        }

        let status = model.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !status.isEmpty else { return model.t(.apiConnectedHint) }
        let lowercased = status.lowercased()
        let suppressedStatuses = [
            model.t(.running),
            model.t(.stopped),
            model.t(.controllerUnavailable),
            model.t(.tunEnabled),
            model.t(.tunDisabled),
            L10n.text(.controllerUnavailable, language: .en)
        ]
        return suppressedStatuses.contains(status)
            || lowercased.contains("could not connect")
            || lowercased.contains("cannot connect")
            ? model.t(.apiConnectedHint)
            : status
    }

    private var commandFailureText: String {
        let status = model.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !status.isEmpty else { return "" }
        let suppressed = [
            model.t(.running),
            model.t(.stopped),
            model.t(.coreNotRunning),
            model.t(.controllerUnavailable),
            L10n.text(.controllerUnavailable, language: .en)
        ]
        if suppressed.contains(status) {
            return ""
        }
        return status
    }

    private var commandBadge: String {
        if !model.isRunning {
            return model.t(.actionStartCore)
        }
        if isAPIUnavailable {
            return model.t(.actionCheckAPI)
        }
        if isAPINotTested {
            return model.t(.pending)
        }
        return model.t(.ready)
    }

    private var commandIcon: String {
        if !model.isRunning {
            return "power"
        }
        if isAPIUnavailable {
            return "exclamationmark.triangle.fill"
        }
        if isAPINotTested {
            return "clock"
        }
        return "checkmark.circle.fill"
    }

    private var commandAccent: Color {
        if !model.isRunning {
            return ChumenStyle.mutedText
        }
        if isAPIUnavailable {
            return .orange
        }
        if isAPINotTested {
            return .blue
        }
        return .green
    }

    private var controllerAddress: String {
        "\(model.settings.externalControllerHost):\(model.settings.externalControllerPort)"
    }

    private var isAPINotTested: Bool {
        let status = normalizedAPIText
        return status.isEmpty
            || status == model.t(.apiNotTested)
            || status == L10n.text(.apiNotTested, language: .en)
    }

    private var isAPIUnavailable: Bool {
        let status = normalizedAPIText
        let lowercased = status.lowercased()
        return status == model.t(.controllerUnavailable)
            || status == L10n.text(.controllerUnavailable, language: .en)
            || lowercased.contains("could not connect")
            || lowercased.contains("cannot connect")
            || lowercased.contains("connection refused")
    }

    private var normalizedAPIText: String {
        model.apiText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var modePicker: some View {
        Picker(model.t(.mode), selection: Binding(
            get: { model.settings.mode },
            set: { model.applyMode($0) }
        )) {
            ForEach(ProxyMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 320), spacing: 12)], spacing: 12) {
            metric(
                model.t(.runtime),
                value: model.isRunning ? model.t(.running) : model.t(.stopped),
                icon: "bolt.horizontal",
                accent: model.isRunning ? .green : ChumenStyle.mutedText
            )
            metric(
                model.t(.activeProfile),
                value: model.activeProfile?.name ?? "-",
                icon: "doc.text",
                accent: .blue
            )
            metric(
                model.t(.mode),
                value: model.settings.mode.rawValue,
                icon: "arrow.triangle.branch",
                accent: .purple
            )
            metric(
                model.t(.cumulativeTraffic),
                value: model.dashboardTrafficText,
                icon: "arrow.up.arrow.down",
                accent: .teal
            )
            metric(
                model.t(.currentSpeed),
                value: model.speedText,
                icon: "speedometer",
                accent: .cyan
            )
            metric(
                model.t(.routedTraffic),
                value: model.routedTrafficText,
                icon: "point.3.connected.trianglepath.dotted",
                accent: .mint
            )
            metric(
                model.t(.memory),
                value: model.memoryText,
                icon: "memorychip",
                accent: .indigo
            )
            metric(
                model.t(.systemProxy),
                value: model.systemProxyEnabled ? model.t(.on) : model.t(.off),
                icon: model.systemProxyEnabled ? "checkmark.shield" : "shield",
                accent: model.systemProxyEnabled ? .green : ChumenStyle.mutedText
            )
            metric(
                model.t(.tunMode),
                value: tunStateText,
                icon: "shield.lefthalf.filled",
                accent: tunAccent
            )
            metric(
                model.t(.lastRefresh),
                value: model.lastRefreshText,
                icon: "clock",
                accent: .orange
            )
        }
    }

    private func metric(_ title: String, value: String, icon: String, accent: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ChumenStyle.groupedSurface)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                Text(value)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: 88, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .shadow(color: ChumenStyle.softShadow, radius: 5, x: 0, y: 1)
    }

    private var tunStateText: String {
        if !model.settings.enableTun {
            return model.t(.off)
        }
        if model.tunRuntimeFailed {
            return model.tunRuntimeFailureTitle
        }
        if model.isCoreTransitioning {
            return model.t(.pending)
        }
        return model.t(.on)
    }

    private var tunAccent: Color {
        if model.settings.enableTun && model.tunRuntimeFailed {
            return .orange
        }
        return model.settings.enableTun ? .green : ChumenStyle.mutedText
    }

    private var tunHelpText: String {
        if model.settings.enableTun && model.tunRuntimeFailed {
            let detail = model.tunRuntimeFailureDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? model.t(.tunFailed) : "\(model.t(.tunFailed)): \(detail)"
        }
        return model.settings.enableTun ? model.t(.disableTun) : model.t(.enableTun)
    }
}

private struct ProfilesView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var choosingProfile: Bool

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    choosingProfile = true
                } label: {
                    Label(model.t(.importLocal), systemImage: "square.and.arrow.down")
                }

                Divider()

                TextField(model.t(.subscriptionURL), text: $model.remoteProfileURL)
                    .textFieldStyle(.roundedBorder)
                TextField(model.t(.displayName), text: $model.remoteProfileName)
                    .textFieldStyle(.roundedBorder)
                Button {
                    model.importRemoteProfile()
                } label: {
                    Label(model.t(.importSubscription), systemImage: "arrow.down.doc")
                }

                Divider()

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.t(.importFromClients))
                            .font(.headline)
                        Text(model.t(.externalImportHint))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button {
                                model.scanExternalProfiles()
                            } label: {
                                Label(model.t(.scanClients), systemImage: "magnifyingglass")
                            }

                            Button {
                                model.importExternalProfiles()
                            } label: {
                                Label(model.t(.importAllFound), systemImage: "tray.and.arrow.down")
                            }
                            .disabled(model.externalProfileCandidates.isEmpty)
                        }

                        if model.externalProfileCandidates.isEmpty && model.externalProfileScanCompleted {
                            Text(model.t(.noExternalProfilesFound))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if !model.externalProfileCandidates.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(model.externalProfileCandidates) { candidate in
                                        HStack(alignment: .top, spacing: 8) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(candidate.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .lineLimit(1)
                                                Text(candidate.sourceName)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                if candidate.remoteURL != nil {
                                                    Label(model.t(.subscriptionURLFound), systemImage: "link.badge.plus")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Text(candidate.filePath)
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                                    .lineLimit(1)
                                            }
                                            Spacer(minLength: 8)
                                            Button(model.t(.importOne)) {
                                                model.importExternalProfile(candidate)
                                            }
                                            .controlSize(.small)
                                        }
                                        .padding(8)
                                        .background(ChumenStyle.groupedSurface.opacity(0.65))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                }
                            }
                            .frame(maxHeight: 210)
                        }
                    }
                }

                Spacer()
            }
            .padding(18)
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)

            List {
                ForEach(model.profileLibrary.profiles) { profile in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(profile.filePath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if let remoteURL = profile.remoteURL, !remoteURL.isEmpty {
                                    Label(remoteURL, systemImage: "link")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if profile.id == model.profileLibrary.activeProfileID {
                                Label(model.t(.active), systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }

                        HStack {
                            if profile.id == model.profileLibrary.activeProfileID {
                                Label(model.t(.currentActive), systemImage: "checkmark.circle.fill")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.green.opacity(0.10))
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(Color.green.opacity(0.28))
                                    )
                            } else {
                                Button(model.t(.activate)) {
                                    model.activateProfile(profile)
                                }
                            }

                            Button(model.t(.edit)) {
                                model.beginEditProfile(profile)
                            }

                            Button(model.t(.openFile)) {
                                model.openProfileFile(profile)
                            }

                            if profile.remoteURL != nil {
                                Button(model.t(.update)) {
                                    model.updateProfile(profile)
                                }
                            }

                            Button(model.t(.delete), role: .destructive) {
                                model.deleteProfile(profile)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .sheet(item: $model.editingProfile) { profile in
            ProfileEditorSheet(profile: profile)
                .environmentObject(model)
        }
    }
}

private struct ProfileEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    let profile: ProxyProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.name)
                        .font(.headline)
                    Text(profile.filePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(model.t(.cancel)) {
                    model.cancelProfileEditor()
                }
                Button(model.t(.save)) {
                    model.saveProfileEditor()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.profileEditorIsLoading)
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField(model.t(.displayName), text: $model.profileEditorName)
                    .textFieldStyle(.roundedBorder)
                TextField(model.t(.subscriptionURL), text: $model.profileEditorRemoteURL)
                    .textFieldStyle(.roundedBorder)
                Text(model.t(.subscriptionEditHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                YAMLTextView(text: $model.profileEditorText)
                    .frame(minWidth: 720, minHeight: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(model.profileEditorIsLoading ? 0.35 : 1)

                if model.profileEditorIsLoading {
                    ProgressView()
                        .controlSize(.large)
                        .padding(18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(18)
    }
}

private struct ProxiesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    Task { await model.refreshProxies() }
                } label: {
                    Label(model.t(.refreshProxies), systemImage: "arrow.triangle.2.circlepath")
                }
                Spacer()
                Text("\(model.proxyGroups.count) \(model.t(.groups))")
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(model.proxyGroups) { group in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.name)
                                .font(.headline)
                            Text(group.type)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker(model.t(.node), selection: Binding(
                            get: { group.selected },
                            set: { model.selectProxy(group: group, name: $0) }
                        )) {
                            ForEach(group.options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 320)
                        Button {
                            model.testDelay(name: group.selected)
                        } label: {
                            Label(delayTitle(for: group.selected), systemImage: "speedometer")
                        }
                        .disabled(group.selected.isEmpty)
                        Button {
                            model.testGroupDelay(group)
                        } label: {
                            Label(model.t(.groups), systemImage: "gauge.with.dots.needle.50percent")
                        }
                        Button {
                            model.clearProxySelection(group)
                        } label: {
                            Label(model.t(.clear), systemImage: "pin.slash")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(18)
        .task {
            if model.proxyGroups.isEmpty {
                await model.refreshProxies()
            }
        }
    }

    private func delayTitle(for name: String) -> String {
        guard let delay = model.proxyDelays[name] else {
            return model.t(.delayTest)
        }
        return "\(delay) ms"
    }
}

private struct ProvidersView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HSplitView {
            providerList(
                title: model.t(.proxyProviders),
                providers: model.proxyProviders,
                showHealthcheck: true,
                updateAction: model.updateProxyProvider,
                healthcheckAction: model.healthcheckProxyProvider
            )

            providerList(
                title: model.t(.ruleProviders),
                providers: model.ruleProviders,
                showHealthcheck: false,
                updateAction: model.updateRuleProvider,
                healthcheckAction: { _ in }
            )
        }
        .padding(18)
        .task {
            if model.proxyProviders.isEmpty && model.ruleProviders.isEmpty {
                await model.refreshProviders()
            }
        }
        .toolbar {
            Button {
                Task { await model.refreshProviders() }
            } label: {
                Label(model.t(.refreshProviders), systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }

    private func providerList(
        title: String,
        providers: [MihomoProvider],
        showHealthcheck: Bool,
        updateAction: @escaping (MihomoProvider) -> Void,
        healthcheckAction: @escaping (MihomoProvider) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(providers.count)")
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(providers) { provider in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(provider.name)
                                    .font(.headline)
                                Text([provider.type, provider.vehicleType, provider.behavior].compactMap { $0 }.joined(separator: " / "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(provider.proxies?.count ?? 0) \(model.t(.providerItems))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Button {
                                updateAction(provider)
                            } label: {
                                Label(model.t(.update), systemImage: "arrow.down.circle")
                            }

                            if showHealthcheck {
                                Button {
                                    healthcheckAction(provider)
                                } label: {
                                    Label(model.t(.delayTest), systemImage: "speedometer")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(minWidth: 360)
    }
}

private struct ConnectionsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    Task { await model.refreshConnections() }
                } label: {
                    Label(model.t(.refreshConnections), systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive) {
                    model.closeAllConnections()
                } label: {
                    Label(model.t(.closeAll), systemImage: "xmark.circle")
                }
                Spacer()
                Text("\(model.connections.count) \(model.t(.activeConnections)) / \(model.totalTrafficText)")
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(model.connections) { connection in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(connection.metadata?.host ?? connection.metadata?.destinationIP ?? connection.id)
                                .font(.headline)
                            Text(connection.chains?.joined(separator: " > ") ?? "-")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(connection.rulePayload ?? connection.rule ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("\(model.t(.upload)) \(AppModel.formatBytes(connection.upload ?? 0))")
                            Text("\(model.t(.download)) \(AppModel.formatBytes(connection.download ?? 0))")
                            Button(model.t(.close)) {
                                model.closeConnection(connection)
                            }
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .padding(18)
    }
}

private struct RulesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    Task { await model.refreshRules() }
                } label: {
                    Label(model.t(.refreshRules), systemImage: "arrow.triangle.2.circlepath")
                }
                Spacer()
                Text("\(model.rules.count) \(model.t(.rules))")
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(Array(model.rules.enumerated()), id: \.offset) { index, rule in
                    HStack {
                        Text(rule.type ?? "unknown")
                            .font(.caption.weight(.semibold))
                            .frame(width: 90, alignment: .leading)
                        Text(rule.payload ?? "")
                            .lineLimit(1)
                        Spacer()
                        Text(rule.proxy ?? "")
                            .foregroundStyle(.secondary)
                        Button(rule.disabled == true ? model.t(.activate) : model.t(.disableProxy)) {
                            model.setRuleDisabled(index: index, disabled: !(rule.disabled ?? false))
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(18)
    }
}

private struct LogsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(model.t(.logs), systemImage: "text.alignleft")
                    .font(.headline)
                Spacer()
                Button {
                    model.clearLogs()
                } label: {
                    Label(model.t(.clear), systemImage: "trash")
                }
            }

            HSplitView {
                logPane(title: model.t(.processLog), text: model.logs)
                logPane(title: model.t(.runtimeLog), text: model.runtimeLogs)
            }
        }
        .padding(18)
    }

    private func logPane(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                Text(text.isEmpty ? model.t(.noLogs) : text)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(minWidth: 320)
    }
}

private struct CoreToolsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                toolGroup(title: model.t(.runtime)) {
                    Button {
                        model.reloadRuntimeConfigViaAPI()
                    } label: {
                        Label(model.t(.reloadRuntimeConfig), systemImage: "arrow.clockwise.circle")
                    }
                    Button {
                        model.restartKernelViaAPI()
                    } label: {
                        Label(model.t(.restartKernelAPI), systemImage: "power")
                    }
                    Button {
                        model.openDashboardURL()
                    } label: {
                        Label(model.t(.openDashboard), systemImage: "safari")
                    }
                }

                toolGroup(title: model.t(.cache)) {
                    Button {
                        model.flushFakeIPCache()
                    } label: {
                        Label(model.t(.flushFakeIP), systemImage: "trash")
                    }
                    Button {
                        model.flushDNSCache()
                    } label: {
                        Label(model.t(.flushDNS), systemImage: "trash.circle")
                    }
                    Button {
                        model.debugGC()
                    } label: {
                        Label(model.t(.debugGC), systemImage: "memorychip")
                    }
                }

                toolGroup(title: "Geo / UI") {
                    Button {
                        model.updateConfigGeo()
                    } label: {
                        Label(model.t(.updateGeo), systemImage: "globe.asia.australia")
                    }
                    Button {
                        model.upgradeGeo()
                    } label: {
                        Label(model.t(.upgradeGeo), systemImage: "arrow.down.circle")
                    }
                    Button {
                        model.upgradeUI()
                    } label: {
                        Label(model.t(.upgradeUI), systemImage: "rectangle.connected.to.line.below")
                    }
                }

                panel(title: model.t(.dnsQuery)) {
                    HStack {
                        TextField("example.com", text: $model.dnsQueryName)
                            .textFieldStyle(.roundedBorder)
                        TextField("A", text: $model.dnsQueryType)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Button(model.t(.request)) {
                            model.queryDNS()
                        }
                    }
                }

                panel(title: model.t(.storage)) {
                    TextField(model.t(.key), text: $model.storageKey)
                        .textFieldStyle(.roundedBorder)
                    TextEditor(text: $model.storageValue)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 90)
                    HStack {
                        Button(model.t(.read)) { model.getStorageValue() }
                        Button(model.t(.write)) { model.putStorageValue() }
                        Button(role: .destructive) { model.deleteStorageValue() } label: { Text(model.t(.delete)) }
                    }
                }

                panel(title: model.t(.rawAPI)) {
                    HStack {
                        Picker("", selection: $model.rawAPIMethod) {
                            ForEach(["GET", "POST", "PUT", "PATCH", "DELETE"], id: \.self) { method in
                                Text(method).tag(method)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 110)
                        TextField("/version", text: $model.rawAPIPath)
                            .textFieldStyle(.roundedBorder)
                        Button(model.t(.request)) {
                            model.callRawAPI()
                        }
                    }
                    Text(model.t(.body))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ChumenStyle.mutedText)
                    TextEditor(text: $model.rawAPIBody)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 90)
                }

                panel(title: model.t(.response)) {
                    ScrollView {
                        Text(model.coreToolResult.isEmpty ? "-" : model.coreToolResult)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(10)
                    }
                    .frame(minHeight: 160)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: ChumenStyle.radius))
                }
            }
            .padding(18)
            .frame(maxWidth: 980, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func toolGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        panel(title: title) {
            HStack(spacing: 8) {
                content()
                Spacer(minLength: 0)
            }
            .controlSize(.large)
        }
    }

    private func panel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var choosingCore: Bool

    var body: some View {
        Form {
            Section(model.t(.runtime)) {
                pathRow(
                    title: model.t(.executable),
                    value: $model.settings.corePath,
                    systemImage: "terminal",
                    chooseAction: { choosingCore = true }
                )
                Button {
                    model.useDetectedCore()
                } label: {
                    Label(model.t(.useDetectedCore), systemImage: "magnifyingglass")
                }

                TextField(model.t(.secret), text: $model.settings.secret)
                    .textFieldStyle(.roundedBorder)
                Toggle(model.t(.autoStartCoreOnLaunch), isOn: $model.settings.autoStartCoreOnLaunch)
            }

            Section(model.t(.statusBar)) {
                Toggle(model.t(.showStatusBarItem), isOn: Binding(
                    get: { model.settings.showStatusBarItem },
                    set: { model.setStatusBarItemVisible($0) }
                ))

                Picker(model.t(.statusBarDisplayMode), selection: Binding(
                    get: { model.settings.statusBarDisplayMode },
                    set: { model.setStatusBarDisplayMode($0) }
                )) {
                    ForEach(StatusBarDisplayMode.allCases) { mode in
                        Text(model.statusBarDisplayModeTitle(mode)).tag(mode)
                    }
                }
                .disabled(!model.settings.showStatusBarItem)

                if model.settings.statusBarDisplayMode == .custom {
                    TextField(model.t(.statusBarCustomTemplate), text: Binding(
                        get: { model.settings.statusBarCustomTemplate },
                        set: { model.setStatusBarCustomTemplate($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .help("{app} {state} {mode} {profile} {up} {down} {totalUp} {totalDown}")

                    HStack {
                        Text(model.t(.statusBarTemplatePreview))
                            .foregroundStyle(ChumenStyle.mutedText)
                        Text(model.statusBarTemplatePreview)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption)
                }
            }

            Section(model.t(.ports)) {
                Stepper(value: $model.settings.mixedPort, in: 1...65535) {
                    Label("Mixed \(model.settings.mixedPort)", systemImage: "point.3.connected.trianglepath.dotted")
                }
                Toggle("SOCKS", isOn: $model.settings.socksEnabled)
                Stepper(value: $model.settings.socksPort, in: 1...65535) {
                    Label("SOCKS \(model.settings.socksPort)", systemImage: "s.circle")
                }
                .disabled(!model.settings.socksEnabled)
                Toggle("HTTP", isOn: $model.settings.httpEnabled)
                Stepper(value: $model.settings.httpPort, in: 1...65535) {
                    Label("HTTP \(model.settings.httpPort)", systemImage: "h.circle")
                }
                .disabled(!model.settings.httpEnabled)
                Toggle("Redir", isOn: $model.settings.redirEnabled)
                Stepper(value: $model.settings.redirPort, in: 1...65535) {
                    Label("Redir \(model.settings.redirPort)", systemImage: "r.circle")
                }
                .disabled(!model.settings.redirEnabled)
                Toggle("TProxy", isOn: $model.settings.tproxyEnabled)
                Stepper(value: $model.settings.tproxyPort, in: 1...65535) {
                    Label("TProxy \(model.settings.tproxyPort)", systemImage: "t.circle")
                }
                .disabled(!model.settings.tproxyEnabled)
                Stepper(value: $model.settings.externalControllerPort, in: 1...65535) {
                    Label("Controller \(model.settings.externalControllerPort)", systemImage: "slider.horizontal.3")
                }
                TextField(model.t(.controllerHost), text: $model.settings.externalControllerHost)
                    .textFieldStyle(.roundedBorder)
            }

            Section(model.t(.networkOptions)) {
                Toggle(model.t(.allowLAN), isOn: $model.settings.allowLAN)
                Toggle(model.t(.ipv6), isOn: $model.settings.ipv6)
                Toggle(model.t(.unifiedDelay), isOn: $model.settings.unifiedDelay)
                Picker(model.t(.logLevel), selection: $model.settings.logLevel) {
                    ForEach(CoreLogLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }

            Section(model.t(.tunMode)) {
                Toggle(model.t(.enableTun), isOn: Binding(
                    get: { model.settings.enableTun },
                    set: { model.setTunEnabled($0) }
                ))
                .disabled(model.isCoreTransitioning)
                Picker(model.t(.tunStack), selection: Binding(
                    get: { model.settings.tunStack },
                    set: { model.setTunStack($0) }
                )) {
                    ForEach(TunStack.allCases) { stack in
                        Text(stack.rawValue).tag(stack)
                    }
                }
                .disabled(model.isCoreTransitioning)
                .pickerStyle(.segmented)
            }

            Section(model.t(.advancedTun)) {
                TextField("Device", text: $model.settings.tunDevice)
                    .textFieldStyle(.roundedBorder)
                Toggle("Auto Route", isOn: $model.settings.tunAutoRoute)
                Toggle("Strict Route", isOn: $model.settings.tunStrictRoute)
                Toggle("Auto Detect Interface", isOn: $model.settings.tunAutoDetectInterface)
                Stepper(value: $model.settings.tunMTU, in: 576...9000) {
                    Label("MTU \(model.settings.tunMTU)", systemImage: "arrow.left.and.right")
                }
                Text("DNS Hijack")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                TextEditor(text: tunDNSHijackText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 58)
                Text("Route Exclude Address")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                TextEditor(text: tunRouteExcludeText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 58)
            }

            Section(model.t(.dns)) {
                Toggle(model.t(.enableDNS), isOn: $model.settings.enableDNS)
                TextField(model.t(.dnsListen), text: $model.settings.dnsListen)
                    .textFieldStyle(.roundedBorder)
                Picker(model.t(.dnsMode), selection: $model.settings.dnsMode) {
                    ForEach(DNSMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                TextEditor(text: nameserverText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 70)
                    .accessibilityLabel(model.t(.nameservers))
            }

            Section(model.t(.advancedDNS)) {
                Toggle("DNS IPv6", isOn: $model.settings.dnsIPv6)
                Toggle("Prefer HTTP/3", isOn: $model.settings.dnsPreferH3)
                Toggle("Respect Rules", isOn: $model.settings.dnsRespectRules)
                Toggle("Use Hosts", isOn: $model.settings.dnsUseHosts)
                Toggle("Use System Hosts", isOn: $model.settings.dnsUseSystemHosts)
                TextField("Fake-IP Range", text: $model.settings.dnsFakeIPRange)
                    .textFieldStyle(.roundedBorder)
                TextField("Fake-IP Range IPv6", text: $model.settings.dnsFakeIPRange6)
                    .textFieldStyle(.roundedBorder)
                Picker("Fake-IP Filter Mode", selection: $model.settings.dnsFakeIPFilterMode) {
                    ForEach(DNSFakeIPFilterMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                labeledEditor("Default Nameserver", text: defaultNameserverText)
                labeledEditor("Fallback", text: fallbackNameserverText)
                labeledEditor("Proxy Server Nameserver", text: proxyServerNameserverText)
                labeledEditor("Direct Nameserver", text: directNameserverText)
                labeledEditor("Fake-IP Filter", text: fakeIPFilterText)
                labeledEditor("Fallback IP CIDR", text: fallbackIPCIDRText)
                labeledEditor("Fallback Domain", text: fallbackDomainText)
                Toggle("Fallback GeoIP", isOn: $model.settings.fallbackFilterGeoIP)
                TextField("GeoIP Code", text: $model.settings.fallbackFilterGeoIPCode)
                    .textFieldStyle(.roundedBorder)
                labeledEditor("Nameserver Policy YAML", text: $model.settings.nameserverPolicyYAML)
                labeledEditor("Hosts YAML", text: $model.settings.hostsYAML)
            }

            Section(model.t(.externalUI)) {
                TextField("external-ui", text: $model.settings.externalUI)
                    .textFieldStyle(.roundedBorder)
                TextField("external-ui-name", text: $model.settings.externalUIName)
                    .textFieldStyle(.roundedBorder)
                TextField("external-ui-url", text: $model.settings.externalUIURL)
                    .textFieldStyle(.roundedBorder)
                Toggle("CORS allow-private-network", isOn: $model.settings.externalControllerCORSAllowPrivateNetwork)
                labeledEditor(model.t(.corsOrigins), text: corsOriginsText)
            }

            Section(model.t(.configAppendix)) {
                TextEditor(text: $model.settings.configAppendixYAML)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 100)
            }

            Section(model.t(.language)) {
                Picker(model.t(.language), selection: Binding(
                    get: { model.settings.language ?? .system },
                    set: { model.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(model.languageTitle(language)).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(model.t(.systemProxy)) {
                TextField(model.t(.systemProxyHost), text: $model.settings.systemProxyHost)
                    .textFieldStyle(.roundedBorder)
                Toggle(model.t(.setProxyOnStart), isOn: $model.settings.setSystemProxyOnStart)
                Toggle(model.t(.clearProxyOnStop), isOn: $model.settings.clearSystemProxyOnStop)
                HStack {
                    Text(model.systemProxyStateText)
                    Spacer()
                    Button(model.t(.refresh)) {
                        model.refreshSystemProxyState()
                    }
                }
            }

            Section(model.t(.files)) {
                Text(model.paths.appHome.path)
                    .font(.caption)
                    .textSelection(.enabled)
                Button {
                    model.openDataDirectory()
                } label: {
                    Label(model.t(.openDataDirectory), systemImage: "folder")
                }
            }

            Section {
                Button {
                    model.saveSettings()
                } label: {
                    Label(model.t(.saveSettings), systemImage: "square.and.arrow.down")
                }
                Button {
                    model.reloadRuntimeConfigViaAPI()
                } label: {
                    Label(model.t(.reloadRuntimeConfig), systemImage: "arrow.clockwise.circle")
                }
                Button {
                    model.openDashboardURL()
                } label: {
                    Label(model.t(.openDashboard), systemImage: "safari")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }

    private func pathRow(
        title: String,
        value: Binding<String>,
        systemImage: String,
        chooseAction: @escaping () -> Void
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .frame(width: 110, alignment: .leading)
            TextField(title, text: value)
                .textFieldStyle(.roundedBorder)
            Button(action: chooseAction) {
                Image(systemName: "folder")
            }
            .help(title)
        }
    }

    private var nameserverText: Binding<String> {
        listText(\.nameservers)
    }

    private var defaultNameserverText: Binding<String> { listText(\.defaultNameservers) }
    private var fallbackNameserverText: Binding<String> { listText(\.fallbackNameservers) }
    private var proxyServerNameserverText: Binding<String> { listText(\.proxyServerNameservers) }
    private var directNameserverText: Binding<String> { listText(\.directNameservers) }
    private var fakeIPFilterText: Binding<String> { listText(\.fakeIPFilters) }
    private var fallbackIPCIDRText: Binding<String> { listText(\.fallbackFilterIPCIDRs) }
    private var fallbackDomainText: Binding<String> { listText(\.fallbackFilterDomains) }
    private var tunDNSHijackText: Binding<String> { listText(\.tunDNSHijack) }
    private var tunRouteExcludeText: Binding<String> { listText(\.tunRouteExcludeAddress) }
    private var corsOriginsText: Binding<String> { listText(\.externalControllerCORSAllowOrigins) }

    private func listText(_ keyPath: WritableKeyPath<ChumenRuntimeSettings, [String]>) -> Binding<String> {
        Binding(
            get: { model.settings[keyPath: keyPath].joined(separator: "\n") },
            set: { value in
                model.settings[keyPath: keyPath] = value
                    .components(separatedBy: .newlines)
                    .flatMap { $0.components(separatedBy: ",") }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    @ViewBuilder
    private func labeledEditor(_ title: String, text: Binding<String>) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(ChumenStyle.mutedText)
        TextEditor(text: text)
            .font(.system(.caption, design: .monospaced))
            .frame(minHeight: 62)
    }
}
