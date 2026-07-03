import ChumenCore
import SwiftUI

@main
struct ChumenMacApp: App {
    @NSApplicationDelegateAdaptor(ChumenAppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        ChumenAppDelegate.model = model
    }

    var body: some Scene {
        Window("Chumen", id: "main") {
            ZStack {
                ContentView()
                StatusBarInstaller()
                    .frame(width: 0, height: 0)
            }
                .environmentObject(model)
                .frame(minWidth: 920, minHeight: 620)
        }
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
