import Foundation
import UserNotifications

@MainActor
final class DiagnosticNotificationManager: NSObject, ObservableObject {
    private static let requestIdentifier = "pulse-garmin-relay-diagnostic"

    @Published private(set) var status = "Not requested"
    @Published private(set) var settingsDiagnostic = "Notification settings not checked."

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAndSchedule() {
        Task {
            do {
                let center = UNUserNotificationCenter.current()
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                guard granted else {
                    status = "Notification permission was not granted."
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = "Pulse diagnostic"
                content.body = "Local notification delivery test. No heart-rate data is included."
                content.sound = .default
                center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
                center.removeDeliveredNotifications(withIdentifiers: [Self.requestIdentifier])
                let request = UNNotificationRequest(
                    identifier: Self.requestIdentifier,
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                )
                try await center.add(request)
                status = "Generic notification scheduled for 5 seconds from now."
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                let deliveredOnDevice = await center.deliveredNotifications()
                    .contains { $0.request.identifier == Self.requestIdentifier }
                status = deliveredOnDevice
                    ? "Local notification delivered on this device. Garmin delivery is not verified."
                    : "Notification scheduled; device delivery is not yet confirmed. Garmin delivery is not verified."
            } catch {
                status = "Notification error: \(error.localizedDescription)"
            }
        }
    }

    func checkNotificationSettings() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            var lines = [
                "Authorization: \(authorizationDescription(settings.authorizationStatus))",
                "Notification Center: \(settingDescription(settings.notificationCenterSetting))",
                "Alerts: \(settingDescription(settings.alertSetting))",
                "Lock Screen: \(settingDescription(settings.lockScreenSetting))",
                "Show Previews: \(previewDescription(settings.showPreviewsSetting))"
            ]

            if settings.notificationCenterSetting == .disabled {
                lines.append("Warning: Notification Center is disabled for this app. Garmin Smart Notifications require it to be enabled on the paired iPhone.")
            }
            if settings.showPreviewsSetting == .never {
                lines.append("Warning: Show Previews is set to Never. Garmin Smart Notifications require notification previews to be available on the paired iPhone.")
            }
            if settings.authorizationStatus == .denied {
                lines.append("Warning: Notifications are denied for this app. Open this app's Settings to change them manually.")
            }

            settingsDiagnostic = lines.joined(separator: "\n")
        }
    }

    private func authorizationDescription(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "Not determined"
        case .denied: "Denied"
        case .authorized: "Authorized"
        case .provisional: "Provisional"
        case .ephemeral: "Ephemeral"
        @unknown default: "Unknown"
        }
    }

    private func settingDescription(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: "Not supported"
        case .disabled: "Disabled"
        case .enabled: "Enabled"
        @unknown default: "Unknown"
        }
    }

    private func previewDescription(_ setting: UNShowPreviewsSetting) -> String {
        switch setting {
        case .always: "Always"
        case .whenAuthenticated: "When unlocked"
        case .never: "Never"
        @unknown default: "Unknown"
        }
    }
}

extension DiagnosticNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
