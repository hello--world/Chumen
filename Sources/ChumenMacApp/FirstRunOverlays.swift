import ChumenCore
import SwiftUI

private enum PINOverlayStyle {
    // The first-run security step uses a single identity panel plus native settings rows. Color
    // establishes the security context; the actual controls stay neutral and system-like.
    static let accent = Color(red: 0.05, green: 0.45, blue: 0.92)
    static let teal = Color(red: 0.00, green: 0.74, blue: 0.62)
    static let violet = Color(red: 0.58, green: 0.34, blue: 0.86)
    static let orange = Color(red: 1.00, green: 0.56, blue: 0.20)
    static let accentFill = Color(red: 0.90, green: 0.95, blue: 1.00)
    static let backdrop = Color(nsColor: .controlBackgroundColor).opacity(0.52)
    static let card = Color(nsColor: .textBackgroundColor)
    static let group = Color(nsColor: .controlBackgroundColor).opacity(0.50)
    static let field = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.24)
    static let subtleBorder = Color(nsColor: .separatorColor).opacity(0.16)
    static let shadow = Color.black.opacity(0.045)
}
struct PINLockOverlay: View {
    @EnvironmentObject private var model: AppModel
    @State private var setupPINVisible = true

    var body: some View {
        GeometryReader { geometry in
            let width = min(CGFloat(980), max(CGFloat(820), geometry.size.width - CGFloat(120)))

            ZStack {
                Rectangle()
                    .fill(PINOverlayStyle.backdrop)
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    introPanel
                        .frame(width: 300)

                    VStack(alignment: .leading, spacing: 14) {
                        storageSection
                        if model.pinSetupRequired {
                            setupSection
                            Spacer(minLength: 0)
                            setupActions
                        } else {
                            unlockSection
                            Spacer(minLength: 0)
                            unlockActions
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(width: width, height: 460)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(PINOverlayStyle.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .strokeBorder(PINOverlayStyle.border)
                )
                .shadow(color: PINOverlayStyle.shadow, radius: 16, x: 0, y: 8)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .tint(PINOverlayStyle.accent)
        }
    }

    private var introPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: model.pinSetupRequired ? "key.fill" : "lock.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PINOverlayStyle.accent)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(.white.opacity(0.92))
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(model.t(.pinProtection))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text(model.pinStatusText.isEmpty ? model.t(.pinRequired) : model.pinStatusText)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 12) {
                PINHeroHint(
                    systemImage: "lock.doc",
                    text: model.t(.pinInfoConfigEncrypted)
                )
                PINHeroHint(
                    systemImage: "key.horizontal",
                    text: model.t(.pinInfoPINProtectsKey)
                )
                PINHeroHint(
                    systemImage: "arrow.right.circle",
                    text: model.t(.pinInfoSkipTradeoff)
                )
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    PINOverlayStyle.accent,
                    PINOverlayStyle.teal,
                    PINOverlayStyle.violet.opacity(0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 140, height: 140)
                .offset(x: 54, y: -58)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: ChumenStyle.radius,
                bottomLeadingRadius: ChumenStyle.radius
            )
        )
    }

