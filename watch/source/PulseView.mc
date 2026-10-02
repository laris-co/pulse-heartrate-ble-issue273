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
    private var _showClaude = false;
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

    // Page 2: the Claude status page.
    function toggleClaude() {
        _showClaude = !_showClaude;
        _phaseAt = null;
        WatchUi.requestUpdate();
    }

    function isShowingClaude() as Lang.Boolean {
        return _showClaude;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (_showDetails) {
            drawDetails(dc);
            return;
        }
        if (_showClaude) {
            drawClaude(dc);
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
        // A fresh status line from the phone app replaces the button hint (green);
        // otherwise the hint stays (blue).
        var phoneStatus = _controller.getPhoneStatus();
        if (phoneStatus != null && !_motionPaused) {
            dc.setColor(0xAAFFAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 213, Graphics.FONT_XTINY, phoneStatus, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0xAAAAFF, Graphics.COLOR_TRANSPARENT);
            var actionHint = _motionPaused ? "START: resume" :
                (_controller.hasRecentPhoneRequest() ? "Phone link active" : "UP: link  DOWN: Claude");
            dc.drawText(centerX, 213, Graphics.FONT_XTINY,
                actionHint, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Page 2. Everything shown here came from the phone in one status message; the watch adds
    // only the bar and how long ago the message arrived.
    private function drawClaude(dc) {
        var centerX = dc.getWidth() / 2;
        var page = _controller.getPhoneStatusPage() as Lang.Dictionary or Null;
        dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 18, Graphics.FONT_TINY, page == null ? "Claude" : page["title"] as Lang.String,
            Graphics.TEXT_JUSTIFY_CENTER);
        if (page == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 90, Graphics.FONT_SMALL, "No status yet", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xAAAAFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 130, Graphics.FONT_XTINY, "The phone app pushes it", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(centerX, 196, Graphics.FONT_XTINY, "BACK: clock", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var lines = page["lines"] as Lang.Array<Lang.String>;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 42, Graphics.FONT_SMALL, lines[0], Graphics.TEXT_JUSTIFY_CENTER);
        if (lines.size() > 1) {
            dc.setColor(0xFFAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 74, Graphics.FONT_TINY, lines[1], Graphics.TEXT_JUSTIFY_CENTER);
        }
        var ctx = page["ctx"] as Lang.Number or Null;
        if (ctx != null) {
            var barX = 40;
            var barW = 160;
            var fill = 0x55FF55;
            if (ctx >= 80) {
                fill = 0xFF5555;
            } else if (ctx >= 50) {
                fill = 0xFFAA00;
            }
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(barX, 106, barW, 12);
            dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX + 1, 107, (barW - 2) * ctx / 100, 10);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 120, Graphics.FONT_TINY, "ctx " + ctx.format("%d") + "%",
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xAAAAFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 2; i < lines.size(); i += 1) {
            dc.drawText(centerX, 148 + (i - 2) * 18, Graphics.FONT_XTINY, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        var age = _controller.getPhoneStatusAgeSeconds();
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 196, Graphics.FONT_XTINY,
            age < 60 ? "updated just now" : "updated " + (age / 60).format("%d") + " min ago",
            Graphics.TEXT_JUSTIFY_CENTER);
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
