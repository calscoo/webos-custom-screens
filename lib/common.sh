# shellcheck shell=bash
# Shared helpers for install.sh and uninstall.sh.
# Written for the bash 3.2 that ships with macOS, and for Linux.

# Used by install.sh and uninstall.sh
# shellcheck disable=SC2034
TV_DIR=/media/developer/webos-custom-screens
# shellcheck disable=SC2034
TV_HOOK=/var/lib/webosbrew/init.d/50-webos-custom-screens
# shellcheck disable=SC2034
TESTED_WEBOS_MAJOR=8 # webOS 23

# Colors only on a terminal, and never when NO_COLOR is set (no-color.org)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m'
    CYAN=$'\033[36m' RESET=$'\033[0m'
else
    BOLD="" DIM="" RED="" GREEN="" YELLOW="" CYAN="" RESET=""
fi
# shellcheck disable=SC2034 # set by the scripts that source this file
NONINTERACTIVE=no
STEP_NUM=0
STEP_TOTAL=0

# step "Title": a numbered heading, like "Step 2 of 4  Finding your TV"
step() {
    STEP_NUM=$((STEP_NUM + 1))
    if [ "$STEP_TOTAL" -gt 0 ]; then
        printf '\n%s%sStep %s of %s%s  %s%s%s\n' "$BOLD" "$CYAN" "$STEP_NUM" "$STEP_TOTAL" "$RESET" "$BOLD" "$*" "$RESET"
    else
        printf '\n%s%s%s\n' "$BOLD" "$*" "$RESET"
    fi
}
info() { printf '  %s\n' "$*"; }
note() { printf '  %s%s%s\n' "$DIM" "$*" "$RESET"; }
ok() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die() { printf '%s✗ %s%s\n' "$RED" "$*" "$RESET" >&2; exit 1; }

# ask "Question?" Y|N: returns 0 for yes. --non-interactive answers yes. Without a terminal
# it takes the default.
ask() {
    local reply="" hint="[y/N]"
    [ "$2" = Y ] && hint="[Y/n]"
    if [ "$NONINTERACTIVE" = yes ]; then
        printf '  %s%s%s %syes (--non-interactive)%s\n' "$BOLD" "$1" "$RESET" "$DIM" "$RESET"
        return 0
    fi
    printf '  %s%s%s %s ' "$BOLD" "$1" "$RESET" "$hint"
    { read -r reply </dev/tty; } 2>/dev/null || echo
    case "${reply:-$2}" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

# Whether $1 accepts connections on port $2 within 2 seconds
port_open() {
    (
        (exec 3<>"/dev/tcp/$1/$2") &
        local conn=$!
        (sleep 2; kill "$conn") &
        local timer=$!
        wait "$conn"
        local rc=$?
        kill "$timer"
        exit "$rc"
    ) 2>/dev/null
}

# Runs one shell line on the TV as root through Homebrew Channel's Telnet and prints its
# output. Gives up when the TV sends nothing for $2 seconds (default 30).
tv_run() {
    local line="" out=""
    exec 3<>"/dev/tcp/$TV/23" || return 1
    # The markers are split with "" so the TV's echo of the command line never matches them
    printf 'echo __WCS_""BEGIN__; %s; echo __WCS_""END__; exit\n' "$1" >&3
    while IFS= read -r -t "${2:-30}" line <&3; do
        out+="$line"$'\n'
    done
    out+="$line"
    exec 3<&-
    printf '%s\n' "$out" | LC_ALL=C tr -cd '\11\12\40-\176' |
        sed -n '/^__WCS_BEGIN__$/,/^__WCS_END__$/p' | sed '1d;$d'
}

# This computer's address on the route to $1
local_ip_for() {
    if [ "$(uname -s)" = Darwin ]; then
        ipconfig getifaddr "$(route -n get "$1" 2>/dev/null | awk '/interface:/ {print $2}')"
    else
        ip -4 route get "$1" 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}'
    fi
}

# Checks ports 23 (Telnet), 3000, and 3001 (LG's app connection) on every address of the
# network $1 (for example 192.168.1) at once. Prints "address port" lines.
scan_network() {
    local tmp i port
    tmp=$(mktemp -d)
    (
        for i in $(seq 1 254); do
            for port in 23 3000 3001; do
                # One process per address, so the kill below stops connections that hang
                (exec 3<>"/dev/tcp/$1.$i/$port" && : >"$tmp/$1.$i $port") >/dev/null &
            done
        done
        sleep 3
        # shellcheck disable=SC2046 # one argument per job
        kill $(jobs -p)
        wait
    ) 2>/dev/null
    ls "$tmp"
    rm -rf "$tmp"
}

