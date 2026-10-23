// Fragment, not a standalone file: tools/build.py puts it into Panel.qml in
// place of ui/Launcher.qml's Service elements (from "Service { id:
// launchService" up to "Timer { id: launchTimeout").
    // Overlay variant: Luna goes through the root helper over HTTP (webOS 10
    // answers nothing to a developer QML app). Same callService() shape as
    // the Service elements it replaces in ui/Launcher.qml.
    readonly property string helper: "http://127.0.0.1:8899"
    function http(pathname, done, failed) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            var body = null;
            if (xhr.status === 200) { try { body = JSON.parse(xhr.responseText); } catch (e) {} }
            if (body) { if (done) done(body); }
            else if (failed) failed(xhr.status);
        };
        xhr.open("GET", helper + pathname);
        xhr.send();
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
    QtObject {
        id: catalog
        function callService(p) {
            shell.http("/apps", function(r) {
                if (!r.apps) return;
                var next = [];
                for (var i=0; i<r.apps.length; i++) {
                    var a = r.apps[i];
                    if (Config.excluded.indexOf(a.id) >= 0) continue;
                    next.push({id: a.id, title: a.title, icon: a.icon ? shell.helper + "/" + a.icon : ""});
                }
                if (same(next, applications)) return;
                applications = next;
                if (page === "apps") selected = Math.max(0, Math.min(selected, next.length-1));
            });
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
