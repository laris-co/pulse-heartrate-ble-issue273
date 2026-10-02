using Toybox.Communications as Communications;
using Toybox.Lang as Lang;
using Toybox.Sensor as Sensor;
using Toybox.System as System;
using Toybox.Timer as Timer;
using Toybox.WatchUi as WatchUi;

class PulseConnectionListener extends Communications.ConnectionListener {
    private var _controller;

    function initialize(controller) {
        ConnectionListener.initialize();
        _controller = controller;
    }

    function onComplete() {
        _controller.onTransmitFinished(true);
    }

    function onError() {
        _controller.onTransmitFinished(false);
    }
}

class PulseController {
    const MAX_SENSOR_AGE_MS = 3000;
    // Deliberately beyond MAX_SENSOR_AGE_MS so unavailable can never look fresh.
    const NO_SENSOR_AGE = 4000;
    const UUID_LENGTH = 36;
    const UUID_HEX = "0123456789abcdefABCDEF";
    const TRANSMIT_NONE = 0;
    const TRANSMIT_PULSE = 1;
    const TRANSMIT_LINK_TEST = 2;

    private var _active = false;
    private var _heartRate = 0;
    private var _sensorAt = null;
    private var _transmitBusy = false;
    private var _transmitKind = TRANSMIT_NONE;
    private var _lastNonce = null;
    private var _phoneCallbackCount = 0;
    private var _lastPhoneRequestAt = null;
    private var _status = "Starting";
    private var _listener;
    private var _displayTimer;

    function initialize() {
        _listener = new PulseConnectionListener(self);
        _displayTimer = new Timer.Timer();
    }

    function start() {
        if (_active) {
            return;
        }

        _active = true;
        _status = "Waiting for phone";
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Sensor.enableSensorEvents(method(:onSensor));
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        _displayTimer.start(method(:onDisplayTimer), 1000, true);
        requestDisplayUpdate();
    }

    function stop() {
        if (!_active) {
            return;
        }

        _active = false;
        _displayTimer.stop();
        Communications.registerForPhoneAppMessages(null);
        Sensor.enableSensorEvents(null);
        Sensor.setEnabledSensors([]);
        _heartRate = 0;
        _sensorAt = null;
        _transmitBusy = false;
        _transmitKind = TRANSMIT_NONE;
        _lastPhoneRequestAt = null;
        _status = "Stopped";
    }

    function onSensor(info as Sensor.Info) as Void {
        if (!_active) {
            return;
        }

        _sensorAt = System.getTimer();
        if (info.heartRate == null || info.heartRate <= 0) {
            _heartRate = 0;
        } else {
            _heartRate = info.heartRate.toNumber();
        }
        requestDisplayUpdate();
    }

    function onDisplayTimer() as Void {
        requestDisplayUpdate();
    }

    function onPhoneMessage(message as Communications.PhoneAppMessage) as Void {
        _phoneCallbackCount += 1;
        requestDisplayUpdate();

        if (!_active || _transmitBusy || message == null) {
            return;
        }

        var requestData = message.data;
        if (!isValidRequest(requestData)) {
            _status = "Invalid request";
            requestDisplayUpdate();
            return;
        }

        var request = requestData as Lang.Dictionary;
        var nonce = request["nonce"] as Lang.String;
        if (_lastNonce != null && nonce.equals(_lastNonce)) {
            _status = "Duplicate skipped";
            requestDisplayUpdate();
            return;
        }

        var sample = currentSample();
        var response = buildPulseResponse(nonce, sample[0], sample[1]);

        _lastPhoneRequestAt = System.getTimer();
        _transmitBusy = true;
        _transmitKind = TRANSMIT_PULSE;
        _lastNonce = nonce;
        _status = "Sending";
        requestDisplayUpdate();
        Communications.transmit(response, {}, _listener);
    }

    function runLinkTest() as Void {
        if (!_active || _transmitBusy) {
            return;
        }

        _transmitBusy = true;
        _transmitKind = TRANSMIT_LINK_TEST;
        _status = "Link test sending";
        requestDisplayUpdate();
        Communications.transmit("pulse-link-watch-test", {}, _listener);
    }

    function onTransmitFinished(succeeded) {
        if (!_active) {
            return;
        }
        var completedKind = _transmitKind;
        _transmitBusy = false;
        _transmitKind = TRANSMIT_NONE;
        if (completedKind == TRANSMIT_LINK_TEST) {
            _status = succeeded ? "Link test sent" : "Link test failed";
        } else {
            _status = succeeded ? "Sent" : "Send failed";
        }
        requestDisplayUpdate();
    }

    function currentSample() as Lang.Array<Lang.Number> {
        if (_sensorAt == null) {
            return [0, NO_SENSOR_AGE];
        }

        var age = System.getTimer() - _sensorAt;
        if (age < 0) {
            return [0, NO_SENSOR_AGE];
        }
        if (_heartRate <= 0 || age > MAX_SENSOR_AGE_MS) {
            return [0, age];
        }
        return [_heartRate, age];
    }

    function getDisplayBpm() as Lang.Number {
        var sample = currentSample();
        return sample[0];
    }

    function getStatus() {
        return _status;
    }

    function getPhoneCallbackCount() as Lang.Number {
        return _phoneCallbackCount;
    }

    function hasRecentPhoneRequest() as Lang.Boolean {
        if (!_active || _lastPhoneRequestAt == null) {
            return false;
        }
        var age = System.getTimer() - _lastPhoneRequestAt;
        return age >= 0 && age <= 6000;
    }

    private function isValidRequest(request) {
        if (!(request instanceof Lang.Dictionary)) {
            return false;
        }
        if (!request.hasKey("v") || !request.hasKey("type") || !request.hasKey("nonce")) {
            return false;
        }
        if (!(request["v"] instanceof Lang.Number) || request["v"] != 1) {
            return false;
        }
        if (!(request["type"] instanceof Lang.String) || !request["type"].equals("request")) {
            return false;
        }
        return isUuid(request["nonce"]);
    }

    private function isUuid(value) {
        if (!(value instanceof Lang.String) || value.length() != UUID_LENGTH) {
            return false;
        }

        for (var index = 0; index < UUID_LENGTH; index += 1) {
            var character = value.substring(index, index + 1);
            var isHyphen = index == 8 || index == 13 || index == 18 || index == 23;
            if (isHyphen) {
                if (!character.equals("-")) {
                    return false;
                }
            } else if (UUID_HEX.find(character) == null) {
                return false;
            }
        }
        return true;
    }

    private function requestDisplayUpdate() {
        if (_active) {
            WatchUi.requestUpdate();
        }
    }
}
