#!/usr/bin/env bash
# Puts LG's own screens back and removes everything install.sh put on the TV.
#
#   ./uninstall.sh                    find the TV on the network
#   ./uninstall.sh --tv 192.168.1.50  skip the TV search
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

TV=""
while [ $# -gt 0 ]; do
    case "$1" in
        --tv)
            TV=${2:-}
            [ -n "$TV" ] || die "--tv needs the TV's address, like --tv 192.168.1.50"
            shift
            ;;
        -h | --help)
            sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) die "Unknown option $1. See ./uninstall.sh --help" ;;
    esac
    shift
done

ASKED_TV=$TV
find_tv
if [ -z "$ASKED_TV" ]; then
    ask "Remove the photo screensaver from this TV?" Y || exit 0
fi

step "Removing..."
result=$(tv_run "D=$TV_DIR; if [ ! -d \$D ] && [ ! -f $TV_HOOK ]; then echo WPS_NONE; else if [ -x \$D/apply.sh ]; then \$D/apply.sh revert; fi; rm -f $TV_HOOK; rm -rf \$D \$D.new \$D.old; rm -f /tmp/photo-screensaver-shuffle.*; fi; echo WPS_OK")

if printf '%s\n' "$result" | grep -qx WPS_NONE; then
    ok "Nothing to remove: the photo screensaver isn't on this TV."
elif printf '%s\n' "$result" | grep -qx WPS_OK; then
    ok "Removed. The TV shows LG's own screensaver and no-signal art again."
else
    die "Couldn't finish removing it. Check that the TV is on and run ./uninstall.sh again."
fi
