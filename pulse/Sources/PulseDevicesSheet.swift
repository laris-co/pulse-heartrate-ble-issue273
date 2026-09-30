import SwiftUI

struct PulseDevicesSheet: View {
    @ObservedObject var store: PulseStore
    @Environment(\.dismiss) private var dismiss

    private var hasConnection: Bool {
        switch store.state {
        case .connecting, .discovering, .subscribed: true
        default: false
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.isDemo {
                    Section {
                        Label("You're exploring sample data", systemImage: "play.rectangle")
                        Text("Close and reopen Pulse normally to connect your own watch. Demo readings never come from a sensor.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    connectIQSection
                }

                if !store.isDemo, hasConnection {
                    Section("Your watch") {
                        Label(store.sourceName ?? "Heart-rate sensor", systemImage: "applewatch")
                        Text(store.signalStatus).foregroundStyle(.secondary)
                        Button("Disconnect", role: .destructive) {
                            store.disconnect()
                            dismiss()
                        }
                        .accessibilityIdentifier("disconnectButton")
                    }
                } else if !store.isDemo {
                    Section {
                        Label("Put your watch in Virtual Run", systemImage: "figure.run")
                            .font(.headline)
                        Text("On your Forerunner 245, press START, choose Virtual Run, and leave its pairing screen open. You don't need to start a workout.")
                        Text("Keep the watch nearby. Your existing Garmin pairing stays unchanged.")
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Alternative: Bluetooth sensor")
                    }

                    Section {
                        Button {
                            if store.state == .scanning { store.stopScan() }
                            else { store.startScan() }
                        } label: {
                            HStack {
                                Text(store.state == .scanning ? "Stop scan" : "Scan for sensors")
                                Spacer()
                                if store.state == .scanning { ProgressView() }
                                else { Image(systemName: "magnifyingglass") }
                            }
                            .frame(minHeight: 32)
                        }
                        .accessibilityIdentifier("scanToggleButton")

                        ForEach(store.devices) { device in
                            Button {
                                store.connect(to: device)
                            } label: {
                                Label(device.name, systemImage: "applewatch")
                                    .frame(minHeight: 32)
                            }
                            .accessibilityIdentifier("sensorRow")
                            .accessibilityLabel(device.name)
                        }

                        if store.devices.isEmpty {
                            Text(store.state == .scanning
                                 ? "Looking for a broadcasting heart-rate sensor…"
                                 : "Only broadcasting heart-rate sensors appear here. Tap Scan for sensors to begin.")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Nearby sensors")
                    } footer: {
                        Text("Scanning stops after 15 seconds. If nothing appears, check Virtual Run on the watch and try again.")
                    }
                }

                if !store.isDemo, let recoveryMessage {
                    Section("Connection") {
                        Text(recoveryMessage)
                        Text("Check Bluetooth permission in Settings → Apps → Pulse. Then return here and scan again.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Choose watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("dismissDevicesButton")
                }
            }
            .onChange(of: store.state) { _, state in
                if case .subscribed = state { dismiss() }
            }
            .onDisappear {
                store.stopScan()
            }
        }
    }

    @ViewBuilder
    private var connectIQSection: some View {
        Section {
            Text("Use the Pulse Link watch app with your existing Garmin pairing. Garmin Connect will ask which paired watch Pulse may use. Authorizing leaves the current sensor connection.")
                .foregroundStyle(.secondary)

            Button("Authorize a Garmin watch") {
                store.requestConnectIQAuthorization()
            }
            .accessibilityIdentifier("ciqAuthorizeButton")

            ForEach(store.connectIQDevices) { device in
                Button {
                    store.selectConnectIQDevice(device)
                } label: {
                    Label(device.name, systemImage: "applewatch")
                        .frame(minHeight: 32)
                }
                .accessibilityIdentifier("ciqDeviceRow")
                .accessibilityLabel(device.name)
            }

            switch store.connectIQState {
            case let .ready(name):
                Label(name, systemImage: "applewatch")
                    .accessibilityIdentifier("ciqConnectedWatch")
                Button("Open Pulse Link on watch") {
                    store.openPulseOnWatch()
                }
                .accessibilityIdentifier("ciqOpenWatchButton")
                Button("Disconnect Connect IQ", role: .destructive) {
                    store.disconnectConnectIQ()
                }
                .accessibilityIdentifier("ciqDisconnectButton")
            case .idle:
                EmptyView()
            case .awaitingDeviceAuthorization:
                Label("Waiting for Garmin Connect", systemImage: "hourglass")
                Button("Cancel authorization", role: .cancel) {
                    store.cancelConnectIQAuthorization()
                }
            case .choosingDevice:
                Text("Choose one authorized watch above.")
            case let .connecting(name):
                Text("Connecting to \(name)…")
            case let .checkingApp(name):
                Text("Checking Pulse on \(name)…")
            case let .unavailable(message), let .failed(message):
                Text(message).foregroundStyle(.secondary)
            }

            Text(connectIQStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("ciqStatus")
        } header: {
            Text("Pulse watch app")
        } footer: {
            Text("Pulse polls only while the Pulse app is in the foreground. You can still use the heart-rate sensor option below.")
        }
    }

    private var connectIQStatusText: String {
        switch store.connectIQState {
        case .idle: "Not connected"
        case .awaitingDeviceAuthorization: "Authorization in progress"
        case .choosingDevice: "Authorization returned"
        case .connecting: "Waiting for watch connection"
        case .checkingApp: "Watch connected"
        case .ready: "Ready for live pulse"
        case .unavailable: "Unavailable"
        case .failed: "Connection issue"
        }
    }

    private var recoveryMessage: String? {
        switch store.state {
        case let .failed(message), let .unavailable(message): message
        default: nil
        }
    }
}
