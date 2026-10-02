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

    // DOWN: clock -> Claude page (page 2); from link details it returns to the clock.
    function onNextPage() as Lang.Boolean {
        if (_view.isShowingDetails()) {
            _view.toggleDetails();
        } else {
            _view.toggleClaude();
        }
        return true;
    }

    // UP: clock -> link details; from the Claude page it returns to the clock.
    function onPreviousPage() as Lang.Boolean {
        if (_view.isShowingClaude()) {
            _view.toggleClaude();
        } else {
            _view.toggleDetails();
        }
        return true;
    }

    function onBack() as Lang.Boolean {
        if (_view.isShowingDetails()) {
            _view.toggleDetails();
            return true;
        }
        if (_view.isShowingClaude()) {
            _view.toggleClaude();
            return true;
        }
        return false;
    }
}
