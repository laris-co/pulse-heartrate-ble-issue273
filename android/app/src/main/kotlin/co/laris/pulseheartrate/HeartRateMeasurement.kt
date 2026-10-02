package co.laris.pulseheartrate

data class HeartRateMeasurement(
    val beatsPerMinute: Int,
    val rrIntervalsSeconds: List<Double>,
)

sealed interface HeartRateParseResult {
    data class Success(val measurement: HeartRateMeasurement) : HeartRateParseResult
    data class Malformed(val reason: String) : HeartRateParseResult
}

object HeartRateMeasurementParser {
    fun parse(packet: ByteArray): HeartRateParseResult {
        if (packet.isEmpty()) return HeartRateParseResult.Malformed("missing flags")

        val flags = packet[0].toInt() and 0xff
        var offset = 1
        val bpm: Int
        if (flags and 0x01 != 0) {
            if (packet.size < offset + 2) return HeartRateParseResult.Malformed("truncated uint16 heart rate")
            bpm = uint16Le(packet, offset)
            offset += 2
        } else {
            if (packet.size < offset + 1) return HeartRateParseResult.Malformed("truncated uint8 heart rate")
            bpm = packet[offset].toInt() and 0xff
            offset += 1
        }

        // Energy Expended is optional and precedes any RR intervals.
        if (flags and 0x08 != 0) {
            if (packet.size < offset + 2) return HeartRateParseResult.Malformed("truncated energy expended")
            offset += 2
        }

        val rrIntervals = mutableListOf<Double>()
        if (flags and 0x10 != 0) {
            val remaining = packet.size - offset
            if (remaining == 0 || remaining % 2 != 0) {
                return HeartRateParseResult.Malformed("truncated RR interval")
            }
            while (offset < packet.size) {
                rrIntervals += uint16Le(packet, offset) / 1024.0
                offset += 2
            }
        } else if (offset != packet.size) {
            return HeartRateParseResult.Malformed("unexpected trailing bytes")
        }

        return HeartRateParseResult.Success(HeartRateMeasurement(bpm, rrIntervals))
    }

    private fun uint16Le(packet: ByteArray, offset: Int): Int =
        (packet[offset].toInt() and 0xff) or ((packet[offset + 1].toInt() and 0xff) shl 8)
}
