using Toybox.Application as Application;
using Toybox.WatchUi as WatchUi;

class PulseLinkApp extends Application.AppBase {
    private var _controller;

    function initialize() {
        AppBase.initialize();
        _controller = new PulseController();
    }

    function onStart(state) {
        _controller.start();
    }

    function getInitialView() {
        var view = new PulseView(_controller);
        return [view, new PulseInputDelegate(_controller, view)];
    }

    function onStop(state) {
        _controller.stop();
    }
}

function getApp() {
    return Application.getApp();
}
