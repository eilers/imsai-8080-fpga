#!/bin/sh
set -eu

export DISPLAY="${DISPLAY:-:1}"
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

seed_disks() {
  library="/opt/z80pack/imsaisim/disks/library"
  if [ ! -d "$library" ] || [ -z "$(ls -A "$library" 2>/dev/null)" ]; then
    mkdir -p /opt/z80pack/imsaisim/disks
    cp -a /opt/z80pack/disk-library/. /opt/z80pack/imsaisim/disks/
  fi
  # A volume created by an earlier image still needs disks added later.
  mkdir -p "$library"
  cp -an /opt/z80pack/disk-library/library/. "$library/"
  # The library window lists only files that sit directly in disks/.
  for image in "$library"/*; do
    [ -f "$image" ] || continue
    name=$(basename "$image")
    link="/opt/z80pack/imsaisim/disks/$name"
    if [ ! -e "$link" ]; then
      ln -s "library/$name" "$link"
    fi
  done
}

seed_disks

# A restarted container keeps the previous display lock even though that
# process is gone. Remove a stale lock so the front panel can start.
lock="/tmp/.X${DISPLAY#:}-lock"
if [ -f "$lock" ]; then
  oldpid=$(tr -d '[:space:]' < "$lock")
  if ! kill -0 "$oldpid" 2>/dev/null; then
    rm -f "$lock" "/tmp/.X11-unix/X${DISPLAY#:}"
  fi
fi

# The front panel window is 800 by 324. Match the display so the panel fills the browser.
Xvfb "$DISPLAY" -screen 0 800x324x24 -ac +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &
xvfb_pid=$!

ready=0
i=0
while [ "$i" -lt 50 ]; do
  if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    ready=1
    break
  fi
  if ! kill -0 "$xvfb_pid" 2>/dev/null; then
    break
  fi
  i=$((i + 1))
  sleep 0.1
done

if [ "$ready" -ne 1 ]; then
  echo "The virtual display for the IMSAI front panel did not start." >&2
  cat /tmp/xvfb.log >&2 || true
  exit 1
fi

x11vnc -display "$DISPLAY" -forever -shared -nopw -listen 0.0.0.0 -rfbport 5900 -noxdamage >/tmp/x11vnc.log 2>&1 &
websockify --web=/usr/share/novnc 6080 localhost:5900 >/tmp/websockify.log 2>&1 &

cd /opt/z80pack/imsaisim

boot="${IMSAI_BOOT:-imsai-cpm13}"
case "$boot" in
  shelf|imsai-cpm13|cpm22|cpm3|imdos|imdos202|imdos205r0|um-cpm13|ucsd|boot|bootvio)
    ;;
  *)
    echo "Unknown IMSAI_BOOT=$boot" >&2
    exit 1
    ;;
esac

"./$boot" -n &
sim_pid=$!

trap 'kill "$sim_pid" 2>/dev/null || true; wait "$sim_pid" 2>/dev/null || true; exit 0' TERM INT

i=0
while [ "$i" -lt 50 ]; do
  if xdotool search --name FrontPanel windowmove --sync 0 0 >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 0.1
done

wait "$sim_pid"
