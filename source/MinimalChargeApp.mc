import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class MinimalChargeApp extends Application.AppBase {
    private var _view as MinimalChargeView?;

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
    }

    public function onStop(state as Dictionary?) as Void {
    }

    public function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new MinimalChargeView();
        _view = view;
        return [view];
    }

    public function onSettingsChanged() as Void {
        var view = _view;
        if (view != null) {
            view.loadSettings();
        }
        WatchUi.requestUpdate();
    }
}
