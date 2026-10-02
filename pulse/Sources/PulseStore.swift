import Combine
import Foundation
import SwiftUI

@MainActor
final class PulseStore: ObservableObject {
    let bluetooth: HeartRateBluetoothManager
    let connectIQ: PulseConnectIQManager?

    @Published private(set) var snapshot: PulseSnapshot
    @Published private(set) var state: HeartRateBluetoothManager.ConnectionState
    @Published private(set) var devices: [HeartRateBluetoothManager.DiscoveredDevice]
    @Published private(set) var measurementCount: Int
    @Published private(set) var parseError: String?
    @Published private(set) var sourceName: String?
    @Published private(set) var connectIQState: PulseConnectIQManager.State = .idle
    @Published private(set) var connectIQDevices: [PulseConnectIQManager.DeviceChoice] = []

    let isDemo: Bool
    let isPrivacySafe: Bool

    var signalStatus: String {
        switch snapshot.state {
        case .live:
            return "Live"
        case .stale:
            return "Signal paused"
        case .waiting:
            if activeSource == .connectIQ {
                switch connectIQState {
                case .idle: return "Ready"
                case .awaitingDeviceAuthorization: return "Waiting for Garmin Connect"
                case .choosingDevice: return "Choose an authorized watch"
                case let .connecting(name): return "Connecting to \(name)"
                case let .checkingApp(name): return "Checking Pulse on \(name)"
                case .ready: return "Waiting for pulse"
                case .unavailable: return "Connect IQ unavailable"
                case .failed: return "Connect IQ issue"
                }
            }
            switch state {
            case .idle:
                return "Ready"
            case .scanning:
                return "Searching for sensors"
            case let .connecting(name):
                return "Connecting to \(name)"
            case let .discovering(name):
                return "Setting up \(name)"
            case .subscribed:
                return "Waiting for pulse"
            case .unavailable:
                return "Bluetooth unavailable"
            case .failed:
                return "Connection issue"
            }
        }
    }

    var measurementAgeText: String {
        guard let timestamp = snapshot.latestTimestamp else {
            return "No recent reading"
        }

        let seconds = max(0, Int(now.timeIntervalSince(timestamp).rounded(.down)))
        switch seconds {
        case 0...1:
            return "Just now"
        case 2..<60:
            return "\(seconds)s ago"
        default:
            let minutes = seconds / 60
            return "\(minutes)m ago"
        }
    }

    private enum DemoMode {
        case live
        case stale
    }

    private enum ActiveSource {
        case none
        case bluetooth
        case connectIQ
    }

