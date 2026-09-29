import Foundation
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var bluetooth: HeartRateBluetoothManager
    @EnvironmentObject private var notifications: DiagnosticNotificationManager

    private var isPrivacySafeHardwareTest: Bool {
        ProcessInfo.processInfo.arguments.contains("--privacy-safe-hardware-test")
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Send notification to Garmin") {
                    Button("Request permission and notify in 5 seconds") {
                        notifications.requestAndSchedule()
                    }
                    .accessibilityIdentifier("notificationTestButton")
                    Text(notifications.status)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("notificationStatus")
                    Button("Check notification settings") {
                        notifications.checkNotificationSettings()
                    }
                    .accessibilityIdentifier("checkNotificationSettingsButton")
                    Text(notifications.settingsDiagnostic)
                        .font(.footnote.monospaced())
                        .accessibilityIdentifier("notificationSettingsOutput")
                    Button("Open this app's Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                    .accessibilityIdentifier("openNotificationSettingsButton")
                    Text("This sends a generic local notification without heart-rate data. Use the device currently connected to your Garmin. With the existing pairing and Smart Notifications enabled, the system may mirror the notification to the watch. Do not re-pair the watch for this test.")
                        .font(.footnote)
                    Text("Delivery on this iPhone or iPad does not prove delivery on the watch. Check the Garmin separately; a notification from a different, disconnected phone or tablet will not test the active connection.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Bluetooth status") {
                    Text(bluetooth.state.label)
                        .accessibilityIdentifier("bluetoothStatus")
                    HStack {
                        Button(bluetooth.state == .scanning ? "Stop scan" : "Scan for sensors") {
                            bluetooth.state == .scanning ? bluetooth.stopScan() : bluetooth.startScan()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("scanToggleButton")

                        Button("Disconnect", action: bluetooth.disconnect)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("disconnectButton")
                    }
                }

                Section("Heart-rate sensors") {
                    if bluetooth.devices.isEmpty {
                        Text("No devices found yet. Only devices advertising the standard Heart Rate Service (0x180D) are shown.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(bluetooth.devices) { device in
                        Button {
                            bluetooth.connect(to: device)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                    if !isPrivacySafeHardwareTest {
                                        Text(device.id.uuidString)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if !isPrivacySafeHardwareTest {
                                    Text("\(device.rssi) dBm")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("sensorRow")
                        .accessibilityLabel(device.name)
                    }
                }

                Section("Live foreground measurement") {
                    HStack {
                        Text("Valid measurements")
                        Spacer()
                        Text("\(bluetooth.validMeasurementCount)")
                            .accessibilityIdentifier("measurementCount")
                    }
                    if isPrivacySafeHardwareTest, bluetooth.latestMeasurement != nil {
                        Text("Measurement received")
                            .accessibilityIdentifier("measurementReceived")
                    } else if let measurement = bluetooth.latestMeasurement {
                        LabeledContent("Heart rate", value: "\(measurement.beatsPerMinute) BPM")
                        if let energy = measurement.energyExpended {
                            LabeledContent("Energy expended", value: "\(energy) kJ")
                        }
                        if measurement.rrIntervalsSeconds.isEmpty {
                            LabeledContent("RR intervals", value: "Not included")
                        } else {
                            LabeledContent(
                                "RR intervals",
                                value: measurement.rrIntervalsSeconds
                                    .map { String(format: "%.3f s", $0) }
                                    .joined(separator: ", ")
                            )
                        }
                    } else {
                        Text("Connect to a sensor to receive Heart Rate Measurement (0x2A37) notifications.")
                            .foregroundStyle(.secondary)
                    }
                    if let parseError = bluetooth.parseError {
                        Text(parseError)
                            .foregroundStyle(.red)
                    }
                }

                Section("Privacy and limits") {
                    Text("Foreground diagnostic only. Measurements are kept in memory, cleared when the app leaves the foreground or disconnects, and are never uploaded or stored.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Pulse HR Diagnostic")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HeartRateBluetoothManager())
        .environmentObject(DiagnosticNotificationManager())
}
