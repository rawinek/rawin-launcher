// Fragment, not a standalone file: tools/build.py puts it into Panel.qml in
// place of ui/Launcher.qml's Service elements (from "Service { id:
// launchService" up to "Timer { id: launchTimeout").
    // Overlay variant: Luna goes through the root helper over HTTP (webOS 10
    // answers nothing to a developer QML app). Same callService() shape as
    // the Service elements it replaces in ui/Launcher.qml.
    readonly property string helper: "http://127.0.0.1:8899"
    // GET, or POST with a JSON body.
    function http(pathname, done, failed, body) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            var answer = null;
            if (xhr.status === 200) { try { answer = JSON.parse(xhr.responseText); } catch (e) {} }
            if (answer) { if (done) done(answer); }
            else if (failed) failed(xhr.status);
        };
        var post = body !== undefined && body !== null;
        xhr.open(post ? "POST" : "GET", helper + pathname);
        if (post) { xhr.setRequestHeader("Content-Type", "application/json"); xhr.send(JSON.stringify(body)); }
        else xhr.send();
    }
    function loadInputs() {
        http("/inputs", function(r) { setInputs(r.devices ? inputsFrom(r.devices) : []); });
    }
    QtObject {
        id: launchService
        function callService(p) {
            shell.http("/launch?id=" + encodeURIComponent(p.id), function(r) {
                launching = false; launchTimeout.stop();
                if (r.returnValue) closeHome();
                else message = t("err_launch");
            }, function() {
                launching = false; launchTimeout.stop();
                message = t("err_helper");
            });
        }
    }
    // The helper can be a moment behind the panel: a HOME in the second
    // between Input Hook and the helper coming up after a boot, or an update
    // replacing the helper. A failed app list is asked for again every 1.5 s,
    // up to ten times in a row, while the panel is up.
    Timer {
        id: helperRetry
        interval: 1500
        property int left: 10
        onTriggered: if (shell.foreground) { catalog.callService({}); loadInputs(); }
    }
    function helperMissing() {
        if (helperRetry.running || helperRetry.left <= 0) return;
        helperRetry.left--;
        helperRetry.restart();
    }
    QtObject {
        id: catalog
        function callService(p) {
            shell.http("/apps", function(r) {
                helperRetry.left = 10;
                if (!r.apps) return;
                var next = [];
                for (var i=0; i<r.apps.length; i++) {
                    var a = r.apps[i];
                    if (Config.excluded.indexOf(a.id) >= 0) continue;
                    next.push({id: a.id, title: a.title, icon: a.icon ? shell.helper + "/" + a.icon : ""});
                }
                if (same(next, applications)) return;
                applications = next;
                if (page === "apps") selected = Math.max(0, Math.min(selected, apps.length-1));
            }, helperMissing);
        }
    }
    // The TV's language and the BACK-hold target go through the helper too.
    // Asked once at start, with whether LG's Home is still there to open.
    QtObject {
        id: localeService
        function callService(p) {
            shell.http("/locale", function(r) { if (r.locale) systemLang = r.locale; });
            shell.http("/home", function(r) { stockHomeAvailable = !!r.lgHome; });
        }
    }
    onExitTargetChosen: http("/exit-target?id=" + encodeURIComponent(target))
    // Updates: update.sh, run by the helper.
    function updateRun(step, channel) {
        http("/update?step=" + step + "&channel=" + channel,
             function(r) { updateResult(step, r); }, function() { updateResult(step, null); });
    }
    // The backup file, kept by the helper next to the launcher: written
    // with a POST, read back (info and load) with a GET.
    function backupRun(step, data) {
        if (step === "save") http("/backup", function(r) { backupResult("save", r); }, function() { backupResult("save", null); }, data);
        else http("/restore", function(r) { backupResult(step, r.saved ? r : null); }, function() { backupResult(step, null); });
    }
    // What stays visible under the overlay: the first card that is not us.
    QtObject {
        id: foregroundInfo
        function callService(p) {
            shell.http("/foreground", function(r) {
                nowTitle = "";
                var list = r.foregroundAppInfo || [];
                for (var i=0; i<list.length; i++) {
                    if (list[i].appId.indexOf("org.rawin.launcher") === 0 || list[i].windowType === "_WEBOS_WINDOW_TYPE_OVERLAY") continue;
                    if (describe(list[i].appId)) return;
                }
            });
        }
    }
