#!/bin/sh
# Homebrew init.d hook (overlay): put the black stand-in in LG Home's place
# (rawin-launcher-home/takeover.sh) and start the rawin-launcher helper, so the
# panel has its HTTP bridge on 127.0.0.1:8899 before the first HOME. Any Luna
# call starts the service; it then stays resident. Then the panel itself is
# started hidden ({"preload": true}), so the first HOME after a boot only has
# to show it instead of starting qml-runner. Runs in the background and
# retries while the Luna hub and services come up.
#
# The Homebrew Channel runs these hooks some 40 s into a boot, and the HOME
# button reaches the launcher only once Input Hook's own hook (inputhook,
# after this one) has started: a HOME before that opens LG's Home once.
# Each step is noted in /tmp/rawin-launcher-boot.log with the seconds since
# boot (diagnose.sh shows it; on webOS 10 logger lines do not reach
# /var/log/messages).
LOG=/tmp/rawin-launcher-boot.log
log() { logger -t rawin-launcher "$1"; echo "$(cut -d' ' -f1 /proc/uptime)s $1" >>"$LOG"; }
launch() { luna-send -n 1 luna://com.webos.applicationManager/launch "$1" 2>/dev/null | grep -q '"returnValue": *true'; }
log 'boot hook started'
(
  /bin/sh /var/lib/webosbrew/rawin-launcher-home/takeover.sh apply
) >/dev/null 2>&1 &
(
  n=0
  while [ $n -lt 40 ]; do
    if luna-send -n 1 luna://org.rawin.launcher.service/ping '{}' 2>/dev/null | grep -q '"http"'; then
      log 'helper started'
      # Without the app manager's loading spinner and splash, where the
      # launch call takes those flags; else the plain launch (the app then
      # maps its window for a moment, which takes the spinner down).
      if launch '{"id":"org.rawin.launcher","params":{"preload":true},"noSplash":true,"spinner":false}'; then
        log 'panel preloaded'
      elif launch '{"id":"org.rawin.launcher","params":{"preload":true}}'; then
        log 'panel preloaded (plain launch)'
      else
        log 'panel not preloaded (the launch failed); the first HOME starts it'
      fi
      exit 0
    fi
    n=$((n + 1))
    sleep 3
  done
  log 'helper did not start'
) >/dev/null 2>&1 &
