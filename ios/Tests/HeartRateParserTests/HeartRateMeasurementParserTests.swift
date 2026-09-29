import Foundation
import Testing
@testable import HeartRateParser

@Test("Parses an 8-bit heart rate")
func parsesUInt8HeartRate() throws {
    let measurement = try HeartRateMeasurementParser.parse(Data([0x00, 72]))

    #expect(measurement.beatsPerMinute == 72)
    #expect(measurement.energyExpended == nil)
    #expect(measurement.rrIntervalsSeconds.isEmpty)
}

@Test("Parses a 16-bit heart rate, energy, and multiple RR intervals")
func parsesAllOptionalFields() throws {
    let measurement = try HeartRateMeasurementParser.parse(Data([
        0x19,
        0x2C, 0x01, // 300 BPM
        0x34, 0x12, // energy 0x1234
        0x00, 0x04, // 1.0 seconds
        0x00, 0x02  // 0.5 seconds
    ]))

    #expect(measurement.beatsPerMinute == 300)
    #expect(measurement.energyExpended == 0x1234)
    #expect(measurement.rrIntervalsSeconds == [1.0, 0.5])
}

@Test("Rejects an empty packet")
func rejectsEmptyPacket() {
    #expect(throws: HeartRateMeasurementError.emptyPacket) {
        try HeartRateMeasurementParser.parse(Data())
    }
}

@Test("Rejects a truncated 16-bit heart rate")
func rejectsTruncatedHeartRate() {
    #expect(throws: HeartRateMeasurementError.truncated(field: "heart rate")) {
        try HeartRateMeasurementParser.parse(Data([0x01, 0x2C]))
    }
}

@Test("Rejects truncated energy")
func rejectsTruncatedEnergy() {
    #expect(throws: HeartRateMeasurementError.truncated(field: "energy expended")) {
        try HeartRateMeasurementParser.parse(Data([0x08, 72, 0x34]))
    }
}

@Test("Rejects an odd trailing RR byte")
func rejectsTruncatedRRInterval() {
    #expect(throws: HeartRateMeasurementError.truncated(field: "RR interval")) {
        try HeartRateMeasurementParser.parse(Data([0x10, 72, 0x00]))
    }
}

@Test("Rejects an RR-present flag without an RR interval")
func rejectsMissingRRInterval() {
    #expect(throws: HeartRateMeasurementError.truncated(field: "RR interval")) {
        try HeartRateMeasurementParser.parse(Data([0x10, 72]))
    }
}

@Test("Rejects trailing bytes when the RR-present flag is clear")
func rejectsUnexpectedTrailingBytes() {
    #expect(throws: HeartRateMeasurementError.unexpectedTrailingBytes(count: 2)) {
        try HeartRateMeasurementParser.parse(Data([0x00, 72, 0x00, 0x04]))
    }
}
