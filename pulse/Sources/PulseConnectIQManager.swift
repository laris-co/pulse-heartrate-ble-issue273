import Combine
import Foundation
@preconcurrency import ConnectIQ

@MainActor
final class PulseConnectIQManager: NSObject, ObservableObject {
    static let callbackScheme = "pulselive-ciq"
    static let pulseAppUUID = UUID(uuidString: "32f2d775-1230-41a7-ac0c-38e3a3f4551b")!

    enum State: Equatable {
        case idle
        case awaitingDeviceAuthorization
        case choosingDevice
        case connecting(String)
        case checkingApp(String)
        case ready(String)
        case unavailable(String)
        case failed(String)
    }

    struct DeviceChoice: Identifiable {
        fileprivate let device: IQDevice
        let id: UUID
        let name: String

        fileprivate init(device: IQDevice) {
            self.device = device
            self.id = device.uuid
            let friendlyName = device.friendlyName.trimmingCharacters(in: .whitespacesAndNewlines)
            self.name = friendlyName.isEmpty ? device.modelName : friendlyName
        }
    }

    struct Reading: Equatable, Sendable {
        let bpm: Int?
        let timestamp: Date
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var authorizedDevices: [DeviceChoice] = []
    @Published private(set) var latestReading: Reading?
    @Published private(set) var transportDiagnostics = ""

    var selectedDeviceName: String? {
        selectedDevice.map(Self.deviceName)
    }

    private let sdk: ConnectIQ = ConnectIQ.sharedInstance()
    private let authorizationIntentStore = PulseConnectIQAuthorizationIntentStore()
    private var isInitialized = false
    private var isAwaitingSelectionResponse = false
    private var isForeground = true
    private var selectedDevice: IQDevice?
    private var pulseApp: IQApp?
    private var isCharacteristicsDiscovered = false
    private var isListeningForMessages = false
    private var pollTimer: Timer?
    private var watchdog: DispatchWorkItem?
    private var validator = PulseCompanionPacketValidator()
#if DEBUG
    private static var diagnosticEventCount = 0
    private static var queuedProbeAttempted = false
    private static var listenOnlyReadyLogged = false
    private let diagnosticsEnabled = ProcessInfo.processInfo.arguments.contains(
        "--privacy-safe-hardware-test"
    )
    private let queuedProbeRequested = ProcessInfo.processInfo.arguments.contains(
        "--ciq-single-queued-probe"
    )
    private let listenOnlyProbeRequested = ProcessInfo.processInfo.arguments.contains(
        "--ciq-listen-only-probe"
    )
#endif

    override init() {
        super.init()
        if authorizationIntentStore.hasValidIntent() {
            isAwaitingSelectionResponse = true
            state = .awaitingDeviceAuthorization
        }
    }

    func requestDeviceSelection() {
        if isAwaitingSelectionResponse, !authorizationIntentStore.hasValidIntent() {
            isAwaitingSelectionResponse = false
        }
        guard !isAwaitingSelectionResponse else { return }
        initializeIfNeeded()
        authorizationIntentStore.begin()
        isAwaitingSelectionResponse = true
        state = .awaitingDeviceAuthorization
        sdk.showDeviceSelection()
    }

    @discardableResult
    func handleOpenURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == Self.callbackScheme else { return false }
        initializeIfNeeded()
        guard authorizationIntentStore.consumeIfValid() else {
            isAwaitingSelectionResponse = false
            state = .failed("No Garmin authorization request is pending. Tap Authorize a Garmin watch and try again.")
            return true
        }

        isAwaitingSelectionResponse = false
        let parsed = sdk.parseDeviceSelectionResponse(from: url)
        guard let devices = parsed as? [IQDevice], !devices.isEmpty else {
            authorizedDevices = []
            state = .failed("No Garmin watch was authorized.")
            return true
        }

        stopConnection(clearSelection: true)
        authorizedDevices = devices.map(DeviceChoice.init(device:))
        state = .choosingDevice
        return true
    }

    func cancelDeviceSelectionRequest() {
        authorizationIntentStore.cancel()
        isAwaitingSelectionResponse = false
        state = .idle
    }

    func select(_ choice: DeviceChoice) {
        guard authorizedDevices.contains(where: { $0.id == choice.id }) else { return }
        stopConnection(clearSelection: true)
        selectedDevice = choice.device
        authorizedDevices = []
        startSelectedDeviceIfPossible()
    }

    func openWatchApp() {
        guard let pulseApp, isListeningForMessages else { return }
        sdk.openAppRequest(pulseApp) { [weak self] result in
            guard result != .failure_DeviceNotAvailable,
                  result != .failure_AppNotFound
            else {
                Task { @MainActor [weak self] in
                    self?.state = .failed("Pulse could not be opened on the watch.")
                }
                return
            }
        }
    }

