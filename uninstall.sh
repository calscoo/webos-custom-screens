#!/usr/bin/env bash
# Puts LG's own screens back and removes everything install.sh put on the TV. See --help
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

usage() {
    cat <<EOF
${BOLD}Usage:${RESET} ./uninstall.sh [options]

Puts LG's own screensaver, no-signal art, and power-off logo back, and removes
everything ./install.sh put on the TV. It asks before it changes anything.

${BOLD}Options${RESET}
  ${BOLD}--tv${RESET} ADDRESS            Use the TV at this address and skip the search.
  ${BOLD}--non-interactive${RESET}       Answer yes to every question. Needs --tv when the
                          search finds more than one TV.
  ${BOLD}-h, --help${RESET}              Show this help.
EOF
}

TV=""
while [ $# -gt 0 ]; do
    case "$1" in
        --tv)
            TV=${2:-}
            [ -n "$TV" ] && [ "${TV#-}" = "$TV" ] || die "--tv needs the TV's address, like --tv 192.168.1.50"
            shift
            ;;
        --tv=*) TV=${1#*=} ;;
        --non-interactive) NONINTERACTIVE=yes ;;
        -h | --help)
            usage
            exit 0
            ;;
        *) die "Unknown option $1. See ./uninstall.sh --help" ;;
    esac
    shift
done

STEP_TOTAL=2
printf '%swebOS Custom Screens%s\n' "$BOLD" "$RESET"

step "Finding your TV"
find_tv
ask "Put LG's screens back on this TV?" Y || { info "Stopped. Nothing changed."; exit 0; }

step "Removing"
result=$(tv_run "D=$TV_DIR; if [ ! -d \$D ] && [ ! -f $TV_HOOK ]; then echo WCS_NONE; else if [ -x \$D/apply.sh ]; then \$D/apply.sh revert; fi; rm -f $TV_HOOK; rm -rf \$D \$D.new \$D.old; rm -f /tmp/webos-custom-screens-shuffle.*; fi; echo WCS_OK")

if printf '%s\n' "$result" | grep -qx WCS_NONE; then
    ok "Nothing to remove: webos-custom-screens isn't on this TV."
elif printf '%s\n' "$result" | grep -qx WCS_OK; then
    ok "Removed. The TV shows LG's own screensaver, no-signal art, and power-off logo again."
else
    die "Couldn't finish removing it. Check that the TV is on and run ./uninstall.sh again."
fi