    private let demoMode: DemoMode?
    private var signal = PulseSignal()
    private var cancellables: Set<AnyCancellable> = []
    private var refreshTimer: AnyCancellable?
    private var demoSequenceIndex = 0
    private var now: Date
    private var hasPendingScanIntent = false
    private var isHandlingSceneSuspension = false
    private var previousBluetoothState: HeartRateBluetoothManager.ConnectionState?
    private var activeSource: ActiveSource = .none

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        bluetooth suppliedBluetooth: HeartRateBluetoothManager? = nil
    ) {
        let bluetooth = suppliedBluetooth ?? HeartRateBluetoothManager()
        let launchArguments = Set(arguments)
        let demoMode: DemoMode? = launchArguments.contains("--demo-stale")
            ? .stale
            : launchArguments.contains("--demo") ? .live : nil
        let initialNow = Date()
        var initialSignal = PulseSignal()

        self.bluetooth = bluetooth
        self.connectIQ = demoMode == nil ? PulseConnectIQManager() : nil
        self.demoMode = demoMode
        self.isDemo = demoMode != nil
        self.isPrivacySafe = launchArguments.contains("--privacy-safe-hardware-test")
        self.now = initialNow
        self.snapshot = initialSignal.snapshot(at: initialNow)
        self.state = demoMode == nil ? bluetooth.state : .idle
        self.devices = demoMode == nil ? bluetooth.devices : []
        self.measurementCount = 0
        self.parseError = demoMode == nil ? bluetooth.parseError : nil
        self.sourceName = demoMode == nil ? Self.sourceName(for: bluetooth.state) : nil
        self.signal = initialSignal

        if demoMode == nil {
            subscribeToBluetooth()
            subscribeToConnectIQ()
        } else {
            seedDemo(at: initialNow)
        }
        startRefreshTimer()
    }

    func startScan() {
        guard !isDemo else { return }
        activateBluetooth()
        hasPendingScanIntent = true
        bluetooth.startScan()
    }

    func stopScan() {
        guard !isDemo else { return }
        hasPendingScanIntent = false
        bluetooth.stopScan()
    }

    func connect(to device: HeartRateBluetoothManager.DiscoveredDevice) {
        guard !isDemo else { return }
        activateBluetooth()
        hasPendingScanIntent = false
        bluetooth.connect(to: device)
    }

    func disconnect() {
        guard !isDemo else { return }
        hasPendingScanIntent = false
        bluetooth.disconnect()
        if activeSource == .bluetooth {
            activeSource = .none
            clearSignal()
        }
    }

    func requestConnectIQAuthorization() {
        guard !isDemo, let connectIQ else { return }
        activateConnectIQ()
        connectIQ.requestDeviceSelection()
    }

    @discardableResult
    func handleConnectIQURL(_ url: URL) -> Bool {
        guard !isDemo, let connectIQ else { return false }
        return connectIQ.handleOpenURL(url)
    }

    func selectConnectIQDevice(_ device: PulseConnectIQManager.DeviceChoice) {
        guard !isDemo, let connectIQ else { return }
        activateConnectIQ()
        connectIQ.select(device)
    }

    func cancelConnectIQAuthorization() {
        connectIQ?.cancelDeviceSelectionRequest()
    }

    func openPulseOnWatch() {
        connectIQ?.openWatchApp()
    }

    func disconnectConnectIQ() {
        connectIQ?.disconnect()
        if activeSource == .connectIQ {
            activeSource = .none
            sourceName = nil
            clearSignal()
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        if isDemo {
            handleDemoScenePhase(phase)
            return
        }

        if phase == .background {
            hasPendingScanIntent = false
        }
        isHandlingSceneSuspension = phase != .active
        bluetooth.handleScenePhase(phase)
        if phase == .active {
            connectIQ?.resume()
        } else {
            connectIQ?.suspend()
        }
        isHandlingSceneSuspension = false

        guard phase == .active else {
            refreshTimer?.cancel()
            refreshTimer = nil
            clearSignal()
            return
        }

        now = Date()
        refreshSnapshot(at: now)
        if hasPendingScanIntent {
            bluetooth.startScan()
        }
        startRefreshTimer()
    }

    private func handleDemoScenePhase(_ phase: ScenePhase) {
        guard phase == .active else {
            refreshTimer?.cancel()
            refreshTimer = nil
            clearSignal()
            return
        }

        now = Date()
        seedDemo(at: now)
        startRefreshTimer()
    }

    private func subscribeToBluetooth() {
        bluetooth.$state
            .sink { [weak self] state in
                guard let self else { return }
                self.reconcileScanIntent(from: self.previousBluetoothState, to: state)
                self.previousBluetoothState = state
                self.state = state
                if self.activeSource != .connectIQ {
                    self.sourceName = Self.sourceName(for: state)
                }
            }
            .store(in: &cancellables)

        bluetooth.$devices
            .sink { [weak self] in self?.devices = $0 }
            .store(in: &cancellables)

        bluetooth.$parseError
            .sink { [weak self] error in
                guard let self else { return }
                guard self.activeSource == .bluetooth else { return }
                self.parseError = error
                guard error != nil else { return }
                let timestamp = Date()
                self.now = timestamp
                self.signal.ingest(bpm: nil, at: timestamp)
                self.refreshSnapshot(at: timestamp)
            }
            .store(in: &cancellables)

        bluetooth.$latestMeasurement
            .sink { [weak self] measurement in
                guard let self else { return }
                guard self.activeSource == .bluetooth else { return }
                let timestamp = Date()
                self.now = timestamp
                guard let measurement else {
                    self.signal.reset()
                    self.refreshSnapshot(at: timestamp)
                    return
                }
                self.signal.ingest(bpm: Int(measurement.beatsPerMinute), at: timestamp)
                self.refreshSnapshot(at: timestamp)
            }
            .store(in: &cancellables)
    }

    private func subscribeToConnectIQ() {
        guard let connectIQ else { return }

        connectIQ.$state
            .sink { [weak self] state in
                guard let self else { return }
                self.connectIQState = state
                guard self.activeSource == .connectIQ else { return }
                self.sourceName = self.connectIQ?.selectedDeviceName
            }
            .store(in: &cancellables)

        connectIQ.$authorizedDevices
            .sink { [weak self] devices in
                self?.connectIQDevices = devices
            }
            .store(in: &cancellables)

        connectIQ.$latestReading
            .sink { [weak self] reading in
                guard let self, self.activeSource == .connectIQ else { return }
                self.now = Date()
                guard let reading else {
                    self.signal.reset()
                    self.refreshSnapshot(at: self.now)
                    return
                }
                self.signal.ingest(bpm: reading.bpm, at: reading.timestamp)
                self.refreshSnapshot(at: self.now)
            }
            .store(in: &cancellables)
    }

    private func activateBluetooth() {
        guard activeSource != .bluetooth else { return }
        connectIQ?.disconnect()
        activeSource = .bluetooth
        sourceName = Self.sourceName(for: bluetooth.state)
        clearSignal()
    }

    private func activateConnectIQ() {
        guard activeSource != .connectIQ else { return }
        hasPendingScanIntent = false
        bluetooth.disconnect()
        activeSource = .connectIQ
        sourceName = connectIQ?.selectedDeviceName
        clearSignal()
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] timestamp in
                self?.refresh(at: timestamp)
            }
    }

    private func refresh(at timestamp: Date) {
        now = timestamp
        if demoMode == .live {
            signal.ingest(bpm: Self.demoBPM(at: demoSequenceIndex), at: timestamp)
            demoSequenceIndex += 1
        }
        refreshSnapshot(at: timestamp)
    }

    private func refreshSnapshot(at timestamp: Date) {
        snapshot = signal.snapshot(at: timestamp)
        measurementCount = signal.acceptedUpdateCount
    }

    private func clearSignal() {
        signal.reset()
        now = Date()
        snapshot = signal.snapshot(at: now)
        measurementCount = signal.acceptedUpdateCount
        parseError = nil
    }

    private func seedDemo(at timestamp: Date) {
        signal.reset()
        let latestTimestamp = demoMode == .stale
            ? timestamp.addingTimeInterval(-(PulseSignal.defaultFreshnessThreshold + 1))
            : timestamp

        for index in 0..<PulseSignal.maximumSampleCount {
            let sampleTimestamp = latestTimestamp.addingTimeInterval(
                TimeInterval(index - (PulseSignal.maximumSampleCount - 1))
            )
            signal.ingest(bpm: Self.demoBPM(at: index), at: sampleTimestamp)
        }

        demoSequenceIndex = PulseSignal.maximumSampleCount
        parseError = nil
        sourceName = "Synthetic demo"
        refreshSnapshot(at: timestamp)
    }

    private static func demoBPM(at index: Int) -> Int {
        let waveform = [
            73, 74, 75, 74, 76, 77, 76, 78, 79, 78,
            80, 79, 78, 77, 78, 76, 75, 76, 74, 73,
            74, 72, 71, 72, 70, 69, 70, 68, 69, 70,
            69, 71, 72, 71, 73, 74, 73, 75, 76, 75,
            77, 78, 77, 76, 78, 77, 75, 74, 75, 73,
            72, 74, 73, 71, 70, 71, 69, 70, 71, 72,
        ]
        return waveform[index % waveform.count]
    }

    private static func sourceName(
        for state: HeartRateBluetoothManager.ConnectionState
    ) -> String? {
        switch state {
        case let .connecting(name), let .discovering(name), let .subscribed(name):
            return name
        case .unavailable, .idle, .scanning, .failed:
            return nil
        }
    }

    private func reconcileScanIntent(
        from previousState: HeartRateBluetoothManager.ConnectionState?,
        to state: HeartRateBluetoothManager.ConnectionState
    ) {
        guard hasPendingScanIntent, !isHandlingSceneSuspension else { return }

        switch state {
        case .idle:
            if previousState == .scanning {
                hasPendingScanIntent = false
            }
        case let .unavailable(message):
            if !Self.isTransientBluetoothStatus(message) {
                hasPendingScanIntent = false
            }
        case .failed:
            hasPendingScanIntent = false
        case .scanning, .connecting, .discovering, .subscribed:
            break
        }
    }

    private static func isTransientBluetoothStatus(_ message: String) -> Bool {
        message == "Bluetooth status is not ready yet."
            || message == "Bluetooth is resetting."
    }
}
