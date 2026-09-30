using Toybox.Lang as Lang;

function formatPulseClockTime(
    hour as Lang.Number,
    minute as Lang.Number,
    is24Hour as Lang.Boolean
) as Lang.String {
    var displayHour = hour;

    if (!is24Hour) {
        displayHour = hour % 12;
        if (displayHour == 0) {
            displayHour = 12;
        }
    }

    var hourText = is24Hour ? displayHour.format("%02d") : displayHour.format("%d");
    return hourText + ":" + minute.format("%02d");
}

function advancePulsePhase(
    phase as Lang.Float,
    elapsedMs as Lang.Number,
    bpm as Lang.Number
) as Lang.Float {
    if (bpm <= 0) {
        return 0.0;
    }

    if (elapsedMs < 0 || elapsedMs > 1000) {
        return phase;
    }

    var nextPhase = phase + (elapsedMs.toFloat() * bpm.toFloat() / 60000.0);
    while (nextPhase >= 1.0) {
        nextPhase -= 1.0;
    }
    while (nextPhase < 0.0) {
        nextPhase += 1.0;
    }

    return nextPhase;
}

function pulseHeartFrame(phase as Lang.Float) as Lang.Number {
    var normalizedPhase = phase;
    while (normalizedPhase >= 1.0) {
        normalizedPhase -= 1.0;
    }
    while (normalizedPhase < 0.0) {
        normalizedPhase += 1.0;
    }

    if (normalizedPhase < 0.08) {
        return 0;
    } else if (normalizedPhase < 0.16) {
        return 2;
    } else if (normalizedPhase < 0.22) {
        return 5;
    } else if (normalizedPhase < 0.29) {
        return 3;
    } else if (normalizedPhase < 0.38) {
        return 1;
    } else if (normalizedPhase < 0.46) {
        return 2;
    } else if (normalizedPhase < 0.54) {
        return 1;
    }

    return 0;
}
