import ChumenCore
import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var choosingProfile: Bool
    @State private var profileSearchText = ""
    @State private var externalImportSearchText = ""

    // The Profiles page is a high-frequency maintenance surface: users scan the current config,
    // make one targeted change, then leave. Keep imports in the left rail and make each profile row
    // read like a compact settings row, not a dashboard card with every action competing at once.
    private enum Layout {
        static let sidebarWidth: CGFloat = 320
        static let pagePadding: CGFloat = 18
        static let rowHorizontalPadding: CGFloat = 16
        static let rowVerticalPadding: CGFloat = 14
        static let actionWidth: CGFloat = 96
        static let compactActionWidth: CGFloat = 80
        static let actionHeight: CGFloat = 30
        static let primaryActionWidth: CGFloat = 108
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

                    HStack(spacing: 8) {
                        Button {
                            model.scanExternalProfiles()
                        } label: {
                            Label(model.t(.scanClients), systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            model.importExternalProfiles(filteredExternalProfileCandidates)
                        } label: {
                            Label(model.t(.importAllFound), systemImage: "tray.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(filteredExternalProfileCandidates.isEmpty)
                    }

                    externalProfileCandidatesList
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

    @ViewBuilder
    private var externalProfileCandidatesList: some View {
        if model.externalProfileCandidates.isEmpty && model.externalProfileScanCompleted {
            Text(model.t(.noExternalProfilesFound))
                .font(.callout)
                .foregroundStyle(ChumenStyle.mutedText)
        } else if !model.externalProfileCandidates.isEmpty {
            TextField(model.t(.importSearchPlaceholder), text: $externalImportSearchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredExternalProfileCandidates) { candidate in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(candidate.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(candidate.sourceName)
                                    .font(.caption)
                                    .foregroundStyle(ChumenStyle.mutedText)
                                if candidate.remoteURL != nil {
                                    Label(model.t(.subscriptionURLFound), systemImage: "link.badge.plus")
                                        .font(.caption)
                                        .foregroundStyle(ChumenStyle.mutedText)
                                }
                                Text(candidate.filePath)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 8)
                            Button(model.t(.importOne)) {
                                model.importExternalProfile(candidate)
                            }
                            .controlSize(.small)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(ChumenStyle.identityFill)
                        )
                    }
                }
            }
            .frame(maxHeight: 220)
        }
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

    private var filteredExternalProfileCandidates: [ExternalProfileCandidate] {
        let query = externalImportSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.externalProfileCandidates }
        return model.externalProfileCandidates.filter { candidate in
            [candidate.name, candidate.sourceName, candidate.filePath, candidate.remoteURL ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
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

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(profile.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if profile.id == model.profileLibrary.activeProfileID {
                        activeStatusPill
                    }
                }

                profileMetadata(profile)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                if profile.id != model.profileLibrary.activeProfileID {
                    profileActivationControl(profile)
                }
                profileActionBar(profile)
            }
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
        profileActionBarContent(profile)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func profileActionBarContent(_ profile: ProxyProfile) -> some View {
        HStack(spacing: 8) {
            profileActionButton(title: model.t(.edit), systemImage: "square.and.pencil", width: Layout.compactActionWidth, prominent: true) {
                model.beginEditProfile(profile)
            }

            profileActionButton(title: model.t(.editRules), systemImage: ProfileSectionEditorKind.rules.systemImage) {
                model.beginEditProfileSection(profile, kind: .rules)
            }

            profileActionButton(title: model.t(.editNodes), systemImage: ProfileSectionEditorKind.proxies.systemImage) {
                model.beginEditProfileSection(profile, kind: .proxies)
            }

            profileActionButton(title: model.t(.update), systemImage: "arrow.clockwise", width: Layout.compactActionWidth, disabled: profile.remoteURL == nil) {
                model.updateProfile(profile)
            }

            profileMoreMenu(profile)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func profileActionButton(
        title: String,
        systemImage: String,
        width: CGFloat = Layout.actionWidth,
        disabled: Bool = false,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            profileActionLabel(title: title, systemImage: systemImage, width: width, prominent: prominent)
                .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(title)
    }

    private func profileMoreMenu(_ profile: ProxyProfile) -> some View {
        Menu {
            profileSecondaryActionMenu(profile)
        } label: {
            profileActionLabel(title: model.t(.more), systemImage: "ellipsis.circle", width: Layout.compactActionWidth, prominent: false)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(model.t(.more))
    }

    private func profileActionLabel(title: String, systemImage: String, width: CGFloat, prominent: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(prominent ? Color.white : Color.primary)
        .frame(width: width, height: Layout.actionHeight)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(prominent ? Color.accentColor : ChumenStyle.controlFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(prominent ? Color.accentColor.opacity(0.35) : ChumenStyle.border.opacity(0.55))
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
            model.deleteProfile(profile)
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

private struct ProfileEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    let profile: ProxyProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(model.t(.edit), systemImage: "square.and.pencil")
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

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text(model.t(.displayName))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ChumenStyle.mutedText)
                    TextField(model.t(.displayName), text: $model.profileEditorName)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text(model.t(.subscriptionURL))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ChumenStyle.mutedText)
                    TextField(model.t(.subscriptionURL), text: $model.profileEditorRemoteURL)
                        .textFieldStyle(.roundedBorder)
                }
            }

            ZStack {
                LiveYAMLCodeEditor(text: $model.profileEditorText, sections: $model.profileEditorVisualSections)
                    .frame(minWidth: 980, minHeight: 520)
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
        .frame(width: 1040, height: 680)
    }
}

private struct ProfileSectionEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    let editor: ProfileSectionEditorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(model.t(editor.kind.titleKey), systemImage: editor.kind.systemImage)
                        .font(.headline)
                    Text(editor.profile.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(model.t(.cancel)) {
                    model.cancelProfileSectionEditor()
                }
                Button(model.t(.save)) {
                    model.saveProfileSectionEditor()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.profileSectionEditorIsLoading)
            }

            ZStack {
                LiveYAMLCodeEditor(text: $model.profileSectionEditorText, sections: $model.profileSectionEditorVisualSections)
                    .frame(minWidth: 980, minHeight: 520)
                    .opacity(model.profileSectionEditorIsLoading ? 0.35 : 1)

                if model.profileSectionEditorIsLoading {
                    ProgressView()
                        .controlSize(.large)
                        .padding(18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(18)
        .frame(width: 1040, height: 620)
    }
}

private struct ProfileAppendixEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    let target: ProfileAppendixEditorTarget

    private var title: String {
        switch target {
        case .global:
            model.t(.globalExtendOverrideConfig)
        case .profile:
            model.t(.extendOverrideConfig)
        }
    }

    private var subtitle: String {
        switch target {
        case .global:
            model.t(.configAppendix)
        case let .profile(profile):
            profile.name
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(title, systemImage: "doc.badge.gearshape")
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(model.t(.cancel)) {
                    model.cancelProfileAppendixEditor()
                }
                Button(model.t(.save)) {
                    model.saveProfileAppendixEditor()
                }
                .keyboardShortcut(.defaultAction)
            }

            LiveYAMLCodeEditor(text: $model.profileAppendixEditorText, sections: $model.profileAppendixEditorVisualSections)
                .frame(minWidth: 980, minHeight: 510)
        }
        .padding(18)
        .frame(width: 1040, height: 620)
    }
}

private struct LiveYAMLCodeEditor: View {
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

private struct YAMLCommonScalarForm: View {
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

private struct YAMLRulesShortcutForm: View {
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
            YAMLTextField(title: model.t(.targetPolicy), text: $policy)
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

private struct YAMLNodeShortcutForm: View {
    @EnvironmentObject private var model: AppModel
    @Binding private var yamlBody: String
    @State private var nodeName = ""
    @State private var nodeType = "ss"
    @State private var server = ""
    @State private var port = ""
    @State private var username = ""
    @State private var password = ""
    @State private var uuid = ""
    @State private var cipher = "auto"
    @State private var sni = ""
    @State private var udp = true
    @State private var tls = false

    init(body: Binding<String>) {
        _yamlBody = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t(.quickAddNode))
                .font(.caption.weight(.semibold))

            YAMLTextField(title: model.t(.name), text: $nodeName)
            YAMLPickerField(title: model.t(.nodeType), options: ["ss", "vmess", "trojan", "hysteria2", "http", "socks5"], selection: $nodeType)
            HStack(spacing: 8) {
                YAMLTextField(title: model.t(.server), text: $server)
                YAMLTextField(title: model.t(.portNumber), text: $port)
                    .frame(width: 100)
            }
            YAMLTextField(title: model.t(.username), text: $username)
            YAMLTextField(title: model.t(.password), text: $password)
            YAMLTextField(title: "UUID", text: $uuid)
            YAMLTextField(title: model.t(.cipher), text: $cipher)
            YAMLTextField(title: "SNI", text: $sni)
            HStack {
                Toggle("UDP", isOn: $udp)
                Toggle("TLS", isOn: $tls)
            }
            .toggleStyle(.switch)

            Button {
                appendNode()
            } label: {
                Label(model.t(.addNode), systemImage: "plus")
            }
            .disabled(nodeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    private func appendNode() {
        var lines = [
            "- name: \(YAMLVisualValue.clean(nodeName))",
            "  type: \(nodeType)",
            "  server: \(YAMLVisualValue.clean(server))"
        ]
        YAMLVisualValue.appendKey("port", value: port, to: &lines)
        YAMLVisualValue.appendKey("username", value: username, to: &lines)
        YAMLVisualValue.appendKey("password", value: password, to: &lines)
        YAMLVisualValue.appendKey("uuid", value: uuid, to: &lines)
        YAMLVisualValue.appendKey("cipher", value: cipher, to: &lines)
        YAMLVisualValue.appendKey("sni", value: sni, to: &lines)
        lines.append("  udp: \(udp ? "true" : "false")")
        if tls {
            lines.append("  tls: true")
        }
        yamlBody = YAMLVisualValue.appending(lines.joined(separator: "\n"), to: yamlBody)
        nodeName = ""
        server = ""
        port = ""
        username = ""
        password = ""
        uuid = ""
        sni = ""
    }
}

private struct YAMLProxyGroupShortcutForm: View {
    @EnvironmentObject private var model: AppModel
    @Binding private var yamlBody: String
    @State private var groupName = ""
    @State private var groupType = "select"
    @State private var members = "DIRECT"
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
            YAMLTextField(title: model.t(.groupMembers), text: $members)
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
        let proxyNames = members
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for name in proxyNames.isEmpty ? ["DIRECT"] : proxyNames {
            lines.append("    - \(name)")
        }
        yamlBody = YAMLVisualValue.appending(lines.joined(separator: "\n"), to: yamlBody)
        groupName = ""
    }
}

private struct YAMLDNSShortcutForm: View {
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

private struct YAMLHostsShortcutForm: View {
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

private struct YAMLAdvancedSectionForm: View {
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

private struct YAMLSectionPreviewView: View {
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

private struct YAMLSectionPreviewData: Equatable, Sendable {
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

private struct YAMLSectionPreviewItem: Identifiable, Equatable, Sendable {
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

struct YAMLTopLevelSection: Equatable, Sendable {
    var key: String
    var body: String

    static func parse(_ yaml: String) -> [YAMLTopLevelSection] {
        let lines = yaml.components(separatedBy: .newlines)
        var sections: [YAMLTopLevelSection] = []
        var currentKey: String?
        var currentInlineValue = ""
        var currentBody: [String] = []

        func flush() {
            guard let currentKey else { return }
            let body = currentBody.isEmpty
                ? currentInlineValue
                : currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(YAMLTopLevelSection(key: currentKey, body: body))
        }

        for line in lines {
            if let key = ChumenConfigurationBuilder.topLevelKey(in: line) {
                flush()
                currentKey = key
                currentInlineValue = topLevelValue(in: line)
                currentBody = []
            } else if currentKey != nil {
                currentBody.append(line)
            }
        }

        flush()
        return sections
    }

    static func render(_ sections: [YAMLTopLevelSection]) -> String {
        sections
            .map(renderSection)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func renderSection(_ section: YAMLTopLevelSection) -> String {
        let key = section.key.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
        guard !key.isEmpty else { return "" }

        let body = section.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return "\(key):" }

        if shouldRenderInline(body) {
            return "\(key): \(body)"
        }

        return "\(key):\n\(indented(body))"
    }

    private static func shouldRenderInline(_ body: String) -> Bool {
        guard !body.contains("\n") else { return false }

        let trimmed = body.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("-") else { return false }
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            return true
        }
        return !trimmed.contains(":")
    }

    private static func indented(_ body: String) -> String {
        body.components(separatedBy: .newlines)
            .map { line in
                guard !line.isEmpty else { return line }
                if line.hasPrefix(" ") || line.hasPrefix("\t") {
                    return line
                }
                return "  \(line)"
            }
            .joined(separator: "\n")
    }

    private static func topLevelValue(in line: String) -> String {
        guard let colonIndex = line.firstIndex(of: ":") else { return "" }
        return line[line.index(after: colonIndex)...]
            .trimmingCharacters(in: .whitespaces)
    }
}
