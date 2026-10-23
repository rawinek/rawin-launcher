#!/bin/sh
# Homebrew init.d hook (overlay): put the black stand-in in LG Home's place
# (rawin-launcher-home/takeover.sh) and start the rawin-launcher helper, so the
# panel has its HTTP bridge on 127.0.0.1:8899 before the first HOME. Any Luna
# call starts the service; it then stays resident. Then the panel itself is
# started hidden ({"preload": true}), so the first HOME after a boot only has
# to show it instead of starting qml-runner. Runs in the background and
# retries while the Luna hub and services come up.
(
  /bin/sh /var/lib/webosbrew/rawin-launcher-home/takeover.sh apply
) >/dev/null 2>&1 &
(
  n=0
  while [ $n -lt 40 ]; do
    if luna-send -n 1 luna://org.rawin.launcher.service/ping '{}' 2>/dev/null | grep -q '"http"'; then
      logger -t rawin-launcher 'helper started'
      sleep 5
      luna-send -n 1 luna://com.webos.applicationManager/launch '{"id":"org.rawin.launcher","params":{"preload":true}}' >/dev/null 2>&1 &&
        logger -t rawin-launcher 'panel preloaded'
      exit 0
    fi
    n=$((n + 1))
    sleep 3
  done
  logger -t rawin-launcher 'helper did not start'
) >/dev/null 2>&1 &
