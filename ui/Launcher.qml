import QtQuick 2.6
import QtGraphicalEffects 1.0
import WebOSServices 1.0
import WebOS.Global 1.0
import "Config.js" as Config
import "Strings.js" as Strings
import "Themes.js" as Themes

FocusScope {
    id: shell
    property var hostWindow
    property bool ready: false
    property bool foreground: false
    // home, apps, system, or settings: the launcher settings menu.
    property string page: "home"
    property int selected: 0
    property bool launching: false
    property bool pressing: false
    property string message: ""
    // Every launch point the TV lists (minus the build's excluded ones).
    property var applications: Config.apps
    // Favourites are app ids; edited on the TV (hold OK) and saved by FavouriteStore.qml.
    property var favouriteIds: Config.favourites.slice(0)
    readonly property var favourites: resolveFavourites(favouriteIds, applications)
    readonly property var favouriteKeys: favourites.map(function(f) { return f.id; })
    readonly property int favCount: favourites.length
    // Rail places for favourites: one "Add favourites" tile while there are
    // none, but only once the app list is known (not while it is still loading).
    readonly property bool showAddTile: favCount === 0 && applications.length > 0
    readonly property int favSlots: favCount > 0 ? favCount : (showAddTile ? 1 : 0)
    readonly property int maxFavourites: 7
    // Hidden on the TV (RED): apps left out of Apps, inputs left off the rail.
    // Saved as "hidden" and "hiddenInputs"; the setting "showHidden" shows
    // them dimmed, so they can be shown again.
    property var hiddenIds: []
    property var hiddenInputs: []
    // How often each app was opened from here ("usage"): the Apps order "most used".
    property var usage: ({})
    // The glow colour read from each app's icon ("colors": {id: {icon, accent}}),
    // for the apps the build has no colour for. See glowReader.
    property var iconColors: ({})
    // Apps as the Apps page shows them: without the hidden ones unless asked,
    // in the TV's order, A to Z or most used first.
    readonly property var apps: appsFor(applications, hiddenIds, settings.sort, settings.showHidden)
    property int editIndex: -1
    property string notice: ""
    property bool okHeld: false
    property bool longFired: false
    // The TV's inputs, as many as it has (two on small sets, four on most),
    // less the hidden ones; then the sources on the rail: Live TV when
    // asked for, and the inputs. The rail, the navigation and the BACK-hold
    // target all follow these lists.
    property var allInputs: Config.inputs
    readonly property var inputs: inputsFor(allInputs, hiddenInputs, settings.showHidden)
    readonly property var tvSource: ({id: "com.webos.app.livetv", title: t("live_tv"), detail: "", present: true, kind: "tv"})
    readonly property var sources: (settings.tv ? [tvSource] : []).concat(inputs)
    readonly property int sourceCount: sources.length
    // The moment the clock shows (tick() moves it on the minute) and the
    // clock itself, in the setting's format: 24-hour or 12-hour.
    property var nowTime: new Date()
    readonly property string clock: Qt.formatTime(nowTime, settings.hours === "12" ? "h:mm AP" : "hh:mm")
    property string nowTitle: ""
    // Launcher settings, saved with the favourites (key "settings").
    // lang: "system" or a code from Strings.languages; theme: an id from
    // Themes.ids; size: the text size; motion: animations; sort: the Apps
    // order; tv: a Live TV source on the rail; showHidden: hidden apps and
    // inputs shown dimmed; exitTo (overlay only, sent to the helper): "last"
    // or an input app id; clock: the top bar; hours: its format, "24" or
    // "12"; title: the big name of the focused app on Home and Apps; beta:
    // updates also offer test builds (GitHub pre-releases).
    property var settings: validSettings({})
    property string systemLang: ""
    // The updater (Launcher settings → Updates): idle, checking, current,
    // available, downloading, ready, installing, done or failed; latest is the
    // version found, failed the text key of the failed step.
    property var updateInfo: ({state: "idle", latest: "", failed: ""})
    readonly property bool updateAvailable: updateInfo.state === "available"
    property real lastUpdateCheck: 0
    // The backup file next to the installed launcher: when it was saved.
    property var backupInfo: ({saved: ""})
    readonly property string lang: settings.lang && settings.lang !== "system" ? settings.lang : (Strings.supported(systemLang) || "en")
    // LG's own Home can be opened: always with the panel inside it; from the
    // overlay only when it was kept (the helper says so, see panel-bridge.qml).
    property bool stockHomeAvailable: Config.stockHome !== false
    readonly property var tools: toolsFor(lang, applications, stockHomeAvailable)
    // The settings menu: the settings in groups, each a key; the rows the
    // menu shows (a group's name, then its settings); the focused one's
    // values. pane 0 is the list of settings, pane 1 their values. The
    // keys and the values do not depend on the settings themselves, so
    // choosing a value does not rebuild the menu around it.
    readonly property var settingGroups: groupsFor(Config.exitTarget)
    readonly property var settingKeys: keysOf(settingGroups)
    readonly property var menuRows: rowsOf(settingGroups, lang)
    readonly property var settingsItems: settingKeys.map(function(k) { return settingFor(k); })
    property int pane: 0
    property int valueIndex: 0
    readonly property string valueKey: page === "settings" && selected < settingKeys.length ? settingKeys[selected] : ""
    readonly property var valueOptions: valueKey ? optionsFor(valueKey, lang, inputs) : []
    // In place of the favourites while there are none: OK opens Apps.
    readonly property var addFavouritesTile: ({title: t("add_favs_title"), action: "apps", symbol: "add"})
    signal stockRequested()
    signal closeRequested()
    signal exitTargetChosen(string target)

    // Spotlight B2: the focused item is named above a rail of rounded tiles,
    // its colour lights the bottom-left edge, the picture stays visible.
    // Colours come from the theme (Launcher settings → Theme, see Themes.js).
    readonly property var theme: Themes.palette(settings.theme)
    readonly property string ink: theme.ink
    readonly property string ink2: theme.ink2
    readonly property string ink3: theme.ink3
    readonly property string surface: theme.surface   // chips over the picture (status)
    readonly property string chip: theme.chip         // tiles and pills: solid, so nothing shows through
    readonly property string chipEdge: theme.chipEdge
    readonly property string neutral: theme.neutral
    readonly property string warning: theme.warning
    readonly property string fontName: inter.status === FontLoader.Ready ? inter.name : medium.name
    // The layout is drawn for 1920×1080 and scaled to the panel's real size:
    // the TV's UI runs at 1280×720 on HD sets and at 1920×1080 on FHD and UHD
    // ones (the TV scales it up to the panel). u is that scale; every length
    // below goes through px(). Positions hang from the bottom and the right
    // edge, so a wider screen simply gets a longer rail and more columns.
    // Text goes through pt(), which also takes the text size setting: the
    // tiles and pills keep their size (the rail is full with seven
    // favourites), the words on and around them grow.
    readonly property real u: width > 0 && height > 0 ? Math.min(width / 1920, height / 1080) : 1
    readonly property real textZoom: settings.size === "larger" ? 1.4 : settings.size === "large" ? 1.2 : 1
    function px(v) { return Math.round(v * u); }
    function pt(v) { return Math.round(v * u * textZoom); }
    // Animation lengths, or none with the setting "motion" off.
    function dur(ms) { return settings.motion === false ? 0 : ms; }
    readonly property int margin: px(96)
    readonly property int tile: px(120)
    readonly property int gap: px(24)
    readonly property int appColumns: Math.max(4, Math.floor((width - 2*margin + gap) / (tile + gap)))
    readonly property int railY: height - px(192)
    // The Home rail: favourites, the source pills, the two doors. The pills
    // get what is left of the width; the device name under "HDMI n" is cut
    // to that, down to a floor, so the rail never runs past the right margin.
    readonly property int railGroupGap: px(32)
    readonly property int favsWidth: favSlots > 0 ? favSlots*(tile + gap) - gap : 0
    readonly property int doorsWidth: 2*px(64) + px(12)
    readonly property int pillRoom: width - 2*margin - favsWidth - doorsWidth - railGroupGap*(favSlots > 0 ? 2 : 1) - px(12)*Math.max(0, sourceCount - 1)
    readonly property int pillTextCap: Math.max(px(64), Math.min(px(180), Math.floor(pillRoom / Math.max(1, sourceCount)) - px(44)))
    // The name sits just above the tiles; a line under it (editing help, a
    // message) lifts it by one line. Without the name (setting "title",
    // Home and Apps only) a line under it still shows, just above the tiles.
    readonly property bool showTitle: settings.title !== false || page === "system"
    readonly property int heroBaseline: height - (page === "apps" ? px(380) : px(238)) - (showTitle ? (hero.sub ? pt(36) : 0) : px(20))
    readonly property var hero: heroFor(page, selected, apps, favourites, editIndex, launching, message, notice, tools, sources, iconColors)
    readonly property var hints: hintsFor(page, selected, favouriteKeys, editIndex, lang, updateInfo, pane)
    property color glowColor: hero.color
    Behavior on glowColor { ColorAnimation { duration: shell.dur(300) } }

    function closeHome() { closeRequested(); }

    FontLoader { id: inter; source: "file:///var/lib/webosbrew/rawin-launcher/current/fonts/Inter-Regular.ttf" }
    FontLoader { id: interBold; source: "file:///var/lib/webosbrew/rawin-launcher/current/fonts/Inter-Bold.ttf" }
    FontLoader { id: medium; source: "file:///usr/share/fonts/MuseoSans-Medium.ttf" }

    function t(key) { return Strings.get(lang, key); }
    // Whether two lists hold the same things: the app and input lists are read
    // again each time Home opens, and only a changed list replaces the old
    // one, so the tiles are not torn down and built again for nothing.
    function same(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
    function installed(id, apps) {
        for (var i=0; i<apps.length; i++) if (apps[i].id === id) return true;
        return false;
    }
    function appById(id) {
        for (var i=0; i<applications.length; i++) if (applications[i].id === id) return applications[i];
        return null;
    }
    function toolsFor(language, apps, stockHome) {
        var list = [
            {title: t("tv_settings"), id: "com.palm.app.settings", symbol: "settings"},
            {title: t("launcher_settings"), action: "launcherSettings", symbol: "tune"},
            {title: "PicCap", id: "org.webosbrew.piccap", symbol: "light", optional: true},
            {title: "Homebrew Channel", id: "org.webosbrew.hbchannel", symbol: "plus"},
            {title: "LG Content Store", id: "com.webos.app.discovery", symbol: "bag"},
            {title: t("stock_home"), action: "stock", symbol: "home", stock: true},
            {title: t("back_to_picture"), action: "close", symbol: "back"}
        ];
        // PicCap only where it is installed; LG's Home only where it is reachable.
        return list.filter(function(x) {
            return !(x.optional && !installed(x.id, apps)) && !(x.stock && !stockHome);
        });
    }
    // The settings menu's groups: a name and the settings in it. The BACK-hold
    // target is the overlay's alone.
    function groupsFor(exitTarget) {
        return [
            {title: "grp_look", keys: ["lang", "theme", "size", "motion"]},
            {title: "grp_home", keys: exitTarget ? ["tv", "showHidden", "exitTo"] : ["tv", "showHidden"]},
            {title: "grp_apps", keys: ["sort"]},
            {title: "grp_screen", keys: ["clock", "hours", "title"]},
            {title: "grp_backup", keys: ["backup", "restore"]},
            {title: "grp_updates", keys: ["update", "beta"]}
        ];
    }
    function keysOf(groups) {
        var out = [];
        for (var i=0; i<groups.length; i++) out = out.concat(groups[i].keys);
        return out;
    }
    // The menu's rows: {header: name} before each group, {key, index} for
    // each setting; index counts the settings alone, as selected does.
    function rowsOf(groups, language) {
        var out = [], n = 0;
        for (var i=0; i<groups.length; i++) {
            out.push({header: t(groups[i].title)});
            for (var j=0; j<groups[i].keys.length; j++) out.push({key: groups[i].keys[j], index: n++});
        }
        return out;
    }
    // One setting as the menu shows it: its name, its value's name (or an
    // action's status), and what OK does with it.
    function settingFor(key) {
        var names = {lang: "set_language", theme: "set_theme", size: "set_size", motion: "set_motion", sort: "set_sort", tv: "set_tv",
                     showHidden: "set_hidden", exitTo: "set_exit", clock: "set_clock", hours: "set_hours", title: "set_title", backup: "set_backup",
                     restore: "set_restore", update: "set_update", beta: "set_beta"};
        var item = {key: key, title: t(names[key]), action: "setting", value: ""};
        if (key === "backup" || key === "restore") {
            item.action = key;
            // The day and the time, in the clock's format: short enough for the row.
            item.value = backupInfo.saved ? Strings.format(t("bak_saved"), {date: Qt.formatDateTime(new Date(backupInfo.saved), "d MMM " + (settings.hours === "12" ? "h:mm AP" : "hh:mm"))}) : t("bak_none");
        } else if (key === "update") {
            item.action = "update";
            item.value = updateText(updateInfo);
        } else item.value = valueTitle(key);
        return item;
    }
    function inputTitle(id) {
        for (var i=0; i<allInputs.length; i++) if (allInputs[i].id === id) return allInputs[i].title;
        return "HDMI " + id.slice(-1);
    }
    // The values of a setting, in the order the menu shows them.
    function optionsFor(key, language, inputList) {
        var list = [], i;
        if (key === "lang") {
            list.push({id: "system", title: Strings.format(t("val_system"), {lang: Strings.names[Strings.supported(systemLang) || "en"]})});
            for (i=0; i<Strings.languages.length; i++) list.push({id: Strings.languages[i], title: Strings.names[Strings.languages[i]]});
        } else if (key === "theme") {
            for (i=0; i<Themes.ids.length; i++) list.push({id: Themes.ids[i], title: t("theme_" + Themes.ids[i])});
        } else if (key === "size") {
            list = [{id: "normal", title: t("val_size_normal")}, {id: "large", title: t("val_size_large")}, {id: "larger", title: t("val_size_larger")}];
        } else if (key === "sort") {
            list = [{id: "lg", title: t("val_sort_lg")}, {id: "az", title: t("val_sort_az")}, {id: "used", title: t("val_sort_used")}];
        } else if (key === "showHidden") {
            list = [{id: false, title: t("val_hidden_hide")}, {id: true, title: t("val_hidden_show")}];
        } else if (key === "exitTo") {
            list.push({id: "last", title: t("val_last_input")});
            for (i=0; i<inputList.length; i++) list.push({id: inputList[i].id, title: inputList[i].title});
        } else if (key === "clock" || key === "tv") {
            list = [{id: true, title: t("val_show")}, {id: false, title: t("val_hide")}];
        } else if (key === "hours") {
            list = [{id: "24", title: t("val_hours_24")}, {id: "12", title: t("val_hours_12")}];
        } else if (key === "title") {
            list = [{id: true, title: t("val_name_show")}, {id: false, title: t("val_name_hide")}];
        } else if (key === "motion" || key === "beta") {
            list = [{id: true, title: t("val_on")}, {id: false, title: t("val_off")}];
        }
        return list;
    }
    function valueTitle(key) {
        var o = optionsFor(key, lang, inputs);
        for (var i=0; i<o.length; i++) if (o[i].id === settings[key]) return o[i].title;
        return "";
    }
    function updateText(u) {
        var v = {version: u.latest};
        if (u.state === "checking") return t("upd_checking");
        if (u.state === "current") return Strings.format(t("upd_current"), {version: Config.version});
        if (u.state === "available") return Strings.format(t("upd_available"), v);
        if (u.state === "downloading") return Strings.format(t("upd_downloading"), v);
        if (u.state === "ready") return Strings.format(t("upd_ready"), v);
        if (u.state === "installing") return Strings.format(t("upd_installing"), v);
        if (u.state === "done") return t("upd_done");
        if (u.state === "failed") return t(u.failed);
        return Strings.format(t("upd_idle"), {version: Config.version});
    }
    // What OK does on an action row: the verb for the hint, or nothing yet.
    function actionVerb(key) {
        if (key === "backup") return t("hint_backup");
        if (key === "restore") return backupInfo.saved ? t("hint_restore") : "";
        if (key === "update") {
            var s = updateInfo.state;
            return s === "available" ? t("hint_download") : s === "ready" ? t("hint_install")
                : ["idle", "current", "failed"].indexOf(s) >= 0 ? t("hint_check") : "";
        }
        return "";
    }
    // OK on Updates: check, download what was found, install what was downloaded.
    function updateAction() {
        var s = updateInfo.state;
        if (s === "available") updateStep("download");
        else if (s === "ready") updateStep("install");
        else if (s === "idle" || s === "current" || s === "failed") updateStep("check");
    }
    function isUpdateIdle() {
        return ["checking", "downloading", "installing", "done"].indexOf(updateInfo.state) < 0;
    }
    function updateStep(step) {
        var busy = {check: "checking", download: "downloading", install: "installing"}[step];
        if (busy) setUpdate({state: busy});
        updateRun(step, settings.beta ? "test" : "stable");
    }
    function setUpdate(change) {
        var next = {}, k;
        for (k in updateInfo) next[k] = updateInfo[k];
        for (k in change) next[k] = change[k];
        updateInfo = next;
    }
    // The answer of one update.sh step (null: no answer).
    function updateResult(step, r) {
        var ok = !!(r && r.ok);
        if (step === "check") setUpdate(ok ? {state: r.newer ? "available" : "current", latest: r.latest} : {state: "failed", failed: "upd_err_check"});
        else if (step === "download") setUpdate(ok ? {state: "ready"} : {state: "failed", failed: "upd_err_download"});
        else if (step === "install") {
            if (ok) installPoll.restart();
            else setUpdate({state: "failed", failed: "upd_err_install"});
        } else if (step === "status" && ok) {
            // On success the installer restarts the launcher, which ends this
            // panel; "done" shows only if it is still here.
            if (r.state === "failed") { installPoll.stop(); setUpdate({state: "failed", failed: "upd_err_install"}); }
            else if (r.state === "done") { installPoll.stop(); setUpdate({state: "done"}); }
        }
    }
    Timer { id: installPoll; interval: 2000; repeat: true; onTriggered: updateRun("status", "stable") }
    // Once a day, the first time Home opens: is there a new version? A dot
    // on System and on Launcher settings says so (updateAvailable).
    function dailyUpdateCheck() {
        if (!isUpdateIdle() || Date.now() - lastUpdateCheck < 86400000) return;
        lastUpdateCheck = Date.now();
        updateStep("check");
    }
    // One setting to a value; the change applies at once.
    function setSetting(key, value) {
        if (settings[key] === value) return;
        var next = {};
        for (var k in settings) next[k] = settings[k];
        next[key] = value;
        settings = next;
        saveSettings();
        if (key === "exitTo") exitTargetChosen(value);
        if (key === "beta" && isUpdateIdle()) updateStep("check");
    }
    // The settings as saved, each checked, with the defaults for the rest.
    function validSettings(s) {
        s = s && typeof s === "object" ? s : {};
        return {
            lang: s.lang === "system" || Strings.languages.indexOf(s.lang) >= 0 ? s.lang : "system",
            theme: Themes.ids.indexOf(s.theme) >= 0 ? s.theme : "default",
            size: ["normal", "large", "larger"].indexOf(s.size) >= 0 ? s.size : "normal",
            motion: s.motion !== false,
            sort: ["lg", "az", "used"].indexOf(s.sort) >= 0 ? s.sort : "lg",
            tv: s.tv === true,
            showHidden: s.showHidden === true,
            exitTo: /^(last|com\.webos\.app\.(hdmi|dp|usbc)\d)$/.test(s.exitTo) ? s.exitTo : "last",
            clock: s.clock !== false,
            hours: s.hours === "12" ? "12" : "24",
            title: s.title !== false,
            beta: s.beta === true
        };
    }
    function saveSettings() { save(settings, "settings"); }
    function loadSettings() {
        try { settings = validSettings(store.item.load("settings")); } catch (e) {}
        if (Config.exitTarget) exitTargetChosen(settings.exitTo);
    }
    // One saved slot: a list or an object, or null when nothing is there.
    function save(value, key) {
        try { if (store.item) store.item.save(value, key); } catch (e) {}
    }
    function loaded(key, fallback) {
        try { var v = store.item.load(key); if (v !== null && v !== undefined) return v; } catch (e) {}
        return fallback;
    }
    function loadExtras() {
        var h = loaded("hidden", []), hi = loaded("hiddenInputs", []);
        hiddenIds = h.length !== undefined ? h : [];
        hiddenInputs = hi.length !== undefined ? hi : [];
        var u = loaded("usage", {}), c = loaded("colors", {});
        usage = typeof u === "object" && u.length === undefined ? u : {};
        iconColors = typeof c === "object" && c.length === undefined ? c : {};
    }
    // The glow colour of an app: from the build, else from its icon, else neutral.
    function styleFor(id) {
        var s = Config.styles ? Config.styles[id] : null;
        if (s && s.accent) return {accent: s.accent};
        var c = iconColors[id];
        return {accent: c && c.accent ? c.accent : neutral};
    }
    // Installed apps only, in the saved order; an uninstalled favourite simply disappears.
    function resolveFavourites(ids, apps) {
        var out = [];
        for (var i=0; i<ids.length && out.length < maxFavourites; i++) {
            for (var j=0; j<apps.length; j++) {
                if (apps[j].id !== ids[i]) continue;
                out.push({id: apps[j].id, title: apps[j].title, icon: apps[j].icon});
                break;
            }
        }
        return out;
    }
    function appsFor(all, hidden, sort, showHidden) {
        var list = all.filter(function(a) { return showHidden || hidden.indexOf(a.id) < 0; });
        if (sort === "az") list.sort(function(a, b) { return a.title.localeCompare(b.title); });
        else if (sort === "used") {
            // usage is read here, and only here, so the list follows the
            // counts only in this order.
            var counts = shell.usage;
            list.sort(function(a, b) { return (counts[b.id] || 0) - (counts[a.id] || 0) || a.title.localeCompare(b.title); });
        }
        return list;
    }
    function inputsFor(list, hidden, showHidden) {
        var out = [];
        for (var i=0; i<list.length; i++) {
            var d = list[i], h = hidden.indexOf(d.id) >= 0;
            if (h && !showHidden) continue;
            out.push({id: d.id, title: d.title, detail: d.detail || "", present: d.present !== false, kind: "input", hidden: h});
        }
        return out;
    }
    // Opened from here: counts for the "most used" order.
    function noteLaunch(id) {
        if (!appById(id)) return;
        var u = {}, k;
        for (k in usage) u[k] = usage[k];
        u[id] = (u[id] || 0) + 1;
        usage = u;
        save(usage, "usage");
    }
    function heroFor(currentPage, index, appList, favs, editing, busy, error, note, toolList, sourceList, colors) {
        var h, n = favs.length;
        if (currentPage === "apps") {
            var app = appList[index] || {title: ""};
            h = {title: app.title, sub: hiddenIds.indexOf(app.id) >= 0 ? t("hidden_sub") : "", color: styleFor(app.id).accent};
        } else if (currentPage === "system") {
            var tool = toolList[index] || {title: ""};
            h = {title: tool.title, sub: "", color: neutral};
        } else if (currentPage === "settings") {
            h = {title: "", sub: "", color: neutral};
        } else if (showAddTile && index === 0) {
            h = {title: t("add_favs_title"), sub: t("add_favs_sub"), color: neutral};
        } else if (index < n) {
            var f = favs[index];
            h = {title: f.title, sub: editing >= 0 ? t("edit_sub") : "", color: styleFor(f.id).accent};
        } else if (index < favSlots + sourceList.length) {
            var source = sourceList[index - favSlots];
            h = {title: source.title, sub: source.hidden ? t("hidden_sub") : "", color: neutral};
        } else if (index === favSlots + sourceList.length) {
            h = {title: t("apps_title"), sub: "", color: neutral};
        } else {
            h = {title: t("system_title"), sub: "", color: neutral};
        }
        if (error) h.sub = error;
        else if (busy) h.sub = t("opening");
        else if (note) h.sub = note;
        return h;
    }
    function hintsFor(currentPage, index, keys, editing, language, upd, currentPane) {
        var red = t("key_red");
        if (currentPage === "apps") {
            var app = apps[index];
            var fav = app && keys.indexOf(app.id) >= 0, hid = app && hiddenIds.indexOf(app.id) >= 0;
            return [["OK", t("hint_open")], [t("hint_hold_ok"), fav ? t("hint_remove_fav") : t("hint_add_fav")],
                    [red, hid ? t("hint_unhide") : t("hint_hide")], [t("hint_back"), t("hint_favourites")]];
        }
        if (currentPage === "system") return [["OK", t("hint_open")], [t("hint_back"), t("hint_favourites")]];
        if (currentPage === "settings") {
            if (currentPane === 1) return [["▲ ▼", t("hint_choose")], ["OK", t("hint_done")]];
            var key = settingKeys[index], verb = actionVerb(key);
            if (key === "backup" || key === "restore" || key === "update")
                return verb ? [["OK", verb], [t("hint_back"), t("hint_system")]] : [[t("hint_back"), t("hint_system")]];
            return [["OK", t("hint_change")], [t("hint_back"), t("hint_system")]];
        }
        if (editing >= 0) return [["OK", t("hint_done")]];
        if (index < keys.length) return [["OK", t("hint_open")], [t("hint_hold_ok"), t("hint_edit_favs")]];
        if (index < favSlots) return [["OK", t("hint_open")]];   // the "Add favourites" tile
        if (index < favSlots + sourceCount) {
            var s = sources[index - favSlots], list = [["OK", t("hint_open")]];
            if (s.kind === "input" && Config.exitTarget) list.push([t("hint_hold_ok"), t("hint_back_target")]);
            if (s.kind === "input") list.push([red, s.hidden ? t("hint_unhide") : t("hint_hide")]);
            return list;
        }
        return [["OK", t("hint_open")]];
    }

    function saveFavourites() {
        if (!store.item) { message = t("err_store_unavailable"); return; }
        try { store.item.save(favouriteIds, "favourites"); }
        catch (e) { message = t("err_save"); }
    }
    // The list saved on the TV wins over the build's defaults. With nothing
    // saved yet, the build's preset becomes the TV's own list at once, so a
    // later version with other defaults (an update) never changes it.
    function loadFavourites() {
        try {
            var ids = store.item.load("favourites");
            if (ids && ids.length !== undefined) favouriteIds = ids;
            else if (favouriteIds.length) store.item.save(favouriteIds, "favourites");
        } catch (e) {}
    }
    function setFavourites(ids) { favouriteIds = ids; saveFavourites(); }
    function toggleFavourite(app) {
        var ids = favouriteKeys.slice(0), at = ids.indexOf(app.id);
        if (at >= 0) { ids.splice(at, 1); notice = t("removed_fav"); }
        else if (ids.length >= maxFavourites) { notice = Strings.format(t("max_favs"), {n: maxFavourites}); return; }
        else { ids.push(app.id); notice = t("added_fav"); }
        setFavourites(ids);
    }
    function moveFavourite(from, to) {
        var ids = favouriteKeys.slice(0), id = ids[from];
        ids[from] = ids[to]; ids[to] = id;
        setFavourites(ids);
        editIndex = to; selected = to;
    }
    function removeFavourite(index) {
        var ids = favouriteKeys.slice(0);
        ids.splice(index, 1);
        editIndex = -1;
        setFavourites(ids);
        selected = Math.max(0, Math.min(index, ids.length-1));
        notice = t("removed_fav");
    }
    // RED: hide an app from Apps (and drop it from the favourites), or show
    // it again; hide an input from the rail, or show it again.
    function toggleHidden(app) {
        var ids = hiddenIds.slice(0), at = ids.indexOf(app.id);
        if (at >= 0) { ids.splice(at, 1); notice = t("unhidden_app"); }
        else {
            ids.push(app.id); notice = t("hidden_app");
            var favs = favouriteKeys.slice(0), f = favs.indexOf(app.id);
            if (f >= 0) { favs.splice(f, 1); setFavourites(favs); }
        }
        hiddenIds = ids;
        save(hiddenIds, "hidden");
        selected = Math.max(0, Math.min(selected, apps.length-1));
    }
    function toggleHiddenInput(id) {
        var ids = hiddenInputs.slice(0), at = ids.indexOf(id);
        if (at >= 0) { ids.splice(at, 1); notice = t("unhidden_input"); }
        else { ids.push(id); notice = t("hidden_input"); }
        hiddenInputs = ids;
        save(hiddenInputs, "hiddenInputs");
        selected = Math.max(0, Math.min(selected, favSlots + sourceCount + 1));
    }
    function hideAction() {
        if (!ready || launching) return;
        if (page === "apps") { if (apps[selected]) toggleHidden(apps[selected]); }
        else if (page === "home" && selected >= favSlots && selected < favSlots + sourceCount) {
            var s = sources[selected - favSlots];
            if (s.kind === "input") toggleHiddenInput(s.id);
        }
    }
    // Hold OK (or the yellow key): edit a favourite on Home, make an input
    // the BACK-hold target; toggle a favourite in Apps.
    function secondaryAction() {
        if (!ready || launching) return;
        if (page === "apps") { if (apps[selected]) toggleFavourite(apps[selected]); }
        else if (page !== "home") return;
        else if (selected < favCount) { editIndex = editIndex === selected ? -1 : selected; notice = ""; }
        else if (selected >= favSlots && selected < favSlots + sourceCount) {
            var s = sources[selected - favSlots];
            if (s.kind === "input" && Config.exitTarget) { setSetting("exitTo", s.id); notice = Strings.format(t("exit_set"), {name: s.title}); }
        }
    }
    // The TV's inputs from eim getAllInputStatus: HDMI, and DisplayPort or
    // USB-C where a set has them. The device under each is its HDMI-CEC name
    // (subList SIMPLINK osdName), else the input's own label when it is not
    // just "HDMI n" (e.g. a name set on the TV), else nothing.
    function inputsFrom(devices) {
        var next = [];
        for (var i=0; i<devices.length; i++) {
            var d = devices[i];
            var kind = !d.appId ? "" : d.appId.indexOf("com.webos.app.hdmi") === 0 ? "HDMI"
                : d.appId.indexOf("com.webos.app.dp") === 0 ? "DP" : d.appId.indexOf("com.webos.app.usbc") === 0 ? "USB-C" : "";
            if (!kind) continue;
            var title = kind === "HDMI" ? "HDMI " + d.port : (d.label || kind + " " + d.port);
            var name = "", subs = d.subList || [];
            for (var j=0; j<subs.length; j++) if (subs[j].id === "SIMPLINK" && subs[j].osdName) { name = subs[j].osdName; break; }
            if (!name && d.label && d.label !== title) name = d.label;
            // Something is plugged in: the TV says so (webOS 4: hdmiPlugIn,
            // webOS 10: activate) or a device answers over HDMI-CEC.
            var present = !!(d.hdmiPlugIn || d.activate || subs.some(function(s) { return s.id === "SIMPLINK" && s.osdName; }));
            next.push({id: d.appId, title: title, detail: name, present: present});
        }
        return next;
    }
    function setInputs(next) {
        if (next.length && !same(next, allInputs)) allInputs = next;
    }
    function describe(appId) {
        if (!appId || appId === "com.webos.app.home") return false;
        for (var i=0; i<allInputs.length; i++) if (allInputs[i].id === appId) { nowTitle = allInputs[i].title; return true; }
        for (var j=0; j<applications.length; j++) if (applications[j].id === appId) { nowTitle = applications[j].title; return true; }
        nowTitle = appId === "com.webos.app.livetv" ? t("live_tv") : appId;
        return true;
    }
    // Into the values of the focused setting, on its current value.
    function enterValues() {
        var options = valueOptions, at = 0;
        if (!valueKey || settingFor(valueKey).action !== "setting") return;
        for (var i=0; i<options.length; i++) if (options[i].id === settings[valueKey]) at = i;
        valueIndex = at;
        pane = 1;
    }
    // In the values the focused one is the chosen one: moving along them is
    // the preview, OK and left keep it.
    function applyValue() {
        var o = valueOptions[valueIndex];
        if (page === "settings" && pane === 1 && o) setSetting(valueKey, o.id);
    }
    onValueIndexChanged: applyValue()
    function activate(item) {
        if (!ready || launching || !item) return;
        message = "";
        if (item.action === "stock") { stockRequested(); return; }
        if (item.action === "close") { closeHome(); return; }
        if (item.action === "setting") { if (pane === 1) pane = 0; else enterValues(); return; }
        if (item.action === "update") { updateAction(); return; }
        if (item.action === "backup") { backupRun("save", backupData()); return; }
        if (item.action === "restore") { if (backupInfo.saved) backupRun("load", null); return; }
        if (item.action === "launcherSettings") {
            page = "settings"; selected = 0; pane = 0;
            // Look for a new version each time the settings open, unless one
            // is already found; and whether there is a backup to restore.
            var s = updateInfo.state;
            if (s === "idle" || s === "current" || s === "failed") updateStep("check");
            backupRun("info", null);
            return;
        }
        if (item.action === "apps" || item.action === "system") {
            page = item.action; selected = 0; return;
        }
        noteLaunch(item.id);
        launching = true;
        launchTimeout.restart();
        launchService.callService({id: item.id, params: {}, reason: "launcher"});
    }
    function itemAt(index) {
        if (page === "apps") return apps[index];
        if (page === "system") return tools[index];
        if (page === "settings") return settingsItems[index];
        if (showAddTile && index === 0) return addFavouritesTile;
        if (index < favCount) return favourites[index];
        if (index < favSlots + sourceCount) return sources[index - favSlots];
        return index === favSlots + sourceCount ? {title: t("apps_title"), action: "apps", symbol: "apps"} : {title: t("system_title"), action: "system", symbol: "settings"};
    }
    // Favourites and settings, in one file next to the launcher on the TV.
    function backupData() {
        return {saved: new Date().toISOString(), version: Config.version, favourites: favouriteIds, settings: settings,
                hidden: hiddenIds, hiddenInputs: hiddenInputs, usage: usage};
    }
    function applyBackup(b) {
        if (!b || typeof b !== "object" || !b.saved) return false;
        if (b.favourites && b.favourites.length !== undefined) setFavourites(b.favourites.slice(0, maxFavourites));
        settings = validSettings(b.settings); saveSettings();
        if (Config.exitTarget) exitTargetChosen(settings.exitTo);
        hiddenIds = b.hidden && b.hidden.length !== undefined ? b.hidden : []; save(hiddenIds, "hidden");
        hiddenInputs = b.hiddenInputs && b.hiddenInputs.length !== undefined ? b.hiddenInputs : []; save(hiddenInputs, "hiddenInputs");
        usage = b.usage && typeof b.usage === "object" ? b.usage : {}; save(usage, "usage");
        return true;
    }
    // The answer of one backup step: info and load bring the file's
    // contents (null: no file or no answer), save says whether it was written.
    function backupResult(step, r) {
        if (step === "save") {
            if (r && r.ok) { notice = t("bak_done"); backupRun("info", null); }
            else message = t("bak_err");
        } else if (step === "info") {
            backupInfo = {saved: r && r.saved ? String(r.saved) : ""};
        } else if (step === "load") {
            if (applyBackup(r)) notice = t("bak_restored");
            else message = t("bak_err_read");
        }
    }
    // Home and System are one rail; All applications is a grid of appColumns;
    // the settings are a menu of rows with the values of one beside them.
    function isOk(key) { return key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Select; }
    function isBack(key) { return key === WebOS.Key_webOS_Back || key === Qt.Key_Escape || key === Qt.Key_Back || key === Qt.Key_Backspace || key === 461; }
    function isYellow(key) { return key === WebOS.Key_webOS_Yellow || key === 405; }
    function isRed(key) { return key === WebOS.Key_webOS_Red || key === 403; }
    function navigateMenu(key) {
        if (pane === 1) {
            if (key === Qt.Key_Up) { if (valueIndex > 0) valueIndex--; }
            else if (key === Qt.Key_Down) { if (valueIndex < valueOptions.length-1) valueIndex++; }
            else if (key === Qt.Key_Left || isOk(key) || isBack(key)) pane = 0;
            else return false;
            return true;
        }
        if (key === Qt.Key_Up) { if (selected > 0) selected--; }
        else if (key === Qt.Key_Down) { if (selected < settingKeys.length-1) selected++; }
        else if (key === Qt.Key_Right) enterValues();
        else if (isOk(key)) activate(itemAt(selected));
        else if (isBack(key)) { page = "system"; selected = toolIndex("launcherSettings"); }
        else return false;
        return true;
    }
    function navigate(key) {
        notice = "";
        if (page === "settings") return navigateMenu(key);
        // Editing a favourite: arrows move it, DOWN removes it, OK/BACK/UP finish.
        if (page === "home" && editIndex >= 0) {
            if (key === Qt.Key_Left) { if (editIndex > 0) moveFavourite(editIndex, editIndex-1); }
            else if (key === Qt.Key_Right) { if (editIndex < favCount-1) moveFavourite(editIndex, editIndex+1); }
            else if (key === Qt.Key_Down) removeFavourite(editIndex);
            else if (isOk(key) || isBack(key) || key === Qt.Key_Up) editIndex = -1;
            else return false;
            return true;
        }
        var count = page === "home" ? favSlots+sourceCount+2 : page === "apps" ? apps.length : tools.length;
        var columns = page === "apps" ? appColumns : count;
        if (key === Qt.Key_Left) { if (selected % columns > 0) selected--; }
        else if (key === Qt.Key_Right) { if (selected % columns < columns-1 && selected+1 < count) selected++; }
        else if (key === Qt.Key_Up) { if (selected-columns >= 0) selected -= columns; }
        else if (key === Qt.Key_Down) {
            if (selected+columns < count) selected += columns;
            else if (Math.floor(selected/columns) < Math.floor((count-1)/columns)) selected = count-1;
        } else if (isOk(key)) activate(itemAt(selected));
        else if (isBack(key)) {
            if (page === "home") closeHome();
            else { selected = favSlots + sourceCount + (page === "apps" ? 0 : 1); page = "home"; }
        } else return false;
        return true;
    }
    function toolIndex(action) {
        for (var i=0; i<tools.length; i++) if (tools[i].action === action) return i;
        return 0;
    }
    function actionKey(key) { return isOk(key) || isBack(key); }
    // Activate on release: switching focus on press would deliver the same
    // OK release to LG's ribbon and accidentally launch a second application.
    // Holding OK past holdTimer runs secondaryAction instead of activating.
    Keys.onPressed: {
        if (isYellow(event.key) || isRed(event.key)) { event.accepted=true; return; }
        if (actionKey(event.key)) {
            event.accepted=true;
            if (isOk(event.key) && !event.isAutoRepeat && !okHeld) {
                okHeld=true; longFired=false; pressing=true; holdTimer.restart();
            }
        }
        else if (navigate(event.key)) event.accepted=true;
    }
    Keys.onReleased: {
        if (isYellow(event.key)) { event.accepted=true; if (!event.isAutoRepeat) secondaryAction(); return; }
        if (isRed(event.key)) { event.accepted=true; if (!event.isAutoRepeat) hideAction(); return; }
        if (!actionKey(event.key)) return;
        event.accepted=true;
        if (event.isAutoRepeat) return;
        if (isOk(event.key)) {
            okHeld=false; holdTimer.stop(); pressing=false;
            if (longFired) { longFired=false; return; }
        }
        navigate(event.key);
    }
    Timer { id: holdTimer; interval: 700; onTriggered: { if (okHeld) { longFired=true; pressing=false; secondaryAction(); } } }
    Loader { id: store; source: "FavouriteStore.qml"; onLoaded: { shell.loadFavourites(); shell.loadSettings(); shell.loadExtras(); } }
    onForegroundChanged: {
        pressing = false; okHeld = false; longFired = false; holdTimer.stop();
        editIndex = -1; notice = "";
        if (foreground) {
            launching = false; message = ""; page="home"; selected=0; pane=0; forceActiveFocus();
            tick();
            if (ready) { catalog.callService({}); foregroundInfo.callService({extraInfo: true}); loadInputs(); dailyUpdateCheck(); }
        }
    }
    onReadyChanged: {
        if (!ready) return;
        localeService.callService({keys: ["localeInfo"]});
        catalog.callService({});
        loadInputs();
        if (foreground) { foregroundInfo.callService({extraInfo: true}); dailyUpdateCheck(); }
    }
    onVisibleChanged: { if (visible && foreground) forceActiveFocus(); }
    Component.onCompleted: tick()
    // The clock changes on the minute: each tick sets the next one for when
    // the minute turns, so the bar is never half a minute behind.
    function tick() {
        var now = new Date();
        nowTime = now;
        clockTimer.interval = 60000 - (now.getSeconds()*1000 + now.getMilliseconds()) + 50;
    }
    Timer { id: clockTimer; interval: 60000; repeat: true; running: shell.foreground; onTriggered: tick() }

    // The glow colour of an app from its icon, for the apps the build has
    // no colour for: the icon is drawn small and its vivid pixels averaged
    // (grey, white and black count for little), once per icon, and kept in
    // "colors" with the icon's path, so a changed icon is read again.
    onApplicationsChanged: glowReader.queueAll()
    Canvas {
        id: glowReader
        // Off screen and see-through, not invisible: an invisible Canvas
        // may never get to paint.
        x: -100; y: -100; opacity: 0
        width: 24; height: 24
        renderStrategy: Canvas.Immediate
        renderTarget: Canvas.Image
        property var queue: []
        property string current: ""
        property var pending: ({})
        function queueAll() {
            var next = [];
            for (var i=0; i<shell.applications.length; i++) {
                var a = shell.applications[i], known = shell.iconColors[a.id];
                if (!a.icon || (Config.styles && Config.styles[a.id] && Config.styles[a.id].accent)) continue;
                if (known && known.icon === a.icon) continue;
                next.push(a);
            }
            queue = next;
            if (!current) step();
        }
        function step() {
            if (!queue.length) { current = ""; return; }
            var a = queue.shift();
            current = a.id;
            if (isImageLoaded(a.icon)) requestPaint();
            else loadImage(a.icon);
        }
        onImageLoaded: {
            var a = shell.appById(current);
            if (a && isImageLoaded(a.icon)) requestPaint();
            else step();
        }
        onPaint: {
            var a = shell.appById(current);
            if (!a) return;
            var c = getContext("2d");
            c.clearRect(0, 0, width, height);
            var accent = "";
            try {
                c.drawImage(a.icon, 0, 0, width, height);
                accent = shell.vividColor(c.getImageData(0, 0, width, height).data);
            } catch (e) {}
            unloadImage(a.icon);
            if (accent) {
                pending[a.id] = {icon: a.icon, accent: accent};
                flush.restart();
            }
            step();
        }
        // Several icons in one go: one new iconColors object (one glow
        // update) and one save for the batch.
        Timer {
            id: flush
            interval: 400
            onTriggered: {
                var next = {}, k;
                for (k in shell.iconColors) next[k] = shell.iconColors[k];
                for (k in glowReader.pending) next[k] = glowReader.pending[k];
                glowReader.pending = {};
                shell.iconColors = next;
                shell.save(next, "colors");
            }
        }
    }
    // The colour of an icon's vivid pixels, lifted to glow strength.
    function vividColor(data) {
        var r = 0, g = 0, b = 0, w = 0, ar = 0, ag = 0, ab = 0, n = 0;
        for (var i=0; i<data.length; i+=4) {
            var R = data[i], G = data[i+1], B = data[i+2], A = data[i+3];
            if (A < 128) continue;
            var max = Math.max(R, G, B), min = Math.min(R, G, B);
            var s = max ? (max - min) / max : 0, v = max / 255;
            var weight = s * s * v;
            r += R * weight; g += G * weight; b += B * weight; w += weight;
            ar += R; ag += G; ab += B; n++;
        }
        if (!n) return "";
        var out = w > n * 0.02 ? [r / w, g / w, b / w] : [ar / n, ag / n, ab / n];
        // Too dark to glow: brighten, keeping the hue.
        var top = Math.max(out[0], out[1], out[2]);
        if (top < 140 && top > 0) out = out.map(function(v) { return v * 140 / top; });
        return "#" + out.map(function(v) { var s = Math.round(Math.min(255, v)).toString(16); return s.length < 2 ? "0" + s : s; }).join("");
    }

    Service {
        id: launchService
        appId: "com.webos.app.home"
        service: "com.webos.applicationManager"
        method: "launch"
        onCallSuccess: {
            launching = false; launchTimeout.stop();
            if (hostWindow && hostWindow.interfaces.application) hostWindow.interfaces.application.hideApp();
        }
        onCallFailure: { launching = false; launchTimeout.stop(); message = t("err_launch"); }
        onError: { launching = false; launchTimeout.stop(); message = t("err_unavailable"); }
    }
    Service {
        id: catalog
        appId: "com.webos.app.home"
        service: "com.webos.applicationManager"
        method: "listLaunchPoints"
        onCallSuccess: {
            if (!response.launchPoints) return;
            var next = [], seen = {};
            for (var i=0; i<response.launchPoints.length; i++) {
                var entry=response.launchPoints[i];
                if (seen[entry.id] || Config.excluded.indexOf(entry.id)>=0) continue;
                seen[entry.id]=true;
                var icon = entry.largeIcon || entry.icon;
                next.push({id: entry.id, title: entry.title || entry.id, icon: icon ? "file://"+icon : ""});
            }
            if (same(next, applications)) return;
            applications=next;
            if (page === "apps") selected=Math.max(0, Math.min(selected, apps.length-1));
        }
    }
    // What stays visible under the transparent top: the card behind Home.
    Service {
        id: foregroundInfo
        appId: "com.webos.app.home"
        service: "com.webos.applicationManager"
        method: "getForegroundAppInfo"
        onCallSuccess: {
            nowTitle = "";
            var list = response.foregroundAppInfo || [];
            for (var i=0; i<list.length; i++) if (describe(list[i].appId)) return;
            describe(response.appId);
        }
    }
    // The TV's language, used while the launcher language is "system".
    Service {
        id: localeService
        appId: "com.webos.app.home"
        service: "com.webos.settingsservice"
        method: "getSystemSettings"
        onCallSuccess: {
            var info = response.settings ? response.settings.localeInfo : null;
            if (info && info.locales && info.locales.UI) systemLang = info.locales.UI;
        }
    }
    // Inputs and the devices on them, read again each time Home opens.
    function loadInputs() { inputService.callService({}); }
    Service {
        id: inputService
        appId: "com.webos.app.home"
        service: "com.webos.service.eim"
        method: "getAllInputStatus"
        onCallSuccess: setInputs(response.devices ? inputsFrom(response.devices) : [])
    }
    // Updates: update.sh, run as root through the Homebrew Channel's exec.
    function updateRun(step, channel) {
        updateService.step = step;
        updateService.callService({command: "sh /var/lib/webosbrew/rawin-launcher/update.sh " + step + " " + channel});
    }
    Service {
        id: updateService
        property string step: ""
        appId: "com.webos.app.home"
        service: "org.webosbrew.hbchannel.service"
        method: "exec"
        onCallSuccess: {
            var r = null;
            try { r = JSON.parse(String(response.stdoutString || "").trim().split("\n").pop()); } catch (e) {}
            updateResult(step, r);
        }
        onCallFailure: updateResult(step, null)
        onError: updateResult(step, null)
    }
    // The backup file, through the same exec: written with printf (the JSON
    // in single quotes, its own quotes escaped), read back with cat.
    readonly property string backupFile: "/var/lib/webosbrew/rawin-launcher/backup.json"
    function backupRun(step, data) {
        backupService.step = step;
        var command = step === "save"
            ? "printf '%s' '" + JSON.stringify(data).replace(/'/g, "'\\''") + "' > " + backupFile + " && echo '{\"ok\":true}'"
            : "cat " + backupFile + " 2>/dev/null || echo null";
        backupService.callService({command: command});
    }
    Service {
        id: backupService
        property string step: ""
        appId: "com.webos.app.home"
        service: "org.webosbrew.hbchannel.service"
        method: "exec"
        onCallSuccess: {
            var r = null;
            try { r = JSON.parse(String(response.stdoutString || "").trim()); } catch (e) {}
            backupResult(step, r);
        }
        onCallFailure: backupResult(step, null)
        onError: backupResult(step, null)
    }
    Timer { id: launchTimeout; interval: 8000; onTriggered: { launching=false; message=t("err_slow"); } }

    function drawGlyph(c, symbol) {
        c.beginPath();
        if (symbol === "settings") {
            c.moveTo(6,12); c.lineTo(23,12); c.moveTo(31,12); c.lineTo(34,12);
            c.moveTo(6,28); c.lineTo(9,28); c.moveTo(17,28); c.lineTo(34,28); c.stroke();
            c.beginPath(); c.arc(27,12,4,0,Math.PI*2); c.stroke();
            c.beginPath(); c.arc(13,28,4,0,Math.PI*2);
        } else if (symbol === "light") {
            c.roundedRect(9,11,22,16,3,3); c.moveTo(4,8); c.lineTo(4,32); c.moveTo(36,8); c.lineTo(36,32); c.moveTo(14,33); c.lineTo(26,33);
        } else if (symbol === "plus") {
            c.moveTo(8,14); c.lineTo(20,7); c.lineTo(32,14); c.lineTo(32,26); c.lineTo(20,33); c.lineTo(8,26); c.closePath();
            c.moveTo(20,15); c.lineTo(20,25); c.moveTo(15,20); c.lineTo(25,20);
        } else if (symbol === "bag") {
            c.moveTo(9,14); c.lineTo(31,14); c.lineTo(29,33); c.lineTo(11,33); c.closePath();
            c.moveTo(15,14); c.lineTo(15,12); c.arc(20,12,5,Math.PI,0,false); c.lineTo(25,14);
        } else if (symbol === "home") {
            c.moveTo(6,19); c.lineTo(20,8); c.lineTo(34,19); c.moveTo(10,16); c.lineTo(10,33); c.lineTo(30,33); c.lineTo(30,16);
            c.moveTo(17,33); c.lineTo(17,25); c.lineTo(23,25); c.lineTo(23,33);
        } else if (symbol === "back") {
            c.moveTo(16,10); c.lineTo(6,20); c.lineTo(16,30); c.moveTo(6,20); c.lineTo(34,20);
        } else if (symbol === "add") {
            c.moveTo(20,9); c.lineTo(20,31); c.moveTo(9,20); c.lineTo(31,20);
        } else if (symbol === "tune") {
            c.moveTo(10,6); c.lineTo(10,34); c.moveTo(20,6); c.lineTo(20,34); c.moveTo(30,6); c.lineTo(30,34); c.stroke();
            c.beginPath(); c.roundedRect(6,22,8,6,2,2); c.roundedRect(16,10,8,6,2,2); c.roundedRect(26,18,8,6,2,2);
            c.fillStyle = c.strokeStyle; c.fill();
        } else if (symbol === "apps") {
            c.roundedRect(7,7,11,11,3,3); c.roundedRect(22,7,11,11,3,3); c.roundedRect(7,22,11,11,3,3); c.roundedRect(22,22,11,11,3,3);
        }
        c.stroke();
    }

    // Transparent native HOME surface: keep the current card/video underneath.
    Item {
        id: panel
        anchors.fill: parent
        opacity: shell.foreground ? 1 : 0
        property real lift: shell.foreground ? 0 : shell.px(24)
        transform: Translate { y: panel.lift }
        Behavior on opacity { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
        Behavior on lift { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }

        // Shade only under the name and the rail, in the lower part of the
        // screen; the rest of the picture stays as it is. Under the settings
        // menu the whole screen is shaded.
        Rectangle {
            id: scrim
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: shell.page === "settings" ? parent.height : shell.page === "apps" ? shell.px(660) : shell.px(540)
            Behavior on height { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
            property color tint: shell.theme.scrim
            function a(v) { return Qt.rgba(tint.r, tint.g, tint.b, v); }
            gradient: Gradient {
                GradientStop { position: 0.00; color: scrim.a(shell.page === "settings" ? 0.55 : 0) }
                GradientStop { position: 0.22; color: scrim.a(shell.page === "settings" ? 0.65 : 0.30) }
                GradientStop { position: 0.45; color: scrim.a(shell.page === "settings" ? 0.75 : 0.66) }
                GradientStop { position: 0.68; color: scrim.a(0.86) }
                GradientStop { position: 1.00; color: scrim.a(0.93) }
            }
        }
        // The glow in the bottom-left corner, in the colour of what is
        // focused. A shader, so it covers only the part of the screen it
        // reaches: a full-screen one is the costliest thing a TV's GPU is
        // asked for here, and it is redrawn while the colour fades.
        RadialGradient {
            x: 0; y: parent.height - shell.px(455); width: shell.px(1400); height: shell.px(455)
            horizontalOffset: shell.px(192) - width/2; verticalOffset: shell.px(520) - height/2
            horizontalRadius: shell.px(1200); verticalRadius: shell.px(520)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(shell.glowColor.r, shell.glowColor.g, shell.glowColor.b, 0.34) }
                GradientStop { position: 0.72; color: Qt.rgba(shell.glowColor.r, shell.glowColor.g, shell.glowColor.b, 0) }
            }
        }

        // Status: what is underneath, then the clock, on a chip like the input
        // pills, so it reads over any picture without shading the screen.
        Rectangle {
            id: status
            visible: shell.settings.clock !== false
            anchors.right: parent.right; anchors.rightMargin: shell.margin; y: shell.px(32)
            width: statusRow.width + shell.px(48); height: Math.max(shell.px(56), statusRow.height + shell.px(22)); radius: shell.px(18)
            color: shell.surface; border.width: 1; border.color: shell.theme.surfaceEdge
            Row {
                id: statusRow
                anchors.centerIn: parent; spacing: shell.px(18)
                Row {
                    visible: nowTitle !== ""; spacing: shell.px(10); anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: shell.px(7); height: width; radius: width/2; color: shell.theme.focus; anchors.verticalCenter: parent.verticalCenter }
                    // A long app name is cut, not the chip pushed off the screen. Its
                    // width is measured by a hidden twin: an elided Text whose width
                    // hangs on its own implicitWidth keeps an old text's width on the
                    // TV, and a metrics object there misses a change of the text size.
                    Text { id: nowTwin; visible: false; text: nowTitle; font.family: shell.fontName; font.pixelSize: shell.pt(19) }
                    Text {
                        text: nowTitle; font.family: shell.fontName; font.pixelSize: shell.pt(19); color: shell.theme.text; anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(Math.ceil(nowTwin.implicitWidth) + 1, shell.px(480)); elide: Text.ElideRight
                    }
                }
                Rectangle { visible: nowTitle !== ""; width: 1; height: shell.pt(20); color: shell.theme.divider; anchors.verticalCenter: parent.verticalCenter }
                Text { text: clock; font.family: shell.fontName; font.bold: true; font.pixelSize: shell.pt(26); font.letterSpacing: -0.4*shell.u; color: shell.theme.heading; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // Hero: the focused name and one line of context under it.
        Item {
            id: heroGroup
            visible: shell.page !== "settings"
            x: shell.margin; y: shell.heroBaseline - shell.px(160)
            width: shell.width - 2*shell.margin; height: shell.px(220)
            Item { id: heroBase; y: shell.px(160); width: 1; height: 1 }
            Text {
                width: parent.width; anchors.baseline: heroBase.top
                visible: shell.showTitle
                text: shell.hero.title; elide: Text.ElideRight
                font.family: shell.fontName; font.bold: true; font.pixelSize: shell.pt(60); font.letterSpacing: -1.8*shell.u; color: shell.theme.heading; style: Text.Raised; styleColor: shell.theme.headingShadow
            }
            Text {
                y: shell.px(174); width: parent.width; elide: Text.ElideRight
                text: shell.hero.sub; font.family: shell.fontName; font.pixelSize: shell.pt(22)
                color: message ? shell.warning : notice ? shell.theme.heading : shell.theme.text
            }
        }

        // Controls for what is focused, on the bottom line with the version.
        Row {
            x: shell.margin; y: shell.height - shell.px(47); spacing: shell.px(24)
            Repeater {
                model: shell.hints
                Row {
                    spacing: shell.px(9)
                    Rectangle {
                        width: keyLabel.implicitWidth+shell.px(14); height: shell.pt(24); radius: shell.px(7); color: "transparent"; border.width: Math.max(1, 1.5*shell.u); border.color: shell.theme.keyEdge
                        Text { id: keyLabel; anchors.centerIn: parent; text: modelData[0]; font.family: shell.fontName; font.bold: true; font.pixelSize: shell.pt(12); color: shell.theme.keyLabel }
                    }
                    Text { text: modelData[1]; font.family: shell.fontName; font.pixelSize: shell.pt(15); color: shell.theme.hint; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        // Rounded app tile with the double focus ring.
        Component {
            id: appTile
            Item {
                id: cell
                property var entry
                property int navIndex: 0
                readonly property int size: shell.tile
                readonly property int corner: shell.px(30)
                property bool chosen: shell.selected === navIndex
                readonly property bool editing: shell.page === "home" && shell.editIndex === navIndex
                readonly property bool starred: shell.page === "apps" && entry !== undefined && shell.favouriteKeys.indexOf(entry.id) >= 0
                readonly property bool hidden: shell.page === "apps" && entry !== undefined && shell.hiddenIds.indexOf(entry.id) >= 0
                width: size; height: size
                z: chosen ? 2 : 0
                opacity: hidden ? 0.45 : 1
                scale: chosen ? (shell.pressing ? 1.03 : 1.1) : 1
                property real lift: chosen ? -6*shell.u : 0
                Behavior on lift { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
                transform: Translate { y: cell.lift }
                Behavior on scale { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
                Rectangle { visible: cell.chosen; anchors.centerIn: parent; width: cell.size+shell.px(14); height: width; radius: cell.corner+shell.px(7); color: cell.editing ? shell.warning : shell.theme.ring }
                Rectangle { visible: cell.chosen; anchors.centerIn: parent; width: cell.size+shell.px(8); height: width; radius: cell.corner+shell.px(4); color: shell.theme.gap }
                Rectangle { anchors.fill: parent; radius: cell.corner; color: shell.theme.tile }
                Text {
                    visible: icon.status !== Image.Ready
                    anchors.centerIn: parent; text: cell.entry && cell.entry.title ? cell.entry.title.charAt(0) : ""
                    font.family: shell.fontName; font.bold: true; font.pixelSize: shell.px(40); color: shell.ink2
                }
                Image {
                    id: icon; anchors.fill: parent; visible: false
                    source: cell.entry && cell.entry.icon ? cell.entry.icon : ""
                    fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                    // Decoded at twice the tile, for the focus zoom; no larger.
                    sourceSize.width: 2*shell.tile; sourceSize.height: 2*shell.tile
                }
                Rectangle { id: corners; anchors.fill: parent; radius: cell.corner; visible: false }
                OpacityMask { anchors.fill: parent; source: icon; maskSource: corners; visible: icon.status === Image.Ready }
                // Edit handles sit on the tile edges, inside the gap to the neighbours.
                Repeater {
                    model: cell.editing ? ["‹", "›"] : []
                    Rectangle {
                        x: index === 0 ? -shell.px(14) : cell.size-shell.px(14); anchors.verticalCenter: parent.verticalCenter
                        width: shell.px(28); height: shell.px(44); radius: shell.px(14); color: shell.theme.handle; border.width: Math.max(1, 2*shell.u); border.color: shell.warning
                        Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -2*shell.u; text: modelData; font.family: shell.fontName; font.bold: true; font.pixelSize: shell.px(30); color: shell.warning }
                    }
                }
                // Favourite marker in All applications.
                Rectangle {
                    visible: cell.starred; x: cell.size-shell.px(20); y: -shell.px(6); width: shell.px(26); height: width; radius: width/2
                    color: shell.theme.focus; border.width: shell.px(3); border.color: shell.theme.gap
                }
                // The pointer: a click focuses and opens; pointing alone does nothing.
                MouseArea {
                    anchors.fill: parent
                    onClicked: { shell.selected=cell.navIndex; shell.activate(shell.itemAt(cell.navIndex)); }
                }
            }
        }
        // Rounded line-icon tile: All applications, System and its tools.
        Component {
            id: glyphTile
            Item {
                id: glyphCell
                property var entry
                property int navIndex: 0
                // Size comes from the Loader so the Canvas paints once at the right scale.
                readonly property int size: parent && parent.glyphSize ? parent.glyphSize : shell.px(88)
                readonly property bool big: size > 100*shell.u
                readonly property bool mid: size > 70*shell.u
                readonly property int corner: big ? shell.px(30) : mid ? shell.px(24) : shell.px(18)
                property bool chosen: shell.selected === navIndex
                // A new version is there: a dot on the way to the updater.
                readonly property bool badge: shell.updateAvailable && entry !== undefined && entry !== null &&
                    (entry.action === "system" || entry.action === "launcherSettings")
                width: size; height: size
                z: chosen ? 2 : 0
                scale: chosen ? (shell.pressing ? 1.03 : 1.1) : 1
                property real lift: chosen ? -6*shell.u : 0
                Behavior on lift { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
                transform: Translate { y: glyphCell.lift }
                Behavior on scale { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
                Rectangle { visible: glyphCell.chosen; anchors.centerIn: parent; width: glyphCell.size+shell.px(14); height: width; radius: glyphCell.corner+shell.px(7); color: shell.theme.ring }
                Rectangle { visible: glyphCell.chosen; anchors.centerIn: parent; width: glyphCell.size+shell.px(8); height: width; radius: glyphCell.corner+shell.px(4); color: shell.theme.gap }
                Rectangle {
                    anchors.fill: parent; radius: glyphCell.corner
                    color: glyphCell.chosen ? shell.theme.focus : shell.chip
                    border.width: glyphCell.chosen ? 0 : 1; border.color: shell.chipEdge
                    Behavior on color { ColorAnimation { duration: shell.dur(180) } }
                }
                Canvas {
                    property int box: glyphCell.big ? shell.px(44) : glyphCell.mid ? shell.px(32) : shell.px(28)
                    anchors.centerIn: parent; width: box; height: box
                    property string symbol: glyphCell.entry && glyphCell.entry.symbol ? glyphCell.entry.symbol : ""
                    property string stroke: glyphCell.chosen ? shell.theme.onFocus : shell.ink
                    onSymbolChanged: requestPaint()
                    onStrokeChanged: requestPaint()
                    onBoxChanged: requestPaint()
                    onPaint: {
                        var c=getContext("2d"); c.reset(); c.scale(box/40, box/40);
                        c.strokeStyle = stroke; c.lineWidth = Math.max(1.5, 2.2*shell.u)*40/box; c.lineCap="round"; c.lineJoin="round";
                        shell.drawGlyph(c, symbol);
                    }
                }
                Rectangle {
                    visible: glyphCell.badge; x: glyphCell.size-shell.px(16); y: -shell.px(4)
                    width: shell.px(20); height: width; radius: width/2
                    color: shell.warning; border.width: shell.px(3); border.color: shell.theme.gap
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { shell.selected=glyphCell.navIndex; shell.activate(shell.itemAt(glyphCell.navIndex)); }
                }
            }
        }
        // A source pill on the Home rail: HDMI n with the device under it, or Live TV.
        Component {
            id: pillTile
            Rectangle {
                id: pill
                property var entry
                property int navIndex: 0
                property bool chosen: shell.selected === navIndex
                property real lift: chosen ? -4*shell.u : 0
                width: Math.max(pillLabel.implicitWidth, pillDevice.visible ? pillDevice.width : 0)+shell.px(44)
                height: Math.max(shell.px(64), pillText.height + shell.px(20)); radius: shell.px(18)
                color: chosen ? shell.theme.focus : shell.chip
                border.width: chosen ? 0 : 1; border.color: shell.chipEdge
                // Nothing plugged in: the pill stays solid, its text dimmed.
                // Hidden (shown by the setting): the whole pill dimmed.
                readonly property bool dim: !chosen && entry !== undefined && entry.present === false
                opacity: entry !== undefined && entry.hidden ? 0.45 : 1
                scale: chosen ? (shell.pressing ? 1.02 : 1.06) : 1
                transform: Translate { y: pill.lift }
                Behavior on lift { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: shell.dur(180) } }
                Column {
                    id: pillText
                    anchors.centerIn: parent; spacing: 1
                    Text {
                        id: pillLabel; anchors.horizontalCenter: parent.horizontalCenter; text: pill.entry ? pill.entry.title : ""
                        font.family: shell.fontName; font.bold: true; font.pixelSize: pillDevice.visible ? shell.pt(19) : shell.pt(21); font.letterSpacing: -0.2*shell.u
                        color: pill.chosen ? shell.theme.onFocus : pill.dim ? shell.theme.dim : shell.theme.label
                    }
                    Text { id: deviceTwin; visible: false; text: pill.entry && pill.entry.detail ? pill.entry.detail : ""; font.family: shell.fontName; font.pixelSize: shell.pt(13) }
                    Text {
                        id: pillDevice; visible: !!(pill.entry && pill.entry.detail); anchors.horizontalCenter: parent.horizontalCenter
                        text: pill.entry && pill.entry.detail ? pill.entry.detail : ""; width: Math.min(Math.ceil(deviceTwin.implicitWidth) + 1, shell.pillTextCap); elide: Text.ElideRight
                        font.family: shell.fontName; font.pixelSize: shell.pt(13)
                        color: pill.chosen ? shell.theme.onFocus2 : pill.dim ? shell.theme.dim2 : shell.ink3
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { shell.selected=pill.navIndex; shell.activate(shell.itemAt(pill.navIndex)); }
                }
            }
        }

        // Home rail: favourites, sources, then the two doors.
        Row {
            id: rail
            visible: page === "home"
            x: shell.margin; y: shell.railY; height: shell.tile; spacing: shell.railGroupGap
            // Should the rail still be wider than the screen allows (a set
            // with many inputs), it is drawn a little smaller rather than cut.
            transformOrigin: Item.Left
            scale: Math.min(1, (shell.width - 2*shell.margin) / Math.max(1, width))
            Row {
                spacing: shell.gap; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: favourites
                    Loader {
                        sourceComponent: appTile; z: item && item.chosen ? 2 : 0
                        onLoaded: { item.entry=modelData; item.navIndex=index; }
                    }
                }
                Loader {
                    active: shell.showAddTile
                    visible: active
                    property int glyphSize: shell.tile
                    sourceComponent: glyphTile
                    onLoaded: { item.entry = Qt.binding(function() { return shell.addFavouritesTile; }); item.navIndex = 0; }
                }
            }
            Row {
                spacing: shell.px(12); anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: sources
                    Loader {
                        sourceComponent: pillTile; z: item && item.chosen ? 2 : 0
                        onLoaded: { item.entry=modelData; item.navIndex=Qt.binding(function() { return shell.favSlots+index; }); }
                    }
                }
            }
            Row {
                spacing: shell.px(12); anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: 2
                    Loader {
                        property int glyphSize: shell.px(64)
                        sourceComponent: glyphTile
                        onLoaded: {
                            item.entry = Qt.binding(function() { return index === 0 ? {title: shell.t("apps_title"), action: "apps", symbol: "apps"} : {title: shell.t("system_title"), action: "system", symbol: "settings"}; });
                            item.navIndex = Qt.binding(function() { return shell.favSlots+shell.sourceCount+index; });
                        }
                    }
                }
            }
        }

        // All applications: as many columns as the width takes, two rows visible.
        Flickable {
            id: appGrid
            visible: page === "apps"
            // Two rows and the focus ring's room under them, short of the next
            // row's favourite markers.
            x: shell.margin-shell.px(20); y: shell.height-shell.px(360); width: shell.appColumns*(shell.tile+shell.gap)-shell.gap+shell.px(40); height: 2*shell.tile+shell.gap+shell.px(40)
            clip: true; interactive: false
            readonly property int step: shell.tile+shell.gap
            readonly property int firstRow: Math.round(contentY/step)
            contentWidth: width; contentHeight: Math.max(height, Math.ceil(apps.length/shell.appColumns)*step+shell.px(48)-shell.gap)
            Behavior on contentY { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
            Repeater {
                model: apps
                Loader {
                    readonly property int row: Math.floor(index/shell.appColumns)
                    x: shell.px(20)+(index%shell.appColumns)*appGrid.step; y: shell.px(24)+row*appGrid.step
                    z: item && item.chosen ? 2 : 0
                    // Only the rows on screen and the next one are built; a long
                    // list is not a long wait, nor a hundred icons in memory.
                    active: row >= appGrid.firstRow-1 && row <= appGrid.firstRow+2
                    sourceComponent: appTile
                    onLoaded: { item.entry=modelData; item.navIndex=index; }
                }
            }
            Connections {
                target: shell
                onSelectedChanged: {
                    if (shell.page !== "apps") return;
                    var row=Math.floor(shell.selected/shell.appColumns), first=Math.round(appGrid.contentY/appGrid.step);
                    if (row < first) appGrid.contentY=row*appGrid.step;
                    else if (row > first+1) appGrid.contentY=(row-1)*appGrid.step;
                }
                onPageChanged: appGrid.contentY=0
            }
        }
        Rectangle {
            visible: page === "apps" && appGrid.contentHeight > appGrid.height
            x: shell.width-shell.margin+shell.px(20); y: shell.height-shell.px(336); width: shell.px(4); height: 2*shell.tile+shell.gap; radius: width/2; color: shell.theme.track
            Rectangle {
                width: parent.width; radius: width/2; color: shell.theme.focus
                height: parent.height*appGrid.height/appGrid.contentHeight
                y: (parent.height-height)*appGrid.contentY/Math.max(1, appGrid.contentHeight-appGrid.height)
            }
        }

        // System: the same rail, glyph tiles at full size.
        Row {
            visible: page === "system"
            x: shell.margin; y: shell.railY; spacing: shell.gap
            Repeater {
                model: shell.tools
                Loader {
                    property int glyphSize: shell.tile
                    sourceComponent: glyphTile; z: item && item.chosen ? 2 : 0
                    onLoaded: { item.entry=modelData; item.navIndex=index; }
                }
            }
        }

        // The version, the TV's webOS and the variant, bottom right.
        Text {
            visible: page === "system"
            anchors.right: parent.right; anchors.rightMargin: shell.margin; y: shell.height-shell.px(43)
            text: "Homebar " + Config.version + (Config.webos ? " · webOS " + Config.webos : "") + (Config.platform ? " · " + Config.platform : "")
            font.family: shell.fontName; font.pixelSize: shell.pt(14); color: shell.theme.version
        }

        // Launcher settings: a menu over most of the screen, in the panel's
        // own colours. On the left the settings in groups, each with its
        // value; on the right the values of the focused one, a dot on the
        // chosen value, or what an action has to say. Up and down move, OK
        // or right goes into the values, where up and down choose (each
        // applies at once: the menu itself is the preview) and OK or left
        // come back; BACK closes the menu.
        Rectangle {
            id: menu
            visible: opacity > 0
            opacity: shell.page === "settings" ? 1 : 0
            property real lift: shell.page === "settings" ? 0 : shell.px(16)
            transform: Translate { y: menu.lift }
            Behavior on opacity { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
            Behavior on lift { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
            x: shell.margin; y: shell.px(110)
            width: shell.width - 2*shell.margin; height: shell.height - shell.px(110) - shell.px(96)
            radius: shell.px(30); color: shell.chip; border.width: 1; border.color: shell.chipEdge
            readonly property int pad: shell.px(40)
            readonly property int rowHeight: shell.pt(56)
            readonly property int headerHeight: shell.pt(44)
            // Under the title, whatever the text size.
            readonly property int listTop: shell.px(30) + Math.round(shell.pt(34)*1.3) + shell.px(26)
            readonly property int listWidth: shell.px(720)

            Text {
                x: menu.pad; y: shell.px(30)
                text: shell.t("launcher_settings"); font.family: shell.fontName; font.bold: true; font.pixelSize: shell.pt(34); font.letterSpacing: -0.8*shell.u; color: shell.ink
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: menu.pad; y: shell.px(30) + Math.round(shell.pt(34)*1.3) - shell.pt(14) - shell.px(6)
                text: "Homebar " + Config.version + (Config.webos ? " · webOS " + Config.webos : "") + (Config.platform ? " · " + Config.platform : "")
                font.family: shell.fontName; font.pixelSize: shell.pt(14); color: shell.ink3
            }
            Rectangle { x: menu.pad; y: menu.listTop - shell.px(14); width: parent.width - 2*menu.pad; height: 1; color: shell.chipEdge }

            // Where a row starts in the list, from the rows' heights (the
            // column places them only a frame later).
            function rowY(index) {
                var y = 0;
                for (var i=0; i<shell.menuRows.length; i++) {
                    var r = shell.menuRows[i];
                    if (r.index === index) return y;
                    y += r.header !== undefined ? menu.headerHeight + (i > 0 ? shell.px(12) : 0) : menu.rowHeight;
                }
                return y;
            }
            // The settings, in groups, scrolling so the focused one stays in view.
            Flickable {
                id: menuList
                x: menu.pad; y: menu.listTop; width: menu.listWidth; height: menu.height - menu.listTop - menu.pad
                clip: true; interactive: false
                // Room under the last row for the fade at the bottom edge.
                readonly property int fade: shell.px(18)
                contentWidth: width; contentHeight: Math.max(height, menuColumn.height + fade)
                Behavior on contentY { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
                // The focused row in view, and clear of the fades at the edges.
                function follow() {
                    if (shell.page !== "settings") return;
                    var top = menu.rowY(shell.selected), bottom = top + menu.rowHeight, at = contentY;
                    if (bottom + fade > at + height) at = bottom + fade - height;
                    else if (top < at + menu.headerHeight) at = Math.max(0, top - menu.headerHeight - shell.px(12));
                    contentY = Math.max(0, Math.min(at, contentHeight - height));
                }
                Column {
                    id: menuColumn
                    width: parent.width
                    Repeater {
                        model: shell.menuRows
                        Item {
                            readonly property bool isHeader: modelData.header !== undefined
                            readonly property var setting: isHeader ? null : shell.settingsItems[modelData.index]
                            readonly property bool chosen: !isHeader && shell.selected === modelData.index
                            width: menuColumn.width; height: isHeader ? menu.headerHeight + (index > 0 ? shell.px(12) : 0) : menu.rowHeight
                            // A group's name.
                            Text {
                                visible: isHeader; x: shell.px(20); anchors.bottom: parent.bottom; anchors.bottomMargin: shell.px(10)
                                text: isHeader ? modelData.header : ""; font.family: shell.fontName; font.bold: true; font.pixelSize: shell.pt(13); font.letterSpacing: 1.2*shell.u; font.capitalization: Font.AllUppercase
                                color: shell.ink3
                            }
                            // A setting: its name, its value at the right.
                            Rectangle {
                                visible: !isHeader
                                anchors.fill: parent; anchors.topMargin: shell.px(3); anchors.bottomMargin: shell.px(3)
                                radius: shell.px(14)
                                color: chosen ? (shell.pane === 0 ? shell.theme.focus : shell.theme.tile) : "transparent"
                                border.width: chosen && shell.pane === 1 ? 1 : 0; border.color: shell.theme.focus
                                Behavior on color { ColorAnimation { duration: shell.dur(120) } }
                                // Both texts are measured by hidden twins (no elide, no width:
                                // their implicitWidth is the text's own, at the text size of
                                // the moment) and cut to what the row has: the value to half
                                // of it, the name to the rest.
                                Text { id: nameTwin; visible: false; text: setting ? setting.title : ""; font.family: shell.fontName; font.pixelSize: shell.pt(22) }
                                Text { id: valueTwin; visible: false; text: setting ? setting.value : ""; font.family: shell.fontName; font.pixelSize: shell.pt(19) }
                                Text {
                                    id: rowValue
                                    anchors.right: parent.right; anchors.rightMargin: shell.px(20); anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(Math.ceil(valueTwin.implicitWidth) + 1, parent.width*0.5); elide: Text.ElideRight; horizontalAlignment: Text.AlignRight
                                    text: setting ? setting.value : ""; font.family: shell.fontName; font.pixelSize: shell.pt(19)
                                    color: chosen && shell.pane === 0 ? shell.theme.onFocus2 : shell.ink3
                                }
                                Text {
                                    id: rowName
                                    x: shell.px(20); anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(Math.ceil(nameTwin.implicitWidth) + 1, parent.width - rowValue.width - shell.px(60))
                                    elide: Text.ElideRight
                                    text: setting ? setting.title : ""; font.family: shell.fontName; font.pixelSize: shell.pt(22)
                                    color: chosen && shell.pane === 0 ? shell.theme.onFocus : shell.ink
                                }
                                // The pointer: a click focuses the row and opens its values
                                // (or does what an action does); pointing alone does nothing.
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { shell.pane = 0; shell.selected = modelData.index; shell.activate(shell.itemAt(modelData.index)); }
                                }
                            }
                        }
                    }
                }
                Connections {
                    target: shell
                    onSelectedChanged: menuList.follow()
                    onPageChanged: { menuList.contentY = 0; menuList.follow(); }
                }
            }
            // The list's edges fade into the card, so a row cut by the edge
            // does not look cut.
            Rectangle {
                x: menuList.x; y: menuList.y; width: menuList.width; height: shell.px(18)
                gradient: Gradient { GradientStop { position: 0; color: shell.chip } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) } }
            }
            Rectangle {
                x: menuList.x; y: menuList.y + menuList.height - shell.px(18); width: menuList.width; height: shell.px(18)
                gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) } GradientStop { position: 1; color: shell.chip } }
            }
            Rectangle { x: menu.pad + menu.listWidth + shell.px(40); y: menu.listTop; width: 1; height: menuList.height; color: shell.chipEdge }

            // The focused setting: its values, or an action's status.
            Item {
                id: valuesPane
                x: menu.pad + menu.listWidth + shell.px(80); y: menu.listTop
                width: menu.width - x - menu.pad; height: menuList.height
                clip: true
                readonly property var setting: shell.page === "settings" && shell.selected < shell.settingsItems.length ? shell.settingsItems[shell.selected] : null
                readonly property bool actionRow: setting !== null && setting.action !== "setting"
                Text {
                    id: valuesTitle
                    x: shell.px(20); y: shell.px(6); width: parent.width - shell.px(40); elide: Text.ElideRight
                    text: valuesPane.setting ? valuesPane.setting.title : ""
                    font.family: shell.fontName; font.bold: true; font.pixelSize: shell.pt(28); font.letterSpacing: -0.6*shell.u; color: shell.ink
                }
                // An action's status, and what OK does with it.
                Column {
                    visible: valuesPane.actionRow
                    x: shell.px(20); y: valuesTitle.y + valuesTitle.height + shell.px(18); width: parent.width - shell.px(40); spacing: shell.px(16)
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: valuesPane.setting ? valuesPane.setting.value : ""
                        font.family: shell.fontName; font.pixelSize: shell.pt(21); color: shell.ink2
                    }
                    Row {
                        spacing: shell.px(9); visible: valuesPane.setting !== null && shell.actionVerb(valuesPane.setting.key) !== ""
                        Rectangle {
                            width: okLabel.implicitWidth+shell.px(14); height: shell.pt(24); radius: shell.px(7); color: "transparent"; border.width: Math.max(1, 1.5*shell.u); border.color: shell.ink3
                            anchors.verticalCenter: parent.verticalCenter
                            Text { id: okLabel; anchors.centerIn: parent; text: "OK"; font.family: shell.fontName; font.bold: true; font.pixelSize: shell.pt(12); color: shell.ink2 }
                        }
                        Text { text: valuesPane.setting ? shell.actionVerb(valuesPane.setting.key) : ""; font.family: shell.fontName; font.pixelSize: shell.pt(17); color: shell.ink2; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                // The values: a dot on the chosen one; the focused one lit
                // while the values have the focus.
                Flickable {
                    id: valueList
                    visible: !valuesPane.actionRow
                    x: 0; y: valuesTitle.y + valuesTitle.height + shell.px(14); width: parent.width; height: parent.height - y
                    clip: true; interactive: false
                    contentWidth: width; contentHeight: Math.max(height, valueColumn.height)
                    Behavior on contentY { NumberAnimation { duration: shell.dur(180); easing.type: Easing.OutCubic } }
                    function follow() {
                        var top = shell.valueIndex*menu.rowHeight, bottom = top + menu.rowHeight, at = contentY;
                        if (bottom > at + height) at = bottom - height;
                        else if (top < at) at = top;
                        contentY = Math.max(0, Math.min(at, Math.max(height, valueColumn.height) - height));
                    }
                    Column {
                        id: valueColumn
                        width: parent.width
                        Repeater {
                            model: shell.valueOptions
                            Rectangle {
                                readonly property bool current: shell.settings[shell.valueKey] === modelData.id
                                readonly property bool lit: shell.pane === 1 && shell.valueIndex === index
                                width: valueColumn.width; height: menu.rowHeight; radius: shell.px(14)
                                color: lit ? shell.theme.focus : "transparent"
                                Behavior on color { ColorAnimation { duration: shell.dur(120) } }
                                Rectangle {
                                    x: shell.px(20); anchors.verticalCenter: parent.verticalCenter
                                    width: shell.px(22); height: width; radius: width/2; color: "transparent"
                                    border.width: Math.max(1, 2*shell.u); border.color: lit ? shell.theme.onFocus : current ? shell.theme.focus : shell.ink3
                                    Rectangle { anchors.centerIn: parent; width: shell.px(10); height: width; radius: width/2; visible: current; color: lit ? shell.theme.onFocus : shell.theme.focus }
                                }
                                Text {
                                    x: shell.px(58); anchors.verticalCenter: parent.verticalCenter; width: parent.width - shell.px(78); elide: Text.ElideRight
                                    text: modelData.title; font.family: shell.fontName; font.pixelSize: shell.pt(22)
                                    color: lit ? shell.theme.onFocus : shell.ink
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { shell.pane = 1; shell.valueIndex = index; shell.applyValue(); }
                                }
                            }
                        }
                    }
                    Connections {
                        target: shell
                        onValueIndexChanged: valueList.follow()
                        onSelectedChanged: valueList.contentY = 0
                    }
                }
            }
        }
    } // panel
}
