import UIKit

/// Captures the APNs device token once the OS hands it over (after
/// `UIApplication.shared.registerForRemoteNotifications()` is called from
/// NotificationPermissionView) and registers it with the backend.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            do {
                try await Backend.shared.registerDeviceToken(token: token)
            } catch {
                // Was `try?`. A failure here meant the device was
                // unreachable for as long as the app stayed installed, and
                // nothing said so. AppState.registerForPushIfAuthorized
                // re-requests the token on every launch, so a failure is
                // now transient — but it should still be visible.
                print("register-device-token failed: \(error)")
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected in Simulator (no real APNs token available there) and
        // harmless if the user later denies notification permission.
    }
}
