using Toybox.Lang as Lang;
using Toybox.WatchUi as WatchUi;

class PulseInputDelegate extends WatchUi.BehaviorDelegate {
    private var _controller;
    private var _view;

    function initialize(controller, view) {
        BehaviorDelegate.initialize();
        _controller = controller;
        _view = view;
    }

    function onSelect() as Lang.Boolean {
        if (_view.isShowingDetails()) {
            _controller.runLinkTest();
        } else {
            _view.toggleMotion();
        }
        return true;
    }

    function onNextPage() as Lang.Boolean {
        _view.toggleDetails();
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        _view.toggleDetails();
        return true;
    }

    function onBack() as Lang.Boolean {
        if (_view.isShowingDetails()) {
            _view.toggleDetails();
            return true;
        }
        return false;
    }
}
