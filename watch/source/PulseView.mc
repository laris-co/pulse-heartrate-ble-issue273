using Toybox.Graphics as Graphics;
using Toybox.Lang as Lang;
using Toybox.System as System;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.Timer as Timer;
using Toybox.WatchUi as WatchUi;

class PulseView extends WatchUi.View {
    private var _controller;
    private var _animationTimer;
    private var _hearts as Lang.Array;
    private var _showDetails = false;
    private var _motionPaused = false;
    private var _visible = false;
    private var _phase = 0.0;
    private var _phaseAt = null;

    function initialize(controller) {
        View.initialize();
        _controller = controller;
        _animationTimer = new Timer.Timer();
        _hearts = [
            WatchUi.loadResource(Rez.Drawables.Heart0),
            WatchUi.loadResource(Rez.Drawables.Heart1),
            WatchUi.loadResource(Rez.Drawables.Heart2),
            WatchUi.loadResource(Rez.Drawables.Heart3),
            WatchUi.loadResource(Rez.Drawables.Heart4),
            WatchUi.loadResource(Rez.Drawables.Heart5)
        ];
    }

    function onShow() {
        _visible = true;
        _phaseAt = null;
        // Six frame invalidations/second, only while this foreground view is visible.
        // The controller's independent 1 Hz timer still handles stale-data clearing.
        _animationTimer.start(method(:onAnimationTimer), 167, true);
    }

    function onHide() {
        _visible = false;
        _animationTimer.stop();
        _phaseAt = null;
    }

    function onAnimationTimer() as Void {
        if (_visible && !_showDetails && !_motionPaused && _controller.getDisplayBpm() > 0) {
            WatchUi.requestUpdate();
        }
    }

    function toggleMotion() {
        _motionPaused = !_motionPaused;
        _phaseAt = null;
        WatchUi.requestUpdate();
    }

    function toggleDetails() {
        _showDetails = !_showDetails;
        _phaseAt = null;
        WatchUi.requestUpdate();
    }

    function isShowingDetails() as Lang.Boolean {
        return _showDetails;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (_showDetails) {
            drawDetails(dc);
            return;
        }
        drawClock(dc);
    }

    private function drawClock(dc) {
        var centerX = dc.getWidth() / 2;
        var clock = System.getClockTime();
        var date = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var is24Hour = System.getDeviceSettings().is24Hour;
        var bpm = _controller.getDisplayBpm();
        var now = System.getTimer();
        if (bpm <= 0) {
            _phase = 0.0;
        } else if (!_motionPaused && _phaseAt != null) {
            _phase = advancePulsePhase(_phase, now - _phaseAt, bpm);
        }
        _phaseAt = now;

        dc.setColor(0xFFAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 15, Graphics.FONT_TINY,
            date.day_of_week + " " + date.day.format("%d") + " " + date.month,
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 29, Graphics.FONT_NUMBER_HOT,
            formatPulseClockTime(clock.hour, clock.min, is24Hour),
            Graphics.TEXT_JUSTIFY_CENTER);
        if (!is24Hour) {
            dc.drawText(192, 59, Graphics.FONT_XTINY, clock.hour < 12 ? "AM" : "PM",
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        var heart = _hearts[pulseHeartFrame(_phase)];
        dc.drawBitmap(77 - heart.getWidth() / 2, 145 - heart.getHeight() / 2, heart);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(170, 109, Graphics.FONT_NUMBER_MEDIUM,
            bpm > 0 ? bpm.format("%d") : "--", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(170, 154, Graphics.FONT_TINY, "BPM", Graphics.TEXT_JUSTIFY_CENTER);

        var footer = "Waiting for pulse";
        if (bpm > 0) {
            footer = _motionPaused ? "Motion paused" : "Live pulse";
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 193, Graphics.FONT_TINY, footer, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAAAAFF, Graphics.COLOR_TRANSPARENT);
        var actionHint = _motionPaused ? "START: resume" :
            (_controller.hasRecentPhoneRequest() ? "Phone link active" : "UP: link details");
        dc.drawText(centerX, 213, Graphics.FONT_XTINY,
            actionHint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawDetails(dc) {
        var centerX = dc.getWidth() / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 27, Graphics.FONT_SMALL, "Pulse Link", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 62, Graphics.FONT_TINY, _controller.getStatus(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 90, Graphics.FONT_TINY,
            "Phone RX: " + _controller.getPhoneCallbackCount().format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, 122, Graphics.FONT_XTINY, "START: link test", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, 144, Graphics.FONT_XTINY, "BACK: clock", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAAAAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 181, Graphics.FONT_XTINY, "Motion follows BPM", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, 198, Graphics.FONT_XTINY, "Not measured beats", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
