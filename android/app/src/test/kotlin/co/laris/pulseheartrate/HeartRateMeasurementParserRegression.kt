package co.laris.pulseheartrate

object HeartRateMeasurementParserRegression {
    @JvmStatic
    fun main(args: Array<String>) {
        parsesUint8HeartRate()
        parsesUint16HeartRateLittleEndian()
        skipsEnergyAndParsesAllRrIntervals()
        treatsBytesAsUnsigned()
        rejectsMissingAndTruncatedFields()
        println("HeartRateMeasurementParserRegression: all checks passed")
    }

    private fun parsesUint8HeartRate() {
        val parsed = success(byteArrayOf(0x00, 72))
        checkEquals(72, parsed.beatsPerMinute)
        check(parsed.rrIntervalsSeconds.isEmpty())
    }

    private fun parsesUint16HeartRateLittleEndian() {
        checkEquals(300, success(byteArrayOf(0x01, 0x2c, 0x01)).beatsPerMinute)
    }

    private fun skipsEnergyAndParsesAllRrIntervals() {
        val parsed = success(byteArrayOf(0x18, 60, 0x34, 0x12, 0x00, 0x04, 0x00, 0x02))
        checkEquals(listOf(1.0, 0.5), parsed.rrIntervalsSeconds)
    }

    private fun treatsBytesAsUnsigned() {
        checkEquals(255, success(byteArrayOf(0x00, 0xff.toByte())).beatsPerMinute)
    }

    private fun rejectsMissingAndTruncatedFields() {
        val malformed = listOf(
            byteArrayOf(),
            byteArrayOf(0x00),
            byteArrayOf(0x01, 0x2c),
            byteArrayOf(0x08, 60, 0x01),
            byteArrayOf(0x10, 60),
            byteArrayOf(0x10, 60, 0x01),
            byteArrayOf(0x00, 60, 0x01),
        )
        malformed.forEach { check(HeartRateMeasurementParser.parse(it) is HeartRateParseResult.Malformed) }
    }

    private fun success(packet: ByteArray): HeartRateMeasurement {
        val result = HeartRateMeasurementParser.parse(packet)
        check(result is HeartRateParseResult.Success) { "expected success but was $result" }
        return (result as HeartRateParseResult.Success).measurement
    }

    private fun checkEquals(expected: Any, actual: Any) {
        check(expected == actual) { "expected <$expected> but was <$actual>" }
    }
}
