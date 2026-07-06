import ChumenCore
import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var choosingProfile: Bool
    @State private var profileSearchText = ""
    @State private var showingExternalImportSheet = false
    @State private var pendingDeleteProfile: ProxyProfile?
    @State private var showingDeleteConfirmation = false

    // The Profiles page is a high-frequency maintenance surface: users scan the current config,
    // make one targeted change, then leave. Keep imports in the left rail and make each profile row
    // read like a compact settings row, not a dashboard card with every action competing at once.
    private enum Layout {
        static let sidebarWidth: CGFloat = 320
        static let pagePadding: CGFloat = 18
        static let rowHorizontalPadding: CGFloat = 16
        static let rowVerticalPadding: CGFloat = 14
        static let actionWidth: CGFloat = 94
        static let compactActionWidth: CGFloat = 76
        static let actionHeight: CGFloat = 32
        static let primaryActionWidth: CGFloat = 108
    }

    // Profile actions follow the dashboard command model: the primary command is filled, while
    // secondary commands keep a tinted low-contrast fill so a long action row stays scannable.
    // Core profile work stays visible and grouped by frequency: daily edits/update on the first row,
    // lower-frequency maintenance on the second row. Do not hide these behind an overflow menu.
    private enum ProfileActionTone {
        case primary
        case neutral
        case blue
        case orange
        case teal
        case violet
        case red
        var tint: Color {
            switch self {
            case .primary, .blue:
                return .blue
            case .orange:
                return .orange
            case .teal:
                return .teal
            case .violet:
                return .purple
            case .red:
                return .red
            case .neutral:
                return ChumenStyle.mutedText
            }
        }

        var foreground: Color {
            switch self {
            case .primary:
                return .white
            case .neutral:
                return .primary
            default:
                return tint
            }
        }

        var background: Color {
            switch self {
            case .primary:
                return tint
            case .neutral:
                return ChumenStyle.controlFill
            default:
                return tint.opacity(0.10)
            }
        }

        var border: Color {
            switch self {
            case .primary:
                return tint.opacity(0.22)
            case .neutral:
                return ChumenStyle.border.opacity(0.55)
            default:
                return tint.opacity(0.18)
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            profileImportSidebar
                .frame(width: Layout.sidebarWidth)

            Divider()

            profileListPane
        }
        .background(ChumenStyle.pageBackground)
        .sheet(item: $model.editingProfile) { profile in
            ProfileEditorSheet(profile: profile)
                .environmentObject(model)
        }
        .sheet(item: $model.editingProfileSection) { editor in
            ProfileSectionEditorSheet(editor: editor)
                .environmentObject(model)
        }
        .sheet(item: $model.editingProfileAppendix) { target in
            ProfileAppendixEditorSheet(target: target)
                .environmentObject(model)
        }
        .sheet(isPresented: $showingExternalImportSheet) {
            ExternalProfileImportSheet()
                .environmentObject(model)
        }
        .alert(
            model.t(.deleteProfileConfirmTitle),
            isPresented: $showingDeleteConfirmation,
            presenting: pendingDeleteProfile
        ) { profile in
            Button(model.t(.delete), role: .destructive) {
                model.deleteProfile(profile)
                pendingDeleteProfile = nil
            }
            Button(model.t(.cancel), role: .cancel) {
                pendingDeleteProfile = nil
            }
        } message: { profile in
            Text(String(format: model.t(.deleteProfileConfirmMessage), profile.name))
        }
    }

    private var profileImportSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    model.createBlankProfileForEditing()
                } label: {
                    Label(model.t(.createProfile), systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                profileSidebarSection(title: model.t(.importLocal), systemImage: "square.and.arrow.down") {
                    Button {
                        choosingProfile = true
                    } label: {
                        Label(model.t(.importLocal), systemImage: "plus.document")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                profileSidebarSection(title: model.t(.importSubscription), systemImage: "link.badge.plus") {
                    TextField(model.t(.subscriptionURL), text: $model.remoteProfileURL)
                        .textFieldStyle(.roundedBorder)
                    TextField(model.t(.displayName), text: $model.remoteProfileName)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        model.importRemoteProfile()
                    } label: {
                        Label(model.t(.importSubscription), systemImage: "arrow.down.doc")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                profileSidebarSection(title: model.t(.importFromClients), systemImage: "tray.and.arrow.down") {
                    Text(model.t(.externalImportHint))
                        .font(.callout)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        model.scanExternalProfiles()
                        showingExternalImportSheet = true
                    } label: {
                        Label(model.t(.scanClients), systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }

                    if model.externalProfileScanCompleted {
                        Button {
                            showingExternalImportSheet = true
                        } label: {
                            Label(externalProfileResultSummary, systemImage: "list.bullet.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                profileSidebarSection(title: model.t(.globalExtendOverrideConfig), systemImage: "doc.badge.gearshape") {
                    Button {
                        model.beginEditGlobalProfileAppendix()
                    } label: {
                        Label(model.t(.globalExtendOverrideConfig), systemImage: "doc.badge.gearshape")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(Layout.pagePadding)
        }
        .background(ChumenStyle.pageBackground)
    }

    @ViewBuilder
    private func profileSidebarSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }

    private var profileListPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.t(.profileLibrary))
                        .font(.title3.weight(.semibold))
                    Text("\(filteredProfiles.count) / \(model.profileLibrary.profiles.count)")
                        .font(.callout)
                        .foregroundStyle(ChumenStyle.mutedText)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ChumenStyle.mutedText)
                    TextField(model.t(.profileSearchPlaceholder), text: $profileSearchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(width: 320, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(ChumenStyle.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .strokeBorder(ChumenStyle.border)
                )
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    if filteredProfiles.isEmpty {
                        emptyProfilesState
                    } else {
                        ForEach(filteredProfiles) { profile in
                            profileRow(profile)
                            if profile.id != filteredProfiles.last?.id {
                                Divider()
                                    .padding(.leading, 58)
                            }
                        }
                    }
                }
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
        .padding(Layout.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ChumenStyle.pageBackground)
    }

    private var filteredProfiles: [ProxyProfile] {
        let query = profileSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.profileLibrary.profiles }
        return model.profileLibrary.profiles.filter { profile in
            [profile.name, profile.filePath, profile.remoteURL ?? "", profile.sourceClient ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var externalProfileResultSummary: String {
        if model.externalProfileCandidates.isEmpty {
            return model.t(.noExternalProfilesFound)
        }
        return "\(model.t(.externalProfilesFound)) \(model.externalProfileCandidates.count)"
    }

    private var emptyProfilesState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(ChumenStyle.mutedText)
            Text(profileSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? model.t(.noProfiles) : model.t(.noMatchingProfiles))
                .font(.headline)
            Button {
                model.createBlankProfileForEditing()
            } label: {
                Label(model.t(.createProfile), systemImage: "doc.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .foregroundStyle(ChumenStyle.mutedText)
    }

    private func profileRow(_ profile: ProxyProfile) -> some View {
        HStack(alignment: .top, spacing: 12) {
            profileStatusIcon(profile)

            // Keep the profile row as one readable content column: title, metadata, and commands
            // share the same left edge. The status icon is only an anchor, not the start of actions.
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(profile.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if profile.id == model.profileLibrary.activeProfileID {
                        activeStatusPill
                    }

                    Spacer(minLength: 12)

                    if profile.id != model.profileLibrary.activeProfileID {
                        profileActivationControl(profile)
                    }
                }

                profileMetadata(profile)
                profileActionBar(profile)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Layout.rowHorizontalPadding)
        .padding(.vertical, Layout.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            profileActionMenu(profile)
        }
    }

    private func profileStatusIcon(_ profile: ProxyProfile) -> some View {
        Image(systemName: profile.id == model.profileLibrary.activeProfileID ? "checkmark.circle.fill" : "doc.text")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(profile.id == model.profileLibrary.activeProfileID ? Color.green : ChumenStyle.mutedText)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill((profile.id == model.profileLibrary.activeProfileID ? Color.green : ChumenStyle.mutedText).opacity(0.10))
            )
    }

    private var activeStatusPill: some View {
        Label(model.t(.currentActive), systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.green.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.green.opacity(0.28))
            )
    }

    private func profileMetadata(_ profile: ProxyProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            metadataLine(systemImage: "folder", text: profile.filePath, color: ChumenStyle.mutedText)

            if let sourceClient = profile.sourceClient, !sourceClient.isEmpty {
                metadataLine(
                    systemImage: "tray.and.arrow.down",
                    text: "\(model.t(.importedFromClient)) \(sourceClient)",
                    color: ChumenStyle.mutedText
                )
            }

            if let remoteURL = profile.remoteURL, !remoteURL.isEmpty {
                metadataLine(systemImage: "link", text: remoteURL, color: Color(nsColor: .tertiaryLabelColor))
            }
        }
    }

    private func metadataLine(systemImage: String, text: String, color: Color) -> some View {
        Label {
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.callout)
        .foregroundStyle(color)
    }

    @ViewBuilder
    private func profileActivationControl(_ profile: ProxyProfile) -> some View {
        if profile.id == model.profileLibrary.activeProfileID {
            activeStatusPill
        } else {
            Button {
                model.activateProfile(profile)
            } label: {
                Label(model.t(.activate), systemImage: "checkmark.circle.fill")
                    .frame(width: Layout.primaryActionWidth)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func profileActionBar(_ profile: ProxyProfile) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                profileEditButton(profile, tone: .primary)
                profileEditRulesButton(profile)
                profileEditNodesButton(profile)
                profileEditProxyGroupsButton(profile)
            }

            HStack(spacing: 6) {
                profileUpdateButton(profile)
                profileUpdateViaProxyButton(profile)
                profileExtendOverrideButton(profile)
                profileOpenFileButton(profile)
                profileDeleteButton(profile)
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileEditButton(_ profile: ProxyProfile, tone: ProfileActionTone = .neutral) -> some View {
        profileActionButton(title: model.t(.edit), systemImage: "square.and.pencil", width: Layout.compactActionWidth, tone: tone) {
            model.beginEditProfile(profile)
        }
    }

    private func profileEditRulesButton(_ profile: ProxyProfile) -> some View {
        profileActionButton(title: model.t(.editRules), systemImage: ProfileSectionEditorKind.rules.systemImage, tone: .blue) {
            model.beginEditProfileSection(profile, kind: .rules)
        }
    }

    private func profileEditNodesButton(_ profile: ProxyProfile) -> some View {
        profileActionButton(title: model.t(.editNodes), systemImage: ProfileSectionEditorKind.proxies.systemImage, tone: .teal) {
            model.beginEditProfileSection(profile, kind: .proxies)
        }
    }

    private func profileEditProxyGroupsButton(_ profile: ProxyProfile) -> some View {
        profileActionButton(title: model.t(.editProxyGroups), systemImage: ProfileSectionEditorKind.proxyGroups.systemImage, width: 108, tone: .violet) {
            model.beginEditProfileSection(profile, kind: .proxyGroups)
        }
    }

    private func profileExtendOverrideButton(_ profile: ProxyProfile) -> some View {
        profileActionButton(title: model.t(.extendOverrideConfig), systemImage: "doc.badge.gearshape", width: 124, tone: .orange) {
            model.beginEditProfileAppendix(profile)
        }
    }

    private func profileOpenFileButton(_ profile: ProxyProfile) -> some View {
        profileActionButton(title: model.t(.openFile), systemImage: "arrow.up.right.square", width: Layout.compactActionWidth, tone: .neutral) {
            model.openProfileFile(profile)
        }
    }

    private func profileUpdateButton(_ profile: ProxyProfile) -> some View {
        profileActionButton(
            title: model.t(.update),
            systemImage: "arrow.clockwise",
            width: Layout.compactActionWidth,
            disabled: profile.remoteURL == nil,
            tone: .orange
        ) {
            model.updateProfile(profile)
        }
    }

    private func profileUpdateViaProxyButton(_ profile: ProxyProfile) -> some View {
        profileActionButton(
            title: model.t(.updateViaProxy),
            systemImage: "point.3.connected.trianglepath.dotted",
            width: 114,
            disabled: profile.remoteURL == nil,
            tone: .teal
        ) {
            model.updateProfileViaProxy(profile)
        }
    }

    private func profileDeleteButton(_ profile: ProxyProfile) -> some View {
        profileActionButton(title: model.t(.delete), systemImage: "trash", width: Layout.compactActionWidth, tone: .red) {
            requestDeleteProfile(profile)
        }
    }

    // 删除配置是不可逆维护动作；所有入口都必须先走同一个确认状态，
    // 避免按钮、右键菜单等路径出现“一个确认、一个直接删”的分裂行为。
    private func requestDeleteProfile(_ profile: ProxyProfile) {
        pendingDeleteProfile = profile
        showingDeleteConfirmation = true
    }

    private func profileActionButton(
        title: String,
        systemImage: String,
        width: CGFloat = Layout.actionWidth,
        disabled: Bool = false,
        tone: ProfileActionTone = .neutral,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            profileActionLabel(title: title, systemImage: systemImage, minWidth: width, tone: tone)
                .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(title)
    }

    private func profileActionLabel(title: String, systemImage: String, minWidth: CGFloat, tone: ProfileActionTone) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tone.foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 10)
            .frame(minWidth: minWidth)
            .frame(height: Layout.actionHeight)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(tone.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(tone.border)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func profileSecondaryActionMenu(_ profile: ProxyProfile) -> some View {
        Button {
            model.beginEditProfileSection(profile, kind: .proxyGroups)
        } label: {
            Label(model.t(.editProxyGroups), systemImage: ProfileSectionEditorKind.proxyGroups.systemImage)
        }

        Divider()

        Button {
            model.beginEditProfileAppendix(profile)
        } label: {
            Label(model.t(.extendOverrideConfig), systemImage: "doc.badge.gearshape")
        }

        Button {
            model.noteProfileScriptUnsupported()
        } label: {
            Label(model.t(.extendScript), systemImage: "curlybraces")
        }

        Divider()

        Button {
            model.openProfileFile(profile)
        } label: {
            Label(model.t(.openFile), systemImage: "arrow.up.right.square")
        }

        Button {
            model.updateProfileViaProxy(profile)
        } label: {
            Label(model.t(.updateViaProxy), systemImage: "point.3.connected.trianglepath.dotted")
        }
        .disabled(profile.remoteURL == nil)

        Divider()

        Button(role: .destructive) {
            requestDeleteProfile(profile)
        } label: {
            Label(model.t(.delete), systemImage: "trash")
        }
    }

    @ViewBuilder
    private func profileActionMenu(_ profile: ProxyProfile) -> some View {
        Button {
            model.activateProfile(profile)
        } label: {
            Label(model.t(.useProfile), systemImage: "checkmark.circle")
        }
        .disabled(profile.id == model.profileLibrary.activeProfileID)

        Button {
            model.beginEditProfile(profile)
        } label: {
            Label(model.t(.edit), systemImage: "square.and.pencil")
        }

        Divider()

        Button {
            model.beginEditProfileSection(profile, kind: .rules)
        } label: {
            Label(model.t(.editRules), systemImage: ProfileSectionEditorKind.rules.systemImage)
        }

        Button {
            model.beginEditProfileSection(profile, kind: .proxies)
        } label: {
            Label(model.t(.editNodes), systemImage: ProfileSectionEditorKind.proxies.systemImage)
        }

        Button {
            model.beginEditProfileSection(profile, kind: .proxyGroups)
        } label: {
            Label(model.t(.editProxyGroups), systemImage: ProfileSectionEditorKind.proxyGroups.systemImage)
        }

        profileSecondaryActionMenu(profile)
    }
}

private struct ExternalProfileImportSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    // The scanner can find many configs across Clash Verge, ClashX, Mihomo Party, and ~/.config.
    // Keep those results in a dedicated sheet so the Profiles sidebar stays an entry rail instead
    // of becoming a cramped result table.
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            toolbar
            resultsArea
            footer
        }
        .padding(22)
        .frame(width: 820, height: 560)
        .background(ChumenStyle.pageBackground)
        .onAppear {
            if !model.externalProfileScanCompleted {
                model.scanExternalProfiles()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.blue)
                .frame(width: 54, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(model.t(.importFromClients))
                    .font(.title3.weight(.semibold))
                Text(model.t(.externalImportHint))
                    .font(.callout)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text("\(displayedCandidates.count) / \(model.externalProfileCandidates.count)")
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    Capsule(style: .continuous)
                        .fill(ChumenStyle.controlFill)
                )
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ChumenStyle.mutedText)
                TextField(model.t(.importSearchPlaceholder), text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(ChumenStyle.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .strokeBorder(ChumenStyle.border)
            )

            Button {
                model.scanExternalProfiles()
            } label: {
                Label(model.t(.scanClients), systemImage: "arrow.clockwise")
            }
            .controlSize(.large)

            Button {
                model.importExternalProfiles(displayedCandidates)
            } label: {
                Label(model.t(.importAllFound), systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(displayedCandidates.isEmpty)
        }
    }

    @ViewBuilder
    private var resultsArea: some View {
        if model.externalProfileCandidates.isEmpty {
            emptyResultState(
                systemImage: model.externalProfileScanCompleted ? "magnifyingglass" : "clock",
                title: model.externalProfileScanCompleted ? model.t(.noExternalProfilesFound) : model.t(.externalImportHint)
            )
        } else if displayedCandidates.isEmpty {
            emptyResultState(systemImage: "magnifyingglass", title: model.t(.noSearchResults))
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(displayedCandidates) { candidate in
                        candidateRow(candidate)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func emptyResultState(systemImage: String, title: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(ChumenStyle.mutedText)
            Text(title)
                .font(.headline)
                .foregroundStyle(ChumenStyle.mutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }

    private func candidateRow(_ candidate: ExternalProfileCandidate) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(candidate.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text(candidate.sourceName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(ChumenStyle.mutedText)
                        .lineLimit(1)
                }

                Label {
                    Text(ExternalProfileCandidateSearch.displayPath(candidate.filePath))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                } icon: {
                    Image(systemName: "folder")
                }
                .font(.callout)
                .foregroundStyle(ChumenStyle.mutedText)

                if let remoteURL = candidate.remoteURL, !remoteURL.isEmpty {
                    Label {
                        Text(remoteURL)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    } icon: {
                        Image(systemName: "link")
                    }
                    .font(.callout)
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                }
            }

            Spacer(minLength: 12)

            Button {
                model.importExternalProfile(candidate)
            } label: {
                Text(model.t(.importOne))
                    .frame(width: 72)
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
    }

    private var footer: some View {
        HStack {
            Text(model.statusText)
                .font(.callout)
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)

            Spacer()

            Button(model.t(.close)) {
                dismiss()
            }
            .controlSize(.large)
        }
    }

    private var displayedCandidates: [ExternalProfileCandidate] {
        ExternalProfileCandidateSearch.filter(model.externalProfileCandidates, query: searchText)
    }
}
