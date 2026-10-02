import Foundation

public enum PulseSignalState: Equatable, Sendable {
    case waiting
    case live
    case stale
}

public struct PulseSample: Equatable, Sendable {
    public let bpm: Int
    public let timestamp: Date
    public let segmentID: Int

    public init(bpm: Int, timestamp: Date, segmentID: Int = 0) {
        self.bpm = bpm
        self.timestamp = timestamp
        self.segmentID = segmentID
    }
}

public struct PulseSnapshot: Equatable, Sendable {
    public let state: PulseSignalState
    public let liveBPM: Int?
    public let latestBPM: Int?
    public let latestTimestamp: Date?
    public let samples: [PulseSample]
    public let minimumBPM: Int?
    public let maximumBPM: Int?
}

/// An in-memory, presentation-ready view of recent pulse readings.
///
/// Feed each manager measurement to `ingest(bpm:at:)`, then request a
/// deterministic `snapshot(at:)` whenever the presentation clock advances.
/// Non-positive or missing BPM values are treated as unavailable readings.
public struct PulseSignal: Sendable {
    public static let defaultFreshnessThreshold: TimeInterval = 5
    public static let historyWindow: TimeInterval = 60
    public static let maximumSampleCount = 60

    public let freshnessThreshold: TimeInterval
    public private(set) var acceptedUpdateCount = 0

    private var storedSamples: [PulseSample] = []
    private var latestObservation: Observation?
    private var currentSegmentID = 0

    public init(freshnessThreshold: TimeInterval = defaultFreshnessThreshold) {
        precondition(
            freshnessThreshold.isFinite && freshnessThreshold >= 0,
            "freshnessThreshold must be finite and non-negative"
        )
        self.freshnessThreshold = freshnessThreshold
    }

    /// Records one observation. Readings at the same timestamp replace the
    /// previous reading, so duplicate publisher delivery cannot skew history.
    public mutating func ingest(bpm: Int?, at timestamp: Date) {
        let validBPM = bpm.flatMap { $0 > 0 ? $0 : nil }

        if let index = storedSamples.firstIndex(where: { $0.timestamp == timestamp }) {
            storedSamples.remove(at: index)
        }
        if let validBPM {
            storedSamples.append(PulseSample(
                bpm: validBPM,
                timestamp: timestamp,
                segmentID: currentSegmentID
            ))
            storedSamples.sort { $0.timestamp < $1.timestamp }
            if storedSamples.count > Self.maximumSampleCount {
                storedSamples.removeFirst(storedSamples.count - Self.maximumSampleCount)
            }
            acceptedUpdateCount += 1
        } else {
            currentSegmentID += 1
        }

        if latestObservation.map({ timestamp >= $0.timestamp }) ?? true {
            latestObservation = Observation(bpm: validBPM, timestamp: timestamp)
        }
    }

    /// Produces a snapshot relative to an injected clock value and prunes
    /// history outside the closed interval `now - 60 seconds ... now`.
    public mutating func snapshot(at now: Date) -> PulseSnapshot {
        let cutoff = now.addingTimeInterval(-Self.historyWindow)
        storedSamples.removeAll { $0.timestamp < cutoff || $0.timestamp > now }

        let state = state(at: now)
        let latestBPM = latestObservation?.bpm

        return PulseSnapshot(
            state: state,
            liveBPM: state == .live ? latestBPM : nil,
            latestBPM: latestBPM,
            latestTimestamp: latestObservation?.timestamp,
            samples: storedSamples,
            minimumBPM: storedSamples.map(\.bpm).min(),
            maximumBPM: storedSamples.map(\.bpm).max()
        )
    }

    public mutating func reset() {
        storedSamples.removeAll(keepingCapacity: false)
        latestObservation = nil
        acceptedUpdateCount = 0
        currentSegmentID = 0
    }

    private func state(at now: Date) -> PulseSignalState {
        guard let latestObservation, latestObservation.bpm != nil else {
            return .waiting
        }

        let age = now.timeIntervalSince(latestObservation.timestamp)
        guard age >= 0 else {
            return .stale
        }
        return age <= freshnessThreshold ? .live : .stale
    }
}

private extension PulseSignal {
    struct Observation: Sendable {
        let bpm: Int?
        let timestamp: Date
    }
}
