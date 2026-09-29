import CoreBluetooth
import Foundation
import SwiftUI

@MainActor
final class HeartRateBluetoothManager: NSObject, ObservableObject {
    struct DiscoveredDevice: Identifiable, Equatable {
        let id: UUID
        let name: String
        let rssi: Int
    }

    enum ConnectionState: Equatable {
        case unavailable(String)
        case idle
        case scanning
        case connecting(String)
        case discovering(String)
        case subscribed(String)
        case failed(String)

        var label: String {
            switch self {
            case let .unavailable(message): "Unavailable: \(message)"
            case .idle: "Idle"
            case .scanning: "Scanning for Heart Rate Service devices"
            case let .connecting(name): "Connecting to \(name)"
            case let .discovering(name): "Discovering services on \(name)"
            case let .subscribed(name): "Subscribed to \(name)"
            case let .failed(message): "Error: \(message)"
            }
        }
    }

    @Published private(set) var state: ConnectionState = .idle
    @Published private(set) var devices: [DiscoveredDevice] = []
    @Published private(set) var latestMeasurement: HeartRateMeasurement?
    @Published private(set) var validMeasurementCount = 0
    @Published private(set) var parseError: String?

    private static let heartRateService = CBUUID(string: "180D")
    private static let heartRateMeasurement = CBUUID(string: "2A37")
    private static let scanTimeout: TimeInterval = 15
    private static let connectionTimeout: TimeInterval = 15

    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var activePeripheral: CBPeripheral?
    private var disconnectingPeripheralIDs: Set<UUID> = []
    private var scanTimeoutTask: Task<Void, Never>?
    private var connectionTimeoutTask: Task<Void, Never>?
    private var isForeground = true
    private var scanRequested = false

    func startScan() {
        guard isForeground else {
            state = .failed("Scanning is available only while the app is in the foreground.")
            return
        }
        scanRequested = true
        let central = centralManager()
        guard central.state == .poweredOn else {
            if central.state != .unknown && central.state != .resetting {
                scanRequested = false
            }
            updateAvailability(for: central.state)
            return
        }

        beginScan(with: central)
    }

    private func beginScan(with central: CBCentralManager) {
        guard scanRequested, isForeground else { return }
        scanRequested = false
        disconnectActivePeripheral()
        devices.removeAll()
        peripherals.removeAll()
        latestMeasurement = nil
        validMeasurementCount = 0
        parseError = nil
        central.scanForPeripherals(
            withServices: [Self.heartRateService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        state = .scanning
        scheduleScanTimeout()
    }

    func stopScan() {
        scanRequested = false
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
        guard let central else { return }
        if central.isScanning {
            central.stopScan()
        }
        if state == .scanning {
            state = .idle
        }
    }

    func connect(to device: DiscoveredDevice) {
        guard let central, isForeground, central.state == .poweredOn else {
            state = .failed("Bluetooth connection requires the app to be foregrounded with Bluetooth on.")
            return
        }
        guard let peripheral = peripherals[device.id] else {
            state = .failed("That scan result is no longer available. Scan again.")
            return
        }
        guard activePeripheral == nil else {
            state = .failed("Disconnect the current sensor before choosing another one.")
            return
        }
        guard !disconnectingPeripheralIDs.contains(device.id) else {
            state = .failed("Waiting for that sensor to finish disconnecting. Try again in a moment.")
            return
        }

        stopScan()
        activePeripheral = peripheral
        peripheral.delegate = self
        latestMeasurement = nil
        validMeasurementCount = 0
        parseError = nil
        state = .connecting(device.name)
        central.connect(peripheral)
        scheduleConnectionTimeout(for: peripheral)
    }

    func disconnect() {
        stopScan()
        disconnectActivePeripheral()
        state = central?.state == .poweredOn ? .idle : state
    }

    func handleScenePhase(_ phase: ScenePhase) {
        isForeground = phase == .active
        guard !isForeground else { return }
        stopScan()
        disconnectActivePeripheral()
        latestMeasurement = nil
        validMeasurementCount = 0
        state = .idle
    }

    private func scheduleScanTimeout() {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.scanTimeout))
            guard !Task.isCancelled else { return }
            self?.stopScan()
        }
    }

    private func scheduleConnectionTimeout(for peripheral: CBPeripheral) {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = Task { [weak self, weak peripheral] in
            try? await Task.sleep(for: .seconds(Self.connectionTimeout))
            guard !Task.isCancelled,
                  let self,
                  let peripheral,
                  self.activePeripheral === peripheral else { return }
            self.state = .failed("Connection timed out.")
            self.disconnectActivePeripheral()
        }
    }

    private func disconnectActivePeripheral() {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        latestMeasurement = nil
        validMeasurementCount = 0
        parseError = nil
        guard let central, let peripheral = activePeripheral else { return }
        peripheral.delegate = nil
        disconnectingPeripheralIDs.insert(peripheral.identifier)
        central.cancelPeripheralConnection(peripheral)
        activePeripheral = nil
    }

    private func name(for peripheral: CBPeripheral) -> String {
        peripheral.name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? "Unnamed sensor"
    }

    private func centralManager() -> CBCentralManager {
        if let central { return central }
        let manager = CBCentralManager(delegate: self, queue: .main)
        central = manager
        return manager
    }

    private func updateAvailability(for bluetoothState: CBManagerState) {
        state = switch bluetoothState {
        case .poweredOn: .idle
        case .poweredOff: .unavailable("Bluetooth is off.")
        case .unauthorized: .unavailable("Bluetooth permission is denied. Enable it in Settings.")
        case .unsupported: .unavailable("Bluetooth Low Energy is not supported on this device.")
        case .resetting: .unavailable("Bluetooth is resetting.")
        case .unknown: .unavailable("Bluetooth status is not ready yet.")
        @unknown default: .unavailable("Unknown Bluetooth state.")
        }
    }
}

