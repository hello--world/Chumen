import ChumenCore
import SwiftUI

struct ProfileEditorSheet: View {
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

struct ProfileSectionEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    let editor: ProfileSectionEditorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(model.t(editor.kind.titleKey), systemImage: editor.kind.systemImage)
                        .font(.headline)
                    HStack(spacing: 6) {
                        sectionPatchChip(model.t(.prependAppend), color: .blue)
                        sectionPatchChip(model.t(.appendAppend), color: .green)
                        sectionPatchChip(model.t(.deleteOriginalItems), color: .red)
                    }
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
                ProfileSectionPatchEditor(
                    kind: editor.kind,
                    text: $model.profileSectionEditorText,
                    sections: $model.profileSectionEditorVisualSections
                )
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

    private func sectionPatchChip(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.10), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.28)))
    }
}

struct ProfileAppendixEditorSheet: View {
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
