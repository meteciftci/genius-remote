import AppIntents
import AppKit
import SwiftData
import SwiftUI

struct GeniusRemoteApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @FocusedValue(\.appActions) private var actions
    @FocusedValue(\.selectedConnection) private var selectedConnection
    @AppStorage(MenuBarContent.visibilityKey) private var showsMenuBarIcon = true
    @Environment(\.openWindow) private var openWindow
    @State private var launcher: ConnectionLauncher

    private let container: ModelContainer

    init() {
        LaunchFiles.cleanUp()
        // Sparkle only starts its scheduled checks once the updater exists.
        _ = AppUpdater.shared
        container = Self.makeContainer()
        SealedPasswordStore.shared = SealedPasswordStore(container: container)
        let launcher = ConnectionLauncher()
        _launcher = State(initialValue: launcher)
        QuickConnectPanel.shared.configure(container: container, launcher: launcher)
        // Shortcuts, Siri and Spotlight use the same store and launcher as the windows.
        let container = container
        AppDependencyManager.shared.add(dependency: container)
        AppDependencyManager.shared.add(dependency: launcher)
        AppDelegate.urlHandler = { url in
            Task { await ConnectURL.handle(url, container: container, launcher: launcher) }
        }
    }

    private static func makeContainer() -> ModelContainer {
        do {
            #if DEBUG
            if DemoData.isEnabled {
                return try DemoData.makeContainer()
            }
            #endif
            return try AppSchema.container()
        } catch {
            fatalError("Could not open the connection store: \(error)")
        }
    }

    var body: some Scene {
        // A single window, so the menu bar's "Open Genius Remote" brings it back instead of adding another.
        Window("Genius Remote", id: MainWindow.id) {
            ContentView()
                .frame(minWidth: 720, minHeight: 440)
                .environment(launcher)
        }
        .defaultSize(width: 1040, height: 600)
        // Open the window on every launch, even if it was closed when the app last quit.
        .defaultLaunchBehavior(.presented)
        .modelContainer(container)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { AppUpdater.shared.checkForUpdates() }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Connection") { actions?.newConnection() }
                    .keyboardShortcut("n")
                    .disabled(actions == nil)
                Button("New Group") { actions?.newGroup() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(actions == nil)
                Divider()
                Button("Instant RDP…") { openWindow(id: InstantRDPWindow.id) }
                    .keyboardShortcut("n", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .importExport) {
                Button("Import…") { actions?.importBackup() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                    .disabled(actions == nil)
                Button("Export…") { actions?.exportBackup() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(actions == nil)
                Divider()
                Button("Import from SSH Config…") { actions?.importSSHConfig() }
                    .disabled(actions == nil)
                Button("Import .rdp Files…") { actions?.importRDPFiles() }
                    .disabled(actions == nil)
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copy Password") {
                    if let selectedConnection { launcher.copyPassword(for: selectedConnection) }
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(selectedConnection?.type.usesNetwork != true)
            }
        }

        WindowGroup(id: EditorWindow.id, for: EditorTarget.self) { $target in
            EditorWindowContent(target: target)
        }
        .modelContainer(container)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        Window("Instant RDP", id: InstantRDPWindow.id) {
            InstantRDPView()
                .environment(launcher)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView()
        }
        .modelContainer(container)

        MenuBarExtra("Genius Remote", systemImage: "network", isInserted: $showsMenuBarIcon) {
            MenuBarContent()
                .environment(launcher)
        }
        .modelContainer(container)
    }
}

enum MainWindow {
    static let id = "main"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by the app once its store and launcher exist.
    static var urlHandler: ((URL) -> Void)?

    /// `geniusremote://connect/…` links, such as the ones in exported shortcuts.
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { Self.urlHandler?($0) }
    }

    /// Keep running in the menu bar after the window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

/// Window actions exposed to the menu bar commands.
struct AppActions {
    var newConnection: () -> Void
    var newGroup: () -> Void
    var importBackup: () -> Void
    var importSSHConfig: () -> Void
    var importRDPFiles: () -> Void
    var exportBackup: () -> Void
}

extension FocusedValues {
    @Entry var appActions: AppActions?
    /// The connection selected in the main window's list, if exactly one is.
    @Entry var selectedConnection: Connection?
}
