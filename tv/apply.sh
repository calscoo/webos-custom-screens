#!/bin/sh
# Runs on the TV. Puts this tool's pictures on three of LG's screens:
#   - the screensaver after idle on the home screen or in an app (when photos/ has photos)
#   - the art on the "no signal" screen of HDMI inputs (same photos)
#   - the logo shown when the TV turns off (when logo/ has one)
# Nothing in LG's files changes. Each screen is a bind mount, which "revert" removes.
# Homebrew Channel runs this at every boot through /var/lib/webosbrew/init.d/50-webos-custom-screens.
#
#   apply.sh          turn the pictures on, or refresh them
#   apply.sh revert   put LG's screens back

BASE=/media/developer/webos-custom-screens
SAVER=/usr/palm/applications/com.webos.app.screensaver/qml/main.qml
ART=/mnt/lg/appstore/preload/igallery/files/data/modernart
LOGO=/usr/lib/qml/MasterBrand/LG_logo.png
LOGO_4K=/usr/lib/qml/MasterBrand/LG_logo_4k.png
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
for target in "$SAVER" "$ART" "$LOGO" "$LOGO_4K"; do
    if ! unmount_ours "$target"; then
        echo "[-] Could not remove this tool's mounts" >&2
        exit 1
    fi
done

if [ "$1" = revert ]; then
    echo "[+] LG's screens are back"
    exit 0
fi

set -- "$BASE"/photos/*.jpg
count=0
[ -f "$1" ] && count=$#
if [ "$count" -eq 0 ] && [ ! -f "$BASE/logo/LG_logo.png" ]; then
    echo "[-] Nothing to show: no photos or logo in $BASE" >&2
    exit 1
fi
screens_on=0

# Home and app screensaver
if [ "$count" -eq 0 ]; then
    : # no photos installed, so LG's screensaver stays
elif [ ! -f "$SAVER" ]; then
    echo "[~] Skipped the home and app screensaver: this TV has no $SAVER"
elif findmnt "$SAVER" >/dev/null 2>&1; then
    echo "[~] Skipped the home and app screensaver: another screensaver mod is active"
elif mount --bind "$BASE/main.qml" "$SAVER"; then
    echo "[+] Home and app screensaver: on"
    screens_on=$((screens_on + 1))
fi

# No-signal art. LG's input app reads the fixed names modernart_0.jpg to modernart_15.jpg
# from $ART and shows a random one every 10 seconds.
if [ "$count" -eq 0 ]; then
    : # no photos installed, so LG's art stays
elif [ ! -d "$ART" ]; then
    echo "[~] Skipped the no-signal art: this TV has no $ART"
elif findmnt "$ART" >/dev/null 2>&1; then
    echo "[~] Skipped the no-signal art: another mod replaces it"
else
    rm -rf "$SLOTS"
    mkdir -p "$SLOTS"
    i=0
    if [ -f "$BASE/shuffle.py" ] && [ ! -f "$BASE/no-shuffle" ] && [ "$count" -gt 1 ]; then
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
    if mount --bind "$SLOTS" "$ART"; then
        screens_on=$((screens_on + 1))
        if [ "$shuffle" = yes ]; then
            nohup /usr/bin/python3 "$BASE/shuffle.py" >/tmp/webos-custom-screens-shuffle.log 2>&1 &
            echo "[+] No-signal art: on, $count photos in a shuffled order"
        elif [ "$count" -gt 16 ]; then
            echo "[+] No-signal art: on, first 16 of $count photos in random order"
        else
            echo "[+] No-signal art: on, $count photos in random order"
        fi
    fi
fi

# Power-off logo. LG's system UI shows LG_logo.png centered on black when the TV turns off,
# and LG_logo_4k.png on TVs with 4K menus.
if [ -f "$BASE/logo/LG_logo.png" ]; then
    if [ ! -f "$LOGO" ]; then
        echo "[~] Skipped the power-off logo: this TV has no $LOGO"
    elif findmnt "$LOGO" >/dev/null 2>&1; then
        echo "[~] Skipped the power-off logo: another mod replaces it"
    elif mount --bind "$BASE/logo/LG_logo.png" "$LOGO"; then
        if [ -f "$LOGO_4K" ] && ! findmnt "$LOGO_4K" >/dev/null 2>&1; then
            mount --bind "$BASE/logo/LG_logo_4k.png" "$LOGO_4K"
        fi
        echo "[+] Power-off logo: on"
        screens_on=$((screens_on + 1))
    fi
fi

# Fails when no screen could be turned on
[ "$screens_on" -gt 0 ]
