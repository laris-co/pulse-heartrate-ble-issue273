import Foundation
import Testing
@testable import PulseSignal

struct PulseCompanionPacketTests {
    private let sentAt = Date(timeIntervalSince1970: 1_000)
    private let nonce = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    @Test func acceptsFreshPulse() throws {
        var validator = PulseCompanionPacketValidator()
        #expect(validator.beginRequest(nonce: nonce, at: sentAt) != nil)

        let reading = try validator.validate(
            packet(bpm: 72, ageMilliseconds: 250),
            receivedAt: sentAt.addingTimeInterval(1)
        ).get()

        #expect(reading.bpm == 72)
        #expect(reading.measuredAt == sentAt.addingTimeInterval(-0.25))
    }

    @Test func zeroSignalsUnavailable() throws {
        var validator = PulseCompanionPacketValidator()
        _ = validator.beginRequest(nonce: nonce, at: sentAt)

        let reading = try validator.validate(
            packet(bpm: 0, ageMilliseconds: 4_000),
            receivedAt: sentAt.addingTimeInterval(1)
        ).get()

        #expect(reading.bpm == nil)
        #expect(reading.measuredAt == sentAt.addingTimeInterval(1))
    }

    @Test func rejectsStaleRoundTripAndReadingAge() {
        var roundTripValidator = PulseCompanionPacketValidator()
        _ = roundTripValidator.beginRequest(nonce: nonce, at: sentAt)
        #expect(roundTripValidator.validate(
            packet(bpm: 72, ageMilliseconds: 0),
            receivedAt: sentAt.addingTimeInterval(3.001)
        ) == .failure(.expired))

        var ageValidator = PulseCompanionPacketValidator()
        _ = ageValidator.beginRequest(nonce: nonce, at: sentAt)
        #expect(ageValidator.validate(
            packet(bpm: 72, ageMilliseconds: 3_001),
            receivedAt: sentAt.addingTimeInterval(1)
        ) == .failure(.expired))
        #expect(ageValidator.pendingRequest == nil)
    }

    @Test func expiredMatchedReplyInvalidatesCurrentSignal() {
        var validator = PulseCompanionPacketValidator()
        _ = validator.beginRequest(nonce: nonce, at: sentAt)

        let result = validator.validate(
            packet(bpm: 72, ageMilliseconds: 3_001),
            receivedAt: sentAt.addingTimeInterval(1)
        )

        guard case let .failure(rejection) = result else {
            Issue.record("Expected an expired matched reply")
            return
        }
        #expect(rejection.invalidatesCurrentSignal)
        #expect(!PulseCompanionPacketRejection.malformed.invalidatesCurrentSignal)
        #expect(!PulseCompanionPacketRejection.wrongNonce.invalidatesCurrentSignal)
        #expect(!PulseCompanionPacketRejection.replay.invalidatesCurrentSignal)
    }

    @Test func authorizationIntentSurvivesColdLaunchAndIsConsumedOnce() throws {
        let suiteName = "PulseCompanionPacketTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        PulseConnectIQAuthorizationIntentStore(defaults: defaults).begin(at: sentAt)

        // A newly constructed store models a fresh process after iOS relaunches
        // the app for Garmin Connect's callback.
        let coldLaunchStore = PulseConnectIQAuthorizationIntentStore(defaults: defaults)
        #expect(coldLaunchStore.consumeIfValid(at: sentAt.addingTimeInterval(30)))
        #expect(!coldLaunchStore.consumeIfValid(at: sentAt.addingTimeInterval(31)))
    }

    @Test func authorizationIntentExpiresAndCancelConsumesIt() throws {
        let suiteName = "PulseCompanionPacketTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = PulseConnectIQAuthorizationIntentStore(defaults: defaults)

        store.begin(at: sentAt)
        #expect(!store.consumeIfValid(
            at: sentAt.addingTimeInterval(PulseConnectIQAuthorizationIntentStore.lifetime + 1)
        ))

        store.begin(at: sentAt)
        store.cancel()
        #expect(!store.consumeIfValid(at: sentAt.addingTimeInterval(1)))
    }

    @Test func rejectsReplay() {
        var validator = PulseCompanionPacketValidator()
        _ = validator.beginRequest(nonce: nonce, at: sentAt)
        let message = packet(bpm: 72, ageMilliseconds: 0)
        #expect(validator.validate(message, receivedAt: sentAt.addingTimeInterval(1)).isSuccess)
        #expect(validator.validate(message, receivedAt: sentAt.addingTimeInterval(2)) == .failure(.replay))
    }

    @Test func rejectsWrongNonceWithoutConsumingLatestRequest() {
        var validator = PulseCompanionPacketValidator()
        _ = validator.beginRequest(nonce: nonce, at: sentAt)
        let wrong = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        #expect(validator.validate(
            packet(nonce: wrong, bpm: 72, ageMilliseconds: 0),
            receivedAt: sentAt.addingTimeInterval(1)
        ) == .failure(.wrongNonce))
        #expect(validator.validate(
            packet(bpm: 73, ageMilliseconds: 0),
            receivedAt: sentAt.addingTimeInterval(2)
        ).isSuccess)
    }

    @Test func wrongNonceTakesPrecedenceOverStalenessAndPreservesPendingRequest() {
        var validator = PulseCompanionPacketValidator()
        let pending = validator.beginRequest(nonce: nonce, at: sentAt)
        let wrong = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        let staleAge = validator.validate(
            packet(nonce: wrong, bpm: 72, ageMilliseconds: 3_001),
            receivedAt: sentAt.addingTimeInterval(1)
        )
        #expect(staleAge == .failure(.wrongNonce))
        #expect(validator.pendingRequest == pending)
        #expect(!PulseCompanionPacketRejection.wrongNonce.invalidatesCurrentSignal)

        let lateReceipt = validator.validate(
            packet(nonce: wrong, bpm: 72, ageMilliseconds: 0),
            receivedAt: sentAt.addingTimeInterval(3.001)
        )
        #expect(lateReceipt == .failure(.wrongNonce))
        #expect(validator.pendingRequest == pending)
    }

    @Test func noPendingRequestTakesPrecedenceOverStaleness() {
        var validator = PulseCompanionPacketValidator()

        let result = validator.validate(
            packet(bpm: 72, ageMilliseconds: 3_001),
            receivedAt: sentAt.addingTimeInterval(4)
        )

        #expect(result == .failure(.noPendingRequest))
        #expect(!PulseCompanionPacketRejection.noPendingRequest.invalidatesCurrentSignal)
    }

    @Test func replayTakesPrecedenceOverStalenessAndPreservesNewPendingRequest() {
        var validator = PulseCompanionPacketValidator()
        _ = validator.beginRequest(nonce: nonce, at: sentAt)
        #expect(validator.validate(
            packet(bpm: 72, ageMilliseconds: 0),
            receivedAt: sentAt.addingTimeInterval(1)
        ).isSuccess)

        let nextNonce = UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        let nextPending = validator.beginRequest(
            nonce: nextNonce,
            at: sentAt.addingTimeInterval(2)
        )
        let replay = validator.validate(
            packet(bpm: 72, ageMilliseconds: 3_001),
            receivedAt: sentAt.addingTimeInterval(4)
        )

        #expect(replay == .failure(.replay))
        #expect(validator.pendingRequest == nextPending)
        #expect(!PulseCompanionPacketRejection.replay.invalidatesCurrentSignal)
    }

    @Test func matchedNonceRoundTripAndAgeExpiryBothInvalidate() {
        var roundTripValidator = PulseCompanionPacketValidator()
        _ = roundTripValidator.beginRequest(nonce: nonce, at: sentAt)
        let lateReceipt = roundTripValidator.validate(
            packet(bpm: 72, ageMilliseconds: 0),
            receivedAt: sentAt.addingTimeInterval(3.001)
        )
        #expect(lateReceipt == .failure(.expired))
        #expect(roundTripValidator.pendingRequest == nil)

        var ageValidator = PulseCompanionPacketValidator()
        _ = ageValidator.beginRequest(nonce: nonce, at: sentAt)
        let staleAge = ageValidator.validate(
            packet(bpm: 72, ageMilliseconds: 3_001),
            receivedAt: sentAt.addingTimeInterval(1)
        )
        #expect(staleAge == .failure(.expired))
        #expect(ageValidator.pendingRequest == nil)
        #expect(PulseCompanionPacketRejection.expired.invalidatesCurrentSignal)
    }

    @Test func rejectsIncorrectFieldTypes() {
        let invalidPackets: [[String: Any]] = [
            packet(bpm: 72, ageMilliseconds: 0).merging(["v": "1"]) { _, new in new },
            packet(bpm: 72, ageMilliseconds: 0).merging(["bpm": 72.0]) { _, new in new },
            packet(bpm: 72, ageMilliseconds: 0).merging(["ageMs": true]) { _, new in new },
            packet(bpm: 72, ageMilliseconds: 0).merging(["extra": 1]) { _, new in new },
        ]

        for invalidPacket in invalidPackets {
            var validator = PulseCompanionPacketValidator()
            _ = validator.beginRequest(nonce: nonce, at: sentAt)
            #expect(validator.validate(
                invalidPacket,
                receivedAt: sentAt.addingTimeInterval(1)
            ) == .failure(.malformed))
        }
    }

    private func packet(
        nonce: UUID? = nil,
        bpm: Any,
        ageMilliseconds: Any
    ) -> [String: Any] {
        [
            "v": 1,
            "type": "pulse",
            "nonce": (nonce ?? self.nonce).uuidString,
            "bpm": bpm,
            "ageMs": ageMilliseconds,
        ]
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { true } else { false }
    }
}
