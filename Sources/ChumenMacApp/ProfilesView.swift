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

            profileActionButton(
                title: model.t(.update),
                systemImage: "arrow.clockwise",
                width: Layout.compactActionWidth,
                disabled: profile.remoteURL == nil
            ) {
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
