import CoreFoundation
import Foundation

struct PulseCompanionRequest: Equatable, Sendable {
    let nonce: UUID
    let sentAt: Date

    var message: [String: Any] {
        [
            "v": 1,
            "type": "request",
            "nonce": nonce.uuidString,
        ]
    }
}

struct PulseCompanionReading: Equatable, Sendable {
    let bpm: Int?
    let measuredAt: Date
}

enum PulseCompanionPacketRejection: Error, Equatable, Sendable {
    case noPendingRequest
    case malformed
    case wrongNonce
    case expired
    case replay

    var invalidatesCurrentSignal: Bool {
        self == .expired
    }
}

/// Persists only the time at which Pulse launched Garmin's authorization UI.
/// The marker is one-use and short-lived so a legitimate GCM callback can be
/// accepted after iOS terminates and relaunches Pulse, without persisting any
/// device identifiers or health data.
struct PulseConnectIQAuthorizationIntentStore {
    static let lifetime: TimeInterval = 5 * 60

    private static let key = "PulseConnectIQ.pendingAuthorization.startedAt"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func begin(at now: Date = Date()) {
        defaults.set(now.timeIntervalSince1970, forKey: Self.key)
    }

    func hasValidIntent(at now: Date = Date()) -> Bool {
        guard let startedAt = startedAt else { return false }
        let age = now.timeIntervalSince(startedAt)
        guard age >= 0, age <= Self.lifetime else {
            cancel()
            return false
        }
        return true
    }

    /// Atomically consumes the marker whether it is valid or expired.
    func consumeIfValid(at now: Date = Date()) -> Bool {
        guard let startedAt = startedAt else { return false }
        cancel()
        let age = now.timeIntervalSince(startedAt)
        return age >= 0 && age <= Self.lifetime
    }

    func cancel() {
        defaults.removeObject(forKey: Self.key)
    }

    private var startedAt: Date? {
        guard defaults.object(forKey: Self.key) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: Self.key))
    }
}

struct PulseCompanionPacketValidator: Sendable {
    static let maximumRoundTrip: TimeInterval = 3
    static let maximumReadingAgeMilliseconds = 3_000

    private(set) var pendingRequest: PulseCompanionRequest?
    private var lastConsumedNonce: UUID?

    mutating func beginRequest(
        nonce: UUID = UUID(),
        at sentAt: Date
    ) -> PulseCompanionRequest? {
        guard pendingRequest == nil, lastConsumedNonce != nonce else { return nil }
        let request = PulseCompanionRequest(nonce: nonce, sentAt: sentAt)
        pendingRequest = request
        return request
    }

    mutating func expirePendingRequest(at now: Date) {
        guard let pendingRequest,
              now.timeIntervalSince(pendingRequest.sentAt) >= Self.maximumRoundTrip
        else { return }
        self.pendingRequest = nil
    }

    mutating func cancelPendingRequest() {
        pendingRequest = nil
    }

    mutating func validate(
        _ message: Any,
        receivedAt: Date
    ) -> Result<PulseCompanionReading, PulseCompanionPacketRejection> {
        guard let fields = message as? [AnyHashable: Any],
              fields.count == 5,
              integer(fields["v"]) == 1,
              fields["type"] as? String == "pulse",
              let nonceText = fields["nonce"] as? String,
              let nonce = UUID(uuidString: nonceText),
              let bpm = integer(fields["bpm"]),
              let ageMilliseconds = integer(fields["ageMs"]),
              ageMilliseconds >= 0,
              (0...65_535).contains(bpm)
        else {
            return .failure(.malformed)
        }

        if lastConsumedNonce == nonce {
            return .failure(.replay)
        }
        guard let pendingRequest else {
            return .failure(.noPendingRequest)
        }
        guard nonce == pendingRequest.nonce else {
            return .failure(.wrongNonce)
        }

        let roundTrip = receivedAt.timeIntervalSince(pendingRequest.sentAt)
        guard roundTrip >= 0, roundTrip <= Self.maximumRoundTrip else {
            self.pendingRequest = nil
            return .failure(.expired)
        }

        guard bpm == 0 || ageMilliseconds <= Self.maximumReadingAgeMilliseconds else {
            self.pendingRequest = nil
            lastConsumedNonce = nonce
            return .failure(.expired)
        }

        self.pendingRequest = nil
        lastConsumedNonce = nonce
        // Anchor age to request transmission rather than receipt. This is
        // intentionally conservative: transport time can never make old sensor
        // data appear newer than it was when the watch formed its reply.
        let measuredAt = bpm == 0
            ? receivedAt
            : pendingRequest.sentAt.addingTimeInterval(-TimeInterval(ageMilliseconds) / 1_000)
        return .success(PulseCompanionReading(
            bpm: bpm == 0 ? nil : bpm,
            measuredAt: measuredAt
        ))
    }

    private func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID()
        else { return nil }

        let type = String(cString: number.objCType)
        guard ["c", "s", "i", "l", "q", "C", "S", "I", "L", "Q"].contains(type) else {
            return nil
        }

        let value = number.int64Value
        guard value >= Int64(Int.min), value <= Int64(Int.max) else { return nil }
        return Int(value)
    }
}
