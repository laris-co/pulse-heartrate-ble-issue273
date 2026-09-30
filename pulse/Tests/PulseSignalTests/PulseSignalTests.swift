import Foundation
import Testing
@testable import PulseSignal

struct PulseSignalTests {
    private let origin = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func historyIsBoundedToSixtySamplesAndOneMinute() {
        var signal = PulseSignal()
        for offset in 0...70 {
            signal.ingest(bpm: 60 + offset, at: origin.addingTimeInterval(TimeInterval(offset)))
        }

        let snapshot = signal.snapshot(at: origin.addingTimeInterval(70))

        #expect(snapshot.samples.count == 60)
        #expect(snapshot.samples.first?.timestamp == origin.addingTimeInterval(11))
        #expect(snapshot.samples.last?.timestamp == origin.addingTimeInterval(70))
        #expect(snapshot.minimumBPM == 71)
        #expect(snapshot.maximumBPM == 130)
    }

    @Test func freshnessBoundaryIsInclusiveThenBecomesStale() {
        var signal = PulseSignal()
        signal.ingest(bpm: 72, at: origin)

        let boundary = signal.snapshot(at: origin.addingTimeInterval(5))
        let pastBoundary = signal.snapshot(at: origin.addingTimeInterval(5.001))

        #expect(boundary.state == .live)
        #expect(boundary.liveBPM == 72)
        #expect(pastBoundary.state == .stale)
        #expect(pastBoundary.liveBPM == nil)
        #expect(pastBoundary.latestBPM == 72)
    }

    @Test func zeroBPMIsUnavailableAndNeverLive() {
        var signal = PulseSignal()
        signal.ingest(bpm: 70, at: origin)
        signal.ingest(bpm: 0, at: origin.addingTimeInterval(1))

        let snapshot = signal.snapshot(at: origin.addingTimeInterval(1))

        #expect(snapshot.state == .waiting)
        #expect(snapshot.liveBPM == nil)
        #expect(snapshot.latestBPM == nil)
        #expect(snapshot.latestTimestamp == origin.addingTimeInterval(1))
        #expect(snapshot.samples.map(\.bpm) == [70])
    }

    @Test func resetClearsCurrentReadingHistoryAndRange() {
        var signal = PulseSignal()
        signal.ingest(bpm: 64, at: origin)
        signal.ingest(bpm: 88, at: origin.addingTimeInterval(1))
        signal.reset()

        let snapshot = signal.snapshot(at: origin.addingTimeInterval(1))

        #expect(snapshot.state == .waiting)
        #expect(snapshot.liveBPM == nil)
        #expect(snapshot.latestBPM == nil)
        #expect(snapshot.latestTimestamp == nil)
        #expect(snapshot.samples.isEmpty)
        #expect(snapshot.minimumBPM == nil)
        #expect(snapshot.maximumBPM == nil)
    }

    @Test func snapshotPrunesSamplesOlderThanOneMinute() {
        var signal = PulseSignal()
        signal.ingest(bpm: 61, at: origin)
        signal.ingest(bpm: 62, at: origin.addingTimeInterval(1))

        let snapshot = signal.snapshot(at: origin.addingTimeInterval(61))

        #expect(snapshot.samples.map(\.bpm) == [62])
        #expect(snapshot.minimumBPM == 62)
        #expect(snapshot.maximumBPM == 62)
    }

    @Test func duplicateTimestampReplacesRatherThanDuplicates() {
        var signal = PulseSignal()
        signal.ingest(bpm: 70, at: origin)
        signal.ingest(bpm: 91, at: origin)

        let snapshot = signal.snapshot(at: origin)

        #expect(snapshot.samples == [PulseSample(bpm: 91, timestamp: origin)])
        #expect(snapshot.liveBPM == 91)
        #expect(snapshot.minimumBPM == 91)
        #expect(snapshot.maximumBPM == 91)
    }

    @Test func futureReadingIsNotReportedAsFreshOrIncludedInRecentHistory() {
        var signal = PulseSignal()
        signal.ingest(bpm: 75, at: origin.addingTimeInterval(10))

        let snapshot = signal.snapshot(at: origin)

        #expect(snapshot.state == .stale)
        #expect(snapshot.liveBPM == nil)
        #expect(snapshot.latestBPM == 75)
        #expect(snapshot.latestTimestamp == origin.addingTimeInterval(10))
        #expect(snapshot.samples.isEmpty)
        #expect(snapshot.minimumBPM == nil)
        #expect(snapshot.maximumBPM == nil)
    }

    @Test func missingAndNegativeReadingsAreUnavailable() {
        var signal = PulseSignal()
        signal.ingest(bpm: nil, at: origin)
        signal.ingest(bpm: -5, at: origin.addingTimeInterval(1))

        let snapshot = signal.snapshot(at: origin.addingTimeInterval(1))

        #expect(snapshot.state == .waiting)
        #expect(snapshot.liveBPM == nil)
        #expect(snapshot.samples.isEmpty)
    }

    @Test func acceptedUpdateCountIncludesOnlyPositiveMeasurementsAndResetClearsIt() {
        var signal = PulseSignal()

        signal.ingest(bpm: 72, at: origin)
        signal.ingest(bpm: 0, at: origin.addingTimeInterval(1))
        signal.ingest(bpm: nil, at: origin.addingTimeInterval(2))
        signal.ingest(bpm: -4, at: origin.addingTimeInterval(3))
        signal.ingest(bpm: 74, at: origin.addingTimeInterval(4))

        #expect(signal.acceptedUpdateCount == 2)

        signal.reset()

        #expect(signal.acceptedUpdateCount == 0)
    }

    @Test func invalidAndMissingObservationsStartNewSampleSegments() {
        var signal = PulseSignal()
        signal.ingest(bpm: 70, at: origin)
        signal.ingest(bpm: 0, at: origin.addingTimeInterval(1))
        signal.ingest(bpm: 72, at: origin.addingTimeInterval(2))
        signal.ingest(bpm: nil, at: origin.addingTimeInterval(3))
        signal.ingest(bpm: 74, at: origin.addingTimeInterval(4))

        let snapshot = signal.snapshot(at: origin.addingTimeInterval(4))

        #expect(snapshot.samples.map(\.bpm) == [70, 72, 74])
        #expect(snapshot.samples[0].segmentID != snapshot.samples[1].segmentID)
        #expect(snapshot.samples[1].segmentID != snapshot.samples[2].segmentID)
    }

    @Test func resetRestartsSampleSegments() {
        var signal = PulseSignal()
        signal.ingest(bpm: nil, at: origin)
        signal.ingest(bpm: 70, at: origin.addingTimeInterval(1))
        #expect(signal.snapshot(at: origin.addingTimeInterval(1)).samples[0].segmentID == 1)

        signal.reset()
        signal.ingest(bpm: 72, at: origin.addingTimeInterval(2))

        #expect(signal.snapshot(at: origin.addingTimeInterval(2)).samples[0].segmentID == 0)
    }
}