extension HeartRateBluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor [weak self] in
            guard let self, central === self.central else { return }
            switch central.state {
            case .poweredOn:
                if self.scanRequested, self.isForeground {
                    self.beginScan(with: central)
                    return
                }
            case .unknown, .resetting:
                break
            case .poweredOff, .unauthorized, .unsupported:
                self.stopScan()
                self.disconnectActivePeripheral()
                self.disconnectingPeripheralIDs.removeAll()
            @unknown default:
                self.stopScan()
            }
            self.updateAvailability(for: central.state)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor [weak self] in
            guard let self, central === self.central, self.state == .scanning else { return }
            self.peripherals[peripheral.identifier] = peripheral
            let result = DiscoveredDevice(
                id: peripheral.identifier,
                name: self.name(for: peripheral),
                rssi: RSSI.intValue
            )
            if let index = self.devices.firstIndex(where: { $0.id == result.id }) {
                self.devices[index] = result
            } else {
                self.devices.append(result)
                self.devices.sort { $0.rssi > $1.rssi }
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor [weak self] in
            guard let self,
                  central === self.central,
                  self.activePeripheral === peripheral else { return }
            self.connectionTimeoutTask?.cancel()
            self.state = .discovering(self.name(for: peripheral))
            peripheral.discoverServices([Self.heartRateService])
            self.scheduleConnectionTimeout(for: peripheral)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self, central === self.central else { return }
            self.disconnectingPeripheralIDs.remove(peripheral.identifier)
            guard self.activePeripheral === peripheral else { return }
            self.connectionTimeoutTask?.cancel()
            self.activePeripheral = nil
            self.state = .failed(error?.localizedDescription ?? "Could not connect to the sensor.")
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self, central === self.central else { return }
            self.disconnectingPeripheralIDs.remove(peripheral.identifier)
            guard self.activePeripheral === peripheral else { return }
            self.connectionTimeoutTask?.cancel()
            self.activePeripheral = nil
            self.latestMeasurement = nil
            self.validMeasurementCount = 0
            self.parseError = nil
            self.state = error.map { .failed("Disconnected: \($0.localizedDescription)") } ?? .idle
        }
    }
}

extension HeartRateBluetoothManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.activePeripheral === peripheral else { return }
            if let error {
                self.state = .failed("Service discovery failed: \(error.localizedDescription)")
                self.disconnectActivePeripheral()
                return
            }
            guard let service = peripheral.services?.first(where: { $0.uuid == Self.heartRateService }) else {
                self.state = .failed("The Heart Rate Service was not found.")
                self.disconnectActivePeripheral()
                return
            }
            peripheral.discoverCharacteristics([Self.heartRateMeasurement], for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self,
                  self.activePeripheral === peripheral,
                  service.uuid == Self.heartRateService else { return }
            if let error {
                self.state = .failed("Characteristic discovery failed: \(error.localizedDescription)")
                self.disconnectActivePeripheral()
                return
            }
            guard let characteristic = service.characteristics?.first(where: {
                $0.uuid == Self.heartRateMeasurement && $0.properties.contains(.notify)
            }) else {
                self.state = .failed("A notifiable Heart Rate Measurement characteristic was not found.")
                self.disconnectActivePeripheral()
                return
            }
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self,
                  self.activePeripheral === peripheral,
                  characteristic.uuid == Self.heartRateMeasurement else { return }
            self.connectionTimeoutTask?.cancel()
            if let error {
                self.state = .failed("Subscription failed: \(error.localizedDescription)")
                self.disconnectActivePeripheral()
            } else if characteristic.isNotifying {
                self.state = .subscribed(self.name(for: peripheral))
            } else {
                self.state = .failed("The sensor declined heart-rate notifications.")
                self.disconnectActivePeripheral()
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self,
                  self.activePeripheral === peripheral,
                  characteristic.uuid == Self.heartRateMeasurement else { return }
            if let error {
                self.parseError = "Measurement update failed: \(error.localizedDescription)"
                return
            }
            guard let data = characteristic.value else {
                self.parseError = "The sensor sent an empty measurement."
                return
            }
            do {
                self.latestMeasurement = try HeartRateMeasurementParser.parse(data)
                self.validMeasurementCount += 1
                self.parseError = nil
            } catch {
                self.parseError = String(describing: error)
            }
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
