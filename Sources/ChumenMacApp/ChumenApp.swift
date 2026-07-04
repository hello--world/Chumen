import AppKit
import ChumenCore
import SwiftUI

private enum ChumenWindowMetrics {
    static let contentSize = NSSize(width: 1080, height: 570)
}

@main
struct ChumenMacApp: App {
    @NSApplicationDelegateAdaptor(ChumenAppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel
    @StateObject private var notificationService: ChumenNotificationService

    init() {
        let notificationService = ChumenNotificationService()
        let model = AppModel(notificationService: notificationService)
        _notificationService = StateObject(wrappedValue: notificationService)
        _model = StateObject(wrappedValue: model)
        ChumenAppDelegate.model = model
    }

    var body: some Scene {
        Window("Chumen", id: "main") {
            ZStack {
                ContentView()
                StatusBarInstaller()
                    .frame(width: 0, height: 0)
                FixedMainWindowConfigurator(size: ChumenWindowMetrics.contentSize)
                    .frame(width: 0, height: 0)
                ChumenNotificationHost()
                    .zIndex(1000)
            }
                .environmentObject(model)
                .environmentObject(notificationService)
                .environmentObject(model.configSync)
                .frame(
                    width: ChumenWindowMetrics.contentSize.width,
                    height: ChumenWindowMetrics.contentSize.height
                )
                .task {
                    notificationService.requestAuthorizationIfNeeded()
                }
        }
        .defaultSize(
            width: ChumenWindowMetrics.contentSize.width,
            height: ChumenWindowMetrics.contentSize.height
        )
        .windowResizability(.contentSize)
    }
}

private struct FixedMainWindowConfigurator: NSViewRepresentable {
    let size: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: view.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }

        let fixedFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: size)).size
        window.contentMinSize = size
        window.contentMaxSize = size
        window.minSize = fixedFrameSize
        window.maxSize = fixedFrameSize

        if window.contentView?.bounds.size != size {
            let frame = window.frame
            let targetFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
            let origin = NSPoint(
                x: frame.midX - targetFrame.width / 2,
                y: frame.midY - targetFrame.height / 2
            )
            window.setFrame(NSRect(origin: origin, size: targetFrame.size), display: true)
        }

        window.styleMask.remove(.resizable)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }
}

private struct StatusBarInstaller: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .onAppear {
                StatusBarController.shared.install(model: model) {
                    NSApplication.shared.setActivationPolicy(.regular)
                    openWindow(id: "main")
                    DispatchQueue.main.async {
                        model.showMainWindow()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        model.showMainWindow()
                    }
                }
            }
    }
}

@MainActor
private final class ChumenAppDelegate: NSObject, NSApplicationDelegate {
    static var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        installStatusBar(replaceOpenAction: false)
        DispatchQueue.main.async { [weak self] in
            self?.installStatusBar(replaceOpenAction: false)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        if Self.model?.settings.showStatusBarItem == true {
            sender.setActivationPolicy(.accessory)
        } else {
            sender.setActivationPolicy(.regular)
        }
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.model?.showMainWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.model?.prepareForQuit()
    }

    private func installStatusBar(replaceOpenAction: Bool) {
        guard let model = Self.model else { return }
        StatusBarController.shared.install(model: model, openMainWindow: {
            model.showMainWindow()
        }, replaceOpenAction: replaceOpenAction)
    }
}
