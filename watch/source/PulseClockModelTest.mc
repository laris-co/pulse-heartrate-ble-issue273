using Toybox.Lang as Lang;
using Toybox.Test as Test;

(:test)
function testPulseClockTimeBoundaries(logger as Test.Logger) as Lang.Boolean {
    return formatPulseClockTime(0, 0, true).equals("00:00")
        && formatPulseClockTime(0, 0, false).equals("12:00")
        && formatPulseClockTime(12, 0, true).equals("12:00")
        && formatPulseClockTime(12, 0, false).equals("12:00")
        && formatPulseClockTime(23, 59, true).equals("23:59")
        && formatPulseClockTime(23, 59, false).equals("11:59");
}

(:test)
function testPulsePhaseTracksHeartRate(logger as Test.Logger) as Lang.Boolean {
    var atSixty = advancePulsePhase(0.0, 250, 60);
    var atOneTwenty = advancePulsePhase(0.0, 250, 120);

    return atSixty > 0.249 && atSixty < 0.251
        && atOneTwenty > 0.499 && atOneTwenty < 0.501;
}

(:test)
function testPulsePhaseRejectsInvalidInput(logger as Test.Logger) as Lang.Boolean {
    return advancePulsePhase(0.42, 100, 0) == 0.0
        && advancePulsePhase(0.42, 100, -1) == 0.0
        && advancePulsePhase(0.42, -1, 72) == 0.42
        && advancePulsePhase(0.42, 1001, 72) == 0.42;
}

(:test)
function testPulsePhaseWraps(logger as Test.Logger) as Lang.Boolean {
    var wrapped = advancePulsePhase(0.9, 200, 60);
    return wrapped > 0.099 && wrapped < 0.101;
}

(:test)
function testPulseHeartFramesStayBounded(logger as Test.Logger) as Lang.Boolean {
    for (var index = 0; index < 100; index += 1) {
        var frame = pulseHeartFrame(index.toFloat() / 100.0);
        if (frame < 0 || frame > 5) {
            return false;
        }
    }

    return true;
}

(:test)
function testPulseHeartContractsAndReturnsToRest(logger as Test.Logger) as Lang.Boolean {
    return pulseHeartFrame(0.0) == 0
        && pulseHeartFrame(0.20) == 5
        && pulseHeartFrame(0.43) == 2
        && pulseHeartFrame(0.70) == 0
        && pulseHeartFrame(0.99) == 0;
}
