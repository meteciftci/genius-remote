import Foundation
import Sparkle

/// Checks GitHub Releases for a newer version through Sparkle. The feed address and the public
/// key that signed updates must match are in Info.plist (`SUFeedURL`, `SUPublicEDKey`).
@Observable
final class AppUpdater {
    static let shared = AppUpdater()

    private let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var automaticallyChecks: Bool {
        get {
            access(keyPath: \.automaticallyChecks)
            return controller.updater.automaticallyChecksForUpdates
        }
        set {
            withMutation(keyPath: \.automaticallyChecks) {
                controller.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
