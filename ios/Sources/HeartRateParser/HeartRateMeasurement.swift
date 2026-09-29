import Foundation

struct HeartRateMeasurement: Equatable, Sendable {
    let beatsPerMinute: UInt16
    let energyExpended: UInt16?
    let rrIntervalsSeconds: [Double]
}

enum HeartRateMeasurementError: Error, Equatable, CustomStringConvertible {
    case emptyPacket
    case truncated(field: String)
    case unexpectedTrailingBytes(count: Int)

    var description: String {
        switch self {
        case .emptyPacket:
            return "The measurement packet is empty."
        case let .truncated(field):
            return "The measurement packet is truncated while reading \(field)."
        case let .unexpectedTrailingBytes(count):
            return "The measurement packet contains \(count) unexpected trailing byte(s)."
        }
    }
}

enum HeartRateMeasurementParser {
    static func parse(_ data: Data) throws -> HeartRateMeasurement {
        let bytes = [UInt8](data)
        guard let flags = bytes.first else {
            throw HeartRateMeasurementError.emptyPacket
        }

        var cursor = 1

        func readUInt8(field: String) throws -> UInt8 {
            guard cursor < bytes.count else {
                throw HeartRateMeasurementError.truncated(field: field)
            }
            defer { cursor += 1 }
            return bytes[cursor]
        }

        func readUInt16(field: String) throws -> UInt16 {
            guard cursor + 1 < bytes.count else {
                throw HeartRateMeasurementError.truncated(field: field)
            }
            defer { cursor += 2 }
            return UInt16(bytes[cursor]) | (UInt16(bytes[cursor + 1]) << 8)
        }

        let usesUInt16BPM = flags & 0x01 != 0
        let beatsPerMinute = try usesUInt16BPM
            ? readUInt16(field: "heart rate")
            : UInt16(readUInt8(field: "heart rate"))

        let energyExpended = flags & 0x08 != 0
            ? try readUInt16(field: "energy expended")
            : nil

        var rrIntervalsSeconds: [Double] = []
        if flags & 0x10 != 0 {
            guard cursor < bytes.count else {
                throw HeartRateMeasurementError.truncated(field: "RR interval")
            }
            while cursor < bytes.count {
                let rawInterval = try readUInt16(field: "RR interval")
                rrIntervalsSeconds.append(Double(rawInterval) / 1024.0)
            }
        } else if cursor != bytes.count {
            throw HeartRateMeasurementError.unexpectedTrailingBytes(count: bytes.count - cursor)
        }

        return HeartRateMeasurement(
            beatsPerMinute: beatsPerMinute,
            energyExpended: energyExpended,
            rrIntervalsSeconds: rrIntervalsSeconds
        )
    }
}