    func suspend() {
        diagnostic("suspend")
        isForeground = false
        stopConnection(clearSelection: false)
        latestReading = nil
    }

    func resume() {
        diagnostic("resume")
        isForeground = true
        startSelectedDeviceIfPossible()
    }

    func disconnect() {
        authorizationIntentStore.cancel()
        isAwaitingSelectionResponse = false
        authorizedDevices = []
        stopConnection(clearSelection: true)
        state = .idle
        latestReading = nil
    }

    private func initializeIfNeeded() {
        guard !isInitialized else { return }
        sdk.initialize(withUrlScheme: Self.callbackScheme, uiOverrideDelegate: nil)
        isInitialized = true
    }

    private func startSelectedDeviceIfPossible() {
        guard isForeground, let selectedDevice else { return }
        initializeIfNeeded()
        state = .connecting(Self.deviceName(selectedDevice))
        isCharacteristicsDiscovered = false
        sdk.register(forDeviceEvents: selectedDevice, delegate: self)
    }

    private func prepareApp(on device: IQDevice) {
        guard isForeground,
              selectedDevice?.uuid == device.uuid,
              isCharacteristicsDiscovered
        else { return }

        let uuid = Self.pulseAppUUID
        let app = IQApp(uuid: uuid, store: uuid, device: device)
        pulseApp = app
        state = .checkingApp(Self.deviceName(device))
        sdk.getAppStatus(app) { [weak self, weak app] status in
            Task { @MainActor [weak self, weak app] in
                guard let self, let app,
                      self.isForeground,
                      self.pulseApp === app,
                      self.selectedDevice?.uuid == device.uuid
                else { return }

                guard let status, status.isInstalled else {
                    self.state = .unavailable("Pulse is not installed on this watch.")
                    self.publishUnavailable()
                    return
                }

                self.sdk.register(forAppMessages: app, delegate: self)
                self.isListeningForMessages = true
                self.diagnostic("messages_registered")
                self.state = .ready(Self.deviceName(device))
                self.startPolling()
            }
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
#if DEBUG
        if diagnosticsEnabled, listenOnlyProbeRequested {
            pollTimer = nil
            if !Self.listenOnlyReadyLogged {
                Self.listenOnlyReadyLogged = true
                diagnostic("listen_only_ready")
            }
            return
        }
#endif
        sendPollIfPossible()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sendPollIfPossible() }
        }
    }

    private func sendPollIfPossible() {
#if DEBUG
        if diagnosticsEnabled, queuedProbeRequested, Self.queuedProbeAttempted {
            return
        }
#endif
        guard isForeground, isListeningForMessages, let pulseApp,
              let request = validator.beginRequest(at: Date())
        else { return }

        let useQueuedProbe: Bool
#if DEBUG
        if diagnosticsEnabled, queuedProbeRequested, !Self.queuedProbeAttempted {
            Self.queuedProbeAttempted = true
            useQueuedProbe = true
        } else {
            useQueuedProbe = false
        }
#else
        useQueuedProbe = false
#endif
        scheduleWatchdog(for: request)
        diagnostic(
            "request_attempted",
            fields: ["queuedProbe": String(useQueuedProbe)]
        )
        sdk.sendMessage(
            request.message,
            to: pulseApp,
            progress: { _, _ in },
            completion: { [weak self] result in
                Task { @MainActor [weak self] in
                    self?.diagnostic(
                        "send_completion",
                        fields: ["status": String(describing: result)]
                    )
                    guard result != .success else { return }
                    guard let self,
                          self.validator.pendingRequest?.nonce == request.nonce
                    else { return }
                    self.watchdog?.cancel()
                    self.watchdog = nil
                    self.validator.cancelPendingRequest()
                    self.publishUnavailable()
                }
            },
            isTransient: !useQueuedProbe
        )
    }

    private func scheduleWatchdog(for request: PulseCompanionRequest) {
        watchdog?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self,
                      self.validator.pendingRequest?.nonce == request.nonce
                else { return }
                self.validator.expirePendingRequest(at: Date())
                self.watchdog = nil
                self.publishUnavailable()
            }
        }
        watchdog = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + PulseCompanionPacketValidator.maximumRoundTrip,
            execute: item
        )
    }

    private func stopConnection(clearSelection: Bool) {
        diagnostic(
            "stop_connection",
            fields: ["clearSelection": String(clearSelection)]
        )
        pollTimer?.invalidate()
        pollTimer = nil
        watchdog?.cancel()
        watchdog = nil
        validator.cancelPendingRequest()
        if let pulseApp, isListeningForMessages {
            sdk.unregister(forAppMessages: pulseApp, delegate: self)
        }
        sdk.unregister(forAllAppMessages: self)
        sdk.unregister(forAllDeviceEvents: self)
        pulseApp = nil
        isListeningForMessages = false
        isCharacteristicsDiscovered = false
        if clearSelection {
            selectedDevice = nil
        }
    }

    private static func deviceName(_ device: IQDevice) -> String {
        let friendlyName = device.friendlyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return friendlyName.isEmpty ? device.modelName : friendlyName
    }

    private func publishUnavailable() {
        diagnostic("unavailable")
        latestReading = Reading(bpm: nil, timestamp: Date())
    }

    private func diagnostic(_ event: String, fields: [String: String] = [:]) {
#if DEBUG
        guard diagnosticsEnabled, Self.diagnosticEventCount < 100 else { return }
        Self.diagnosticEventCount += 1
        let suffix = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = suffix.isEmpty
            ? "[PulseConnectIQ] event=\(event)"
            : "[PulseConnectIQ] event=\(event) \(suffix)"
        let recentLines = (transportDiagnostics.split(separator: "\n").map(String.init) + [line])
            .suffix(8)
        transportDiagnostics = recentLines.joined(separator: "\n")
        print(line)
#endif
    }
}

