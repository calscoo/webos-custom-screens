#!/bin/sh
# Runs on the TV. Shows the photos in photos/ on LG's two idle screens:
#   - the screensaver after idle on the home screen or in an app
#   - the art on the "no signal" screen of HDMI inputs
# Nothing in LG's files changes. Both screens are bind mounts, which "revert" removes.
# Homebrew Channel runs this at every boot through /var/lib/webosbrew/init.d/50-webos-custom-screens.
#
#   apply.sh          turn the photos on, or refresh them
#   apply.sh revert   put LG's screens back

BASE=/media/developer/webos-custom-screens
SAVER=/usr/palm/applications/com.webos.app.screensaver/qml/main.qml
ART=/mnt/lg/appstore/preload/igallery/files/data/modernart
SLOTS=$BASE/nosignal
PIDFILE=/tmp/webos-custom-screens-shuffle.pid

# Removes this tool's mounts from $1, leaving anything another mod mounted there. During an
# update the install folder is briefly named webos-custom-screens.old, so that name is ours too.
unmount_ours() {
    while findmnt -n -o SOURCE "$1" 2>/dev/null | tail -n 1 | grep -qE "/webos-custom-screens(\.[a-z]+)?/"; do
        umount "$1" || return 1
    done
}

if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
fi
if ! unmount_ours "$SAVER" || ! unmount_ours "$ART"; then
    echo "[-] Could not remove this tool's mounts" >&2
    exit 1
fi

if [ "$1" = revert ]; then
    echo "[+] LG's screens are back"
    exit 0
fi

set -- "$BASE"/photos/*.jpg
if [ ! -f "$1" ]; then
    echo "[-] No photos in $BASE/photos" >&2
    exit 1
fi
count=$#
saver=off

# Home and app screensaver
if [ ! -f "$SAVER" ]; then
    echo "[~] Skipped the home and app screensaver: this TV has no $SAVER"
elif findmnt "$SAVER" >/dev/null 2>&1; then
    echo "[~] Skipped the home and app screensaver: another screensaver mod is active"
elif mount --bind "$BASE/main.qml" "$SAVER"; then
    echo "[+] Home and app screensaver: on"
    saver=on
fi

# No-signal art. LG's input app reads the fixed names modernart_0.jpg to modernart_15.jpg
# from $ART and shows a random one every 10 seconds. Exits with an error when neither
# screen could be turned on.
if [ ! -d "$ART" ]; then
    echo "[~] Skipped the no-signal art: this TV has no $ART"
    [ "$saver" = on ]
    exit
fi
if findmnt "$ART" >/dev/null 2>&1; then
    echo "[~] Skipped the no-signal art: another mod replaces it"
    [ "$saver" = on ]
    exit
fi
rm -rf "$SLOTS"
mkdir -p "$SLOTS"
i=0
if [ -f "$BASE/shuffle.py" ] && [ "$count" -gt 1 ]; then
    # All 16 names start on one photo. shuffle.py then moves them through the photos.
    while [ $i -lt 16 ]; do
        ln -f "$1" "$SLOTS/modernart_$i.jpg"
        i=$((i + 1))
    done
    shuffle=yes
else
    # Without the shuffle helper, the 16 names hold up to 16 photos, repeated to fill them
    while [ $i -lt 16 ]; do
        for f in "$BASE"/photos/*.jpg; do
            [ $i -lt 16 ] || break
            ln -f "$f" "$SLOTS/modernart_$i.jpg"
            i=$((i + 1))
        done
    done
    shuffle=no
fi
chmod -R a+rX "$SLOTS"
mount --bind "$SLOTS" "$ART" || exit 1

if [ "$shuffle" = yes ]; then
    nohup /usr/bin/python3 "$BASE/shuffle.py" >/tmp/webos-custom-screens-shuffle.log 2>&1 &
    echo "[+] No-signal art: on, $count photos in a shuffled order"
elif [ "$count" -gt 16 ]; then
    echo "[+] No-signal art: on, first 16 of $count photos in random order"
else
    echo "[+] No-signal art: on, $count photos in random order"
fi