# Prints "model|webOS version" when $1 is a webOS TV with root Telnet, nothing otherwise
describe_tv() {
    local TV=$1 out
    out=$(tv_run 'id -u; nyx-cmd OSInfo query webos_release; luna-send -n 1 -f luna://com.webos.service.tv.systemproperty/getSystemInfo "{\"keys\":[\"modelName\"]}"' 10) || return 0
    [ "$(printf '%s\n' "$out" | sed -n 1p)" = 0 ] || return 0
    local version model
    version=$(printf '%s\n' "$out" | sed -n 2p)
    model=$(printf '%s\n' "$out" | sed -n 's/.*"modelName": *"\([^"]*\)".*/\1/p')
    [ -n "$version" ] && printf '%s|%s\n' "${model:-LG TV}" "$version"
}

# Sets TV, TV_MODEL, and TV_VERSION: from --tv when given, otherwise by searching the network
find_tv() {
    local info
    if [ -n "$TV" ]; then
        port_open "$TV" 23 || die "Can't reach Telnet on $TV. Is the TV on, and is Telnet on in Homebrew Channel's settings?"
        info=$(describe_tv "$TV")
        [ -n "$info" ] || die "$TV answers on Telnet but doesn't look like a rooted LG webOS TV."
        TV_MODEL=${info%%|*}
        TV_VERSION=${info#*|}
        ok "TV: $TV_MODEL (webOS $TV_VERSION) at $TV"
        return
    fi

    local my_ip prefix found ip candidates="" others="" count=0
    my_ip=$(local_ip_for 1.1.1.1)
    [ -n "$my_ip" ] || die "Can't tell which network this computer is on. Run again with --tv <TV address>."
    prefix=${my_ip%.*}
    info "Looking for rooted LG TVs on $prefix.x..."
    found=$(scan_network "$prefix")

    # A rooted webOS TV answers on Telnet and on LG's app connection port
    for ip in $(printf '%s\n' "$found" | awk '{print $1}' | sort -u -t . -k 4,4n); do
        [ "$ip" = "$my_ip" ] && continue
        if printf '%s\n' "$found" | grep -qx "$ip 23"; then
            if printf '%s\n' "$found" | grep -qE "^$ip 300[01]$"; then
                info=$(describe_tv "$ip")
                if [ -n "$info" ]; then
                    count=$((count + 1))
                    candidates+="$ip|$info"$'\n'
                fi
            fi
        elif printf '%s\n' "$found" | grep -qx "$ip 3001"; then
            others+="$ip "
        fi
    done

    if [ "$count" -eq 0 ]; then
        warn "No rooted LG TV found on $prefix.x."
        [ -n "$others" ] && warn "These might be LG TVs without root or with Telnet off: $others"
        info "Check that:"
        info "  - the TV is on and on the same network as this computer"
        info "  - the TV is rooted with Homebrew Channel (see https://cani.rootmy.tv/)"
        info "  - Telnet is on in Homebrew Channel's settings"
        info "Or run again with the TV's address: $0 --tv 192.168.1.50"
        note "(TV address: Settings > General > Network > Wi-Fi or Wired Connection > Advanced Settings)"
        exit 1
    fi

    local choice=1 n=0 entry
    if [ "$count" -gt 1 ]; then
        info "Found $count TVs:"
        while IFS= read -r entry; do
            [ -n "$entry" ] || continue
            n=$((n + 1))
            IFS='|' read -r ip TV_MODEL TV_VERSION <<<"$entry"
            info "  $n) $TV_MODEL (webOS $TV_VERSION) at $ip"
        done <<<"$candidates"
        [ "$NONINTERACTIVE" = yes ] && die "Found $count TVs. Pick one with --tv <address>."
        printf '  %sWhich one?%s [1-%s] ' "$BOLD" "$RESET" "$count"
        { read -r choice </dev/tty; } 2>/dev/null || echo
        case "$choice" in
            '' | *[!0-9]*) die "No TV picked." ;;
        esac
        [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ] || die "No TV picked."
    fi
    entry=$(printf '%s' "$candidates" | sed -n "${choice}p")
    IFS='|' read -r TV TV_MODEL TV_VERSION <<<"$entry"
    ok "Found $TV_MODEL (webOS $TV_VERSION) at $TV"
}