extension PulseConnectIQManager: IQDeviceEventDelegate {
    nonisolated func deviceStatusChanged(_ device: IQDevice!, status: IQDeviceStatus) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.diagnostic(
                "device_status_changed",
                fields: ["status": String(describing: status)]
            )
            guard let device, self.selectedDevice?.uuid == device.uuid else { return }
            switch status {
            case .bluetoothNotReady:
                self.state = .unavailable("Bluetooth is not ready for Garmin Connect IQ.")
                self.publishUnavailable()
            case .notFound:
                self.state = .unavailable("The selected Garmin watch was not found.")
                self.publishUnavailable()
            case .notConnected:
                self.state = .connecting(Self.deviceName(device))
                self.publishUnavailable()
            case .connected:
                // Connected alone is insufficient. Communication starts only
                // after deviceCharacteristicsDiscovered(_:).
                break
            default:
                break
            }
        }
    }

    nonisolated func deviceCharacteristicsDiscovered(_ device: IQDevice!) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.diagnostic("characteristics_discovered")
            guard let device, self.selectedDevice?.uuid == device.uuid else { return }
            self.isCharacteristicsDiscovered = true
            self.prepareApp(on: device)
        }
    }
}

extension PulseConnectIQManager: IQAppMessageDelegate {
    nonisolated func receivedMessage(_ message: Any!, from app: IQApp!) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let appUUIDMatches = app.map { $0.uuid as UUID == Self.pulseAppUUID } ?? false
            let selectedDeviceMatches = app.map {
                $0.device.uuid == self.selectedDevice?.uuid
            } ?? false
            let registeredAppMatches = app.map {
                self.pulseApp?.uuid == $0.uuid
                    && self.pulseApp?.device.uuid == $0.device.uuid
            } ?? false
            self.diagnostic("received_callback", fields: [
                "appMatch": String(appUUIDMatches),
                "registeredAppMatch": String(registeredAppMatches),
                "selectedDeviceMatch": String(selectedDeviceMatches),
            ])

            guard let message, let app,
                  self.isForeground,
                  self.isListeningForMessages,
                  self.pulseApp?.uuid == app.uuid,
                  self.pulseApp?.device.uuid == app.device.uuid,
                  app.uuid as UUID == Self.pulseAppUUID,
                  app.device.uuid == self.selectedDevice?.uuid
            else { return }

            if let linkTest = message as? String,
               linkTest == "pulse-link-watch-test" {
                self.diagnostic("link_test_callback")
            }

            let result = self.validator.validate(
                message,
                receivedAt: Date()
            )
            switch result {
            case let .success(reading):
                self.diagnostic("validator_result", fields: ["result": "accepted"])
                self.watchdog?.cancel()
                self.watchdog = nil
                self.latestReading = Reading(bpm: reading.bpm, timestamp: reading.measuredAt)
                self.diagnostic(
                    "accepted",
                    fields: ["hasBPM": String(reading.bpm != nil)]
                )
            case let .failure(rejection) where rejection.invalidatesCurrentSignal:
                self.diagnostic(
                    "validator_result",
                    fields: ["rejection": String(describing: rejection)]
                )
                self.watchdog?.cancel()
                self.watchdog = nil
                self.publishUnavailable()
            case let .failure(rejection):
                self.diagnostic(
                    "validator_result",
                    fields: ["rejection": String(describing: rejection)]
                )
            }
        }
    }
}
