import ChumenCore
import SwiftUI
import UniformTypeIdentifiers

struct CoreToolsView: View {
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

                toolGroup(title: "Geo") {
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
private enum CoreSettingsSectionID: String, CaseIterable, Identifiable {
    case runtime
    case ports
    case networkOptions
    case tunMode
    case advancedTun
    case dns
    case advancedDNS
    case externalUI
    case configAppendix

    var id: String { rawValue }

    var titleKey: L10n.Key {
        switch self {
        case .runtime: .runtime
        case .ports: .ports
        case .networkOptions: .networkOptions
        case .tunMode: .tunMode
        case .advancedTun: .advancedTun
        case .dns: .dns
        case .advancedDNS: .advancedDNS
        case .externalUI: .externalUI
        case .configAppendix: .configAppendix
        }
    }

    var systemImage: String {
        switch self {
        case .runtime: "terminal"
        case .ports: "point.3.connected.trianglepath.dotted"
        case .networkOptions: "network"
        case .tunMode: "shield.lefthalf.filled"
        case .advancedTun: "slider.horizontal.3"
        case .dns: "server.rack"
        case .advancedDNS: "gearshape.2"
        case .externalUI: "rectangle.connected.to.line.below"
        case .configAppendix: "doc.text"
        }
    }
}

struct CoreSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var choosingCore: Bool
    @State private var selectedSettingsSection: CoreSettingsSectionID = .runtime
    @State private var choosingExternalDashboard = false

    var body: some View {
        ScrollViewReader { proxy in
            HStack(alignment: .top, spacing: 14) {
                settingsQuickBar(proxy: proxy)
                    .padding(.leading, 24)
                    .padding(.top, 18)

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

                        TextField(model.t(.coreProcessName), text: $model.settings.coreProcessName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                model.settings.coreProcessName = ChumenRuntimeSettings.sanitizedCoreProcessName(
                                    model.settings.coreProcessName
                                )
                            }
                        HStack {
                            Label(model.t(.coreProcessExecutableName), systemImage: "door.left.hand.open")
                            Spacer()
                            Text(model.settings.managedCoreExecutableName)
                                .font(.caption.monospaced())
                                .foregroundStyle(ChumenStyle.mutedText)
                                .textSelection(.enabled)
                        }
                        Text(model.t(.coreProcessNameHint))
                            .font(.caption)
                            .foregroundStyle(ChumenStyle.mutedText)

                        TextField(model.t(.secret), text: $model.settings.secret)
                            .textFieldStyle(.roundedBorder)
                        Toggle(model.t(.autoStartCoreOnLaunch), isOn: $model.settings.autoStartCoreOnLaunch)
                        settingsActionButton(title: model.t(.applySettingsToCore), systemImage: "arrow.clockwise.circle") {
                            model.reloadRuntimeConfigViaAPI()
                        }
                    }
                    .id(CoreSettingsSectionID.runtime)

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
            .id(CoreSettingsSectionID.ports)

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
            .id(CoreSettingsSectionID.networkOptions)

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
            .id(CoreSettingsSectionID.tunMode)

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
            .id(CoreSettingsSectionID.advancedTun)

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
            .id(CoreSettingsSectionID.dns)

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
            .id(CoreSettingsSectionID.advancedDNS)

            Section(model.t(.externalUI)) {
                HStack(spacing: 8) {
                    settingsActionButton(title: model.t(.importDashboard), systemImage: "folder.badge.plus") {
                        choosingExternalDashboard = true
                    }
                    settingsActionButton(title: model.t(.openDashboard), systemImage: "safari") {
                        model.openDashboardURL()
                    }
                    .disabled(model.settings.externalUI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    settingsActionButton(title: model.t(.clearDashboard), systemImage: "xmark.circle") {
                        model.clearExternalDashboard()
                    }
                    .disabled(model.settings.externalUI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                pathRow(
                    title: model.t(.externalUIPath),
                    value: $model.settings.externalUI,
                    systemImage: "folder",
                    chooseAction: { choosingExternalDashboard = true }
                )
                TextField(model.t(.externalUIName), text: $model.settings.externalUIName)
                    .textFieldStyle(.roundedBorder)
                TextField(model.t(.externalUIURL), text: $model.settings.externalUIURL)
                    .textFieldStyle(.roundedBorder)
                Toggle("CORS allow-private-network", isOn: $model.settings.externalControllerCORSAllowPrivateNetwork)
                labeledEditor(model.t(.corsOrigins), text: corsOriginsText)
            }
            .id(CoreSettingsSectionID.externalUI)

            Section(model.t(.configAppendix)) {
                TextEditor(text: $model.settings.configAppendixYAML)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 100)
            }
            .id(CoreSettingsSectionID.configAppendix)

                }
                .formStyle(.grouped)
                .onChange(of: model.settings) {
                    model.scheduleSettingsAutosave()
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .fileImporter(
            isPresented: $choosingExternalDashboard,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.importExternalDashboard(url)
            }
        }
    }

    private func settingsQuickBar(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t(.quickSettings))
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)

            ForEach(CoreSettingsSectionID.allCases) { section in
                settingsQuickBarButton(section, proxy: proxy)
            }
        }
        .padding(8)
        .frame(width: 138, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }

    private func settingsQuickBarButton(_ section: CoreSettingsSectionID, proxy: ScrollViewProxy) -> some View {
        Button {
            selectedSettingsSection = section
            withAnimation(.easeInOut(duration: 0.18)) {
                proxy.scrollTo(section, anchor: .top)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 15)
                Text(model.t(section.titleKey))
                    .font(.system(size: 12.5, weight: selectedSettingsSection == section ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(selectedSettingsSection == section ? Color.accentColor : Color.primary)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selectedSettingsSection == section ? Color.accentColor.opacity(0.13) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(model.t(section.titleKey))
    }

    private func settingsActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(ChumenStyle.controlFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .strokeBorder(ChumenStyle.border.opacity(0.65))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
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
