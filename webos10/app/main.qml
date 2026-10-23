// Homebar overlay (webOS 10 and the untested versions tried with it): the
// shared panel (Panel.qml, generated from ui/Launcher.qml by tools/build.py)
// in a developer QML overlay window run by qml-runner. HOME relaunches the
// app; qml-runner resets the "params" context property, which shows the
// panel again. BACK hides the window but keeps the process, so the next HOME
// is a show, not a start.
import QtQuick 2.4
import QtQuick.Window 2.2
import Eos.Window 0.1

WebOSWindow {
    id: win
    windowType: "_WEBOS_WINDOW_TYPE_OVERLAY"
    // The TV's UI plane: 1920×1080 on FHD and UHD sets (the TV scales it to
    // the panel), 1280×720 on HD ones. A screen reported smaller than FHD is
    // taken at its size; anything else stays at the tested 1920×1080. The
    // panel lays itself out for whatever size it gets.
    readonly property bool smallScreen: Screen.width > 0 && Screen.height > 0 && Screen.width < 1920
    width: smallScreen ? Screen.width : 1920
    height: smallScreen ? Screen.height : 1080
    visible: true
    color: "transparent"
    appId: "org.rawin.launcher"
    title: "Homebar"

    property var launchParams: typeof params !== "undefined" ? params : null
    onLaunchParamsChanged: show()

    function show() {
        hideTimer.stop();
        win.visible = true;
        home.foreground = true;
        home.forceActiveFocus();
        home.loadInputs();
    }
    function hide() {
        home.foreground = false;   // runs the panel's 180 ms fade-out
        hideTimer.restart();
    }
    Timer { id: hideTimer; interval: 200; onTriggered: win.visible = false }

    Panel {
        id: home
        anchors.fill: parent
        foreground: true
        onCloseRequested: win.hide()
        // Original LG Home: SAM opens it as a card; we step aside.
        onStockRequested: http("/launch?id=com.webos.app.home", function() { win.hide(); })
        Component.onCompleted: { home.ready = true; home.loadInputs(); home.forceActiveFocus(); }
    }
}