    private var storageSection: some View {
        settingGroup {
            HStack(spacing: 14) {
                Text(model.t(.pinStorage))
                    .font(.headline)
                Spacer(minLength: 24)
                Picker(model.t(.pinStorage), selection: Binding(
                    get: { model.pinStorageKind },
                    set: { model.setPINStorageKind($0) }
                )) {
                    ForEach(ChumenAgeKeyStorageKind.allCases) { storage in
                        Text(pinStorageTitle(storage)).tag(storage)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
                .frame(width: 250)
                .labelsHidden()
            }
        }
    }

    private var setupSection: some View {
        settingGroup {
            Toggle(model.t(.pinProtectAgeKey), isOn: Binding(
                get: { model.pinSetupProtectAgeKey },
                set: { enabled in
                    model.pinSetupProtectAgeKey = enabled
                    if !enabled {
                        model.pinAppLockOnLaunch = false
                    }
                }
            ))
            .font(.headline)
            .controlSize(.regular)

            if model.pinSetupProtectAgeKey {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(model.t(.pinGeneratedPIN))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ChumenStyle.mutedText)

                    HStack(alignment: .center, spacing: 10) {
                        RevealablePINField(
                            title: model.t(.pinValue),
                            text: singlePINBinding,
                            isVisible: $setupPINVisible,
                            showTitle: model.t(.pinShow),
                            hideTitle: model.t(.pinHide)
                        )
                        Button {
                            model.regeneratePINSetupPIN()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.bordered)
                        .help(model.t(.pinRegenerate))
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(model.t(.pinLockAppOnLaunch), isOn: Binding(
                        get: { model.pinAppLockOnLaunch },
                        set: { model.setPINAppLockOnLaunch($0) }
                    ))
                    .font(.headline)
                    .controlSize(.regular)

                    Text(model.t(.pinLockAppOnLaunchHint))
                        .font(.callout)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var singlePINBinding: Binding<String> {
        Binding(
            get: { model.pinSetupPIN },
            set: { value in
                model.pinSetupPIN = value
                model.pinSetupConfirm = value
            }
        )
    }

    private var unlockSection: some View {
        settingGroup {
            SecureField(model.t(.pinValue), text: $model.pinInput)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .onSubmit {
                    model.unlockPIN()
                }
        }
    }

    private var setupActions: some View {
        HStack {
            if model.pinSetupProtectAgeKey {
                Button(model.t(.pinContinueWithoutPIN)) {
                    model.skipPINProtectionSetup()
                }
                .controlSize(.large)
                Spacer()
                Button(model.t(.pinEnable)) {
                    model.enablePINProtection()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Spacer()
                Button(model.t(.pinContinueWithoutPIN)) {
                    model.skipPINProtectionSetup()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var unlockActions: some View {
        HStack {
            if model.pinStorageLocked {
                Button(model.t(.pinUnlockAndDisable)) {
                    model.unlockAndDisablePINProtection()
                }
                .controlSize(.large)
            }
            Spacer()
            Button(model.t(.pinUnlock)) {
                model.unlockPIN()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func settingGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(PINOverlayStyle.group)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(PINOverlayStyle.subtleBorder)
        )
    }

    private func pinStorageTitle(_ storage: ChumenAgeKeyStorageKind) -> String {
        switch storage {
        case .local:
            model.t(.pinStorageLocal)
        case .keychain:
            model.t(.pinStorageKeychain)
        }
    }
}

private struct PINHeroHint: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 22, height: 22)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(text)
                .font(.callout.weight(.medium))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white.opacity(0.92))
    }
}

// First-run PIN setup intentionally defaults to visible because the app generates the PIN for
// the user; the eye toggle preserves the normal password-field privacy path without duplicating
// state between SecureField and TextField.
private struct RevealablePINField: View {
    let title: String
    @Binding var text: String
    @Binding var isVisible: Bool
    let showTitle: String
    let hideTitle: String

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isVisible {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.body)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(isVisible ? hideTitle : showTitle)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(PINOverlayStyle.field)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(PINOverlayStyle.border)
        )
    }
}

struct StartupImportOverlay: View {
    @EnvironmentObject private var model: AppModel
    let openLocalImport: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(ChumenStyle.pageBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 18) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 64, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.t(.startupImportTitle))
                            .font(.title2.weight(.semibold))
                        Text(model.t(.startupImportSubtitle))
                            .font(.body)
                            .foregroundStyle(ChumenStyle.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        model.scanExternalProfiles()
                    } label: {
                        Label(model.t(.scanClients), systemImage: "magnifyingglass")
                    }
                    .controlSize(.large)

                    Button {
                        model.importExternalProfiles()
                    } label: {
                        Label(model.t(.importAllFound), systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.externalProfileCandidates.isEmpty)

                    Spacer()

                    Button {
                        openLocalImport()
                    } label: {
                        Label(model.t(.importLocal), systemImage: "doc.badge.plus")
                    }
                    .controlSize(.large)
                }

                if model.externalProfileCandidates.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: model.externalProfileScanCompleted ? "magnifyingglass" : "clock")
                            .foregroundStyle(ChumenStyle.mutedText)
                        Text(model.externalProfileScanCompleted ? model.t(.noExternalProfilesFound) : model.t(.externalImportHint))
                            .font(.callout)
                            .foregroundStyle(ChumenStyle.mutedText)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ChumenStyle.groupedSurface.opacity(0.65))
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(model.externalProfileCandidates) { candidate in
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(candidate.name)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Text(candidate.sourceName)
                                            .font(.callout)
                                            .foregroundStyle(ChumenStyle.mutedText)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 12)
                                    Button(model.t(.importOne)) {
                                        model.importExternalProfile(candidate)
                                    }
                                    .controlSize(.large)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(ChumenStyle.groupedSurface.opacity(0.65))
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }

                HStack {
                    Spacer()
                    Button(model.t(.startupImportLater)) {
                        model.dismissStartupImportPrompt()
                    }
                    .controlSize(.large)
                }
            }
            .padding(28)
            .frame(width: 620)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ChumenStyle.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(ChumenStyle.border)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 30, x: 0, y: 18)
        }
    }
}
