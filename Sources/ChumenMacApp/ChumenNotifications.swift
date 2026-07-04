import AppKit
import SwiftUI
@preconcurrency import UserNotifications

enum ChumenNotificationAuthorizationState: Equatable {
    case unknown
    case notDetermined
    case authorized
    case denied

    var logName: String {
        switch self {
        case .unknown:
            "unknown"
        case .notDetermined:
            "not-determined"
        case .authorized:
            "authorized"
        case .denied:
            "denied"
        }
    }
}

enum ChumenNotificationLevel: Equatable {
    case info
    case success
    case warning
    case failure

    var systemImage: String {
        switch self {
        case .info:
            "bell.badge"
        case .success:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .failure:
            "xmark.octagon.fill"
        }
    }

    var accent: Color {
        switch self {
        case .info:
            Color(nsColor: .controlAccentColor)
        case .success:
            .green
        case .warning:
            .orange
        case .failure:
            .red
        }
    }

    var logName: String {
        switch self {
        case .info:
            "info"
        case .success:
            "success"
        case .warning:
            "warning"
        case .failure:
            "failure"
        }
    }
}

struct ChumenInAppNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
    let level: ChumenNotificationLevel
    let createdAt = Date()
}

@MainActor
final class ChumenNotificationService: NSObject, ObservableObject {
    @Published private(set) var authorizationState: ChumenNotificationAuthorizationState = .unknown
    @Published private(set) var inAppNotification: ChumenInAppNotification?

    var onLog: ((String) -> Void)?

    private let center: UNUserNotificationCenter
    private var dismissalTask: Task<Void, Never>?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        log("authorization check requested")
        Task { [weak self] in
            guard let self else { return }
            _ = await self.resolveAuthorization(requestIfNeeded: true)
        }
    }

    func refreshAuthorizationState() {
        log("authorization refresh requested")
        Task { [weak self] in
            guard let self else { return }
            _ = await self.resolveAuthorization(requestIfNeeded: false)
        }
    }

    func notify(title: String, body: String, level: ChumenNotificationLevel = .info) {
        let notification = ChumenInAppNotification(title: title, body: body, level: level)
        log(notification, phase: "requested")
        Task { [weak self] in
            await self?.deliver(notification)
        }
    }

    func dismissInAppNotification(_ id: ChumenInAppNotification.ID) {
        guard inAppNotification?.id == id else { return }
        log("in-app dismissed id=\(id.uuidString)")
        dismissalTask?.cancel()
        dismissalTask = nil
        withAnimation(.easeOut(duration: 0.16)) {
            inAppNotification = nil
        }
    }

    private func deliver(_ notification: ChumenInAppNotification) async {
        let state = await resolveAuthorization(requestIfNeeded: true)
        log(notification, phase: "authorization=\(state.logName)")
        guard state == .authorized else {
            log(notification, phase: "fallback=in-app reason=authorization-\(state.logName)")
            presentInApp(notification)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "chumen-\(notification.id.uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            log(notification, phase: "scheduled system id=\(request.identifier)")
        } catch {
            log(notification, phase: "system failed id=\(request.identifier) error=\(error.localizedDescription)")
            presentInApp(notification)
        }
    }

    private func resolveAuthorization(requestIfNeeded: Bool) async -> ChumenNotificationAuthorizationState {
        let settings = await center.notificationSettings()
        let state = authorizationState(from: settings.authorizationStatus)
        if authorizationState != state {
            log("authorization state \(authorizationState.logName) -> \(state.logName)")
        } else {
            log("authorization state \(state.logName)")
        }
        authorizationState = state

        guard requestIfNeeded, state == .notDetermined else {
            return state
        }

        do {
            log("authorization prompt presenting")
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            let requestedState: ChumenNotificationAuthorizationState = granted ? .authorized : .denied
            authorizationState = requestedState
            log("authorization prompt result \(requestedState.logName)")
            return requestedState
        } catch {
            authorizationState = .denied
            log("authorization prompt failed error=\(error.localizedDescription)")
            return .denied
        }
    }

    private func authorizationState(from status: UNAuthorizationStatus) -> ChumenNotificationAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized, .provisional:
            .authorized
        @unknown default:
            .denied
        }
    }

    private func presentInApp(_ notification: ChumenInAppNotification) {
        log(notification, phase: "presented in-app")
        dismissalTask?.cancel()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            inAppNotification = notification
        }
        dismissalTask = Task { [weak self, id = notification.id] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.dismissInAppNotification(id)
            }
        }
    }

    private func log(_ notification: ChumenInAppNotification, phase: String) {
        log("notification \(phase) [\(notification.level.logName)] \(notification.title): \(notification.body)")
    }

    private func log(_ message: String) {
        onLog?("notification-service \(message)")
    }
}

extension ChumenNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            self.log("system will-present id=\(notification.request.identifier) title=\(notification.request.content.title)")
        }
        completionHandler([.banner, .list, .sound])
    }
}

struct ChumenNotificationHost: View {
    @EnvironmentObject private var notifications: ChumenNotificationService

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let notification = notifications.inAppNotification {
                ChumenInAppNotificationView(notification: notification) {
                    notifications.dismissInAppNotification(notification.id)
                }
                .padding(.top, 14)
                .padding(.trailing, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(notifications.inAppNotification != nil)
    }
}

private struct ChumenInAppNotificationView: View {
    let notification: ChumenInAppNotification
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            appIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(notification.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text("now")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Text(notification.body)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 344, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.28))
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private var appIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Image(systemName: notification.level.systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 15, height: 15)
                .background(notification.level.accent, in: Circle())
        }
        .frame(width: 38, height: 38)
    }
}
