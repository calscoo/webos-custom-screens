#!/usr/bin/env bash
# Puts your pictures on a rooted LG webOS TV. See ./install.sh --help
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

usage() {
    cat <<EOF
${BOLD}Usage:${RESET} ./install.sh [options]

Puts your pictures on a rooted LG webOS TV. It shows what it will do and asks
before each big step.

With no options, both screens get this project's pictures:
  - the photos in the screensaver folder, on the screensaver and the no-signal screen
  - logo.png, on the power-off screen

${BOLD}Options${RESET} (mix and match any of them)
  ${BOLD}--screensaver${RESET} [FOLDER]  Change only the screensaver and the no-signal screen.
                          Uses the photos in FOLDER, or this project's screensaver
                          folder when FOLDER is left out. The power-off logo stays
                          as it is on the TV, unless you also pass --logo.
  ${BOLD}--logo${RESET} [FILE]           Change only the power-off logo.
                          Uses the picture FILE, or this project's logo.png when
                          FILE is left out. The screensaver stays as it is on the
                          TV, unless you also pass --screensaver.
  ${BOLD}--no-shuffle${RESET}            Leave out the shuffle helper (see the README).
  ${BOLD}--tv${RESET} ADDRESS            Use the TV at this address and skip the search.
  ${BOLD}--non-interactive${RESET}       Answer yes to every question. Needs --tv when the
                          search finds more than one TV.
  ${BOLD}-h, --help${RESET}              Show this help.

${BOLD}Examples${RESET}
  ./install.sh                                  this project's pictures on both screens
  ./install.sh --screensaver ~/Pictures/tv      your photos, logo unchanged
  ./install.sh --logo ~/Pictures/logo.png       your logo, photos unchanged
  ./install.sh --screensaver ~/Pictures/tv --logo ~/Pictures/logo.png
                                                your photos and your logo
  ./install.sh --logo                           this project's logo only

Undo everything with ./uninstall.sh
EOF
}

# --- Options ----------------------------------------------------------------------------

DO_SAVER=no
SAVER_DIR=""
DO_LOGO=no
LOGO_FILE=""
SHUFFLE=yes
TV=""

# Whether $1 is a value for the option before it, not the next option
is_value() { [ "${1#-}" = "$1" ]; }

while [ $# -gt 0 ]; do
    case "$1" in
        --screensaver)
            DO_SAVER=yes
            if [ $# -gt 1 ] && is_value "$2"; then
                SAVER_DIR=$2
                shift
            fi
            ;;
        --screensaver=*) DO_SAVER=yes SAVER_DIR=${1#*=} ;;
        --logo)
            DO_LOGO=yes
            if [ $# -gt 1 ] && is_value "$2"; then
                LOGO_FILE=$2
                shift
            fi
            ;;
        --logo=*) DO_LOGO=yes LOGO_FILE=${1#*=} ;;
        --no-shuffle) SHUFFLE=no ;;
        --tv)
            TV=${2:-}
            [ -n "$TV" ] && is_value "$TV" || die "--tv needs the TV's address, like --tv 192.168.1.50"
            shift
            ;;
        --tv=*) TV=${1#*=} ;;
        --non-interactive) NONINTERACTIVE=yes ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*) die "Unknown option $1. See ./install.sh --help" ;;
        *) die "Unexpected \"$1\". For a photo folder, use: ./install.sh --screensaver \"$1\". See ./install.sh --help" ;;
    esac
    shift
done

# "~/Pictures" written as --screensaver=~/Pictures reaches the script without the shell's ~
expand_home() {
    case "$1" in
        "~") printf '%s\n' "$HOME" ;;
        "~/"*) printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

DEFAULTS=no
if [ "$DO_SAVER" = no ] && [ "$DO_LOGO" = no ]; then
    DO_SAVER=yes DO_LOGO=yes DEFAULTS=yes
fi
if [ "$SHUFFLE" = no ] && [ "$DO_SAVER" = no ]; then
    warn "--no-shuffle only changes the screensaver, so it does nothing with --logo alone."
fi

# --- Tools on this computer -------------------------------------------------------------

if command -v magick >/dev/null 2>&1; then
    IMG=magick
elif command -v convert >/dev/null 2>&1 && convert -version 2>/dev/null | grep -q ImageMagick; then
    IMG=convert
elif [ "$(uname -s)" = Darwin ]; then
    IMG=sips
else
    die "ImageMagick is needed to prepare the pictures. Install it (for example: sudo apt install imagemagick) and run again."
fi
if [ "$(uname -s)" != Darwin ] && ! command -v python3 >/dev/null 2>&1; then
    die "python3 is needed to send the pictures to the TV. Install it and run again."
fi

# --- Pictures -------------------------------------------------------------------------

list_images() {
    find "$1" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' \
        -o -iname '*.heif' -o -iname '*.webp' -o -iname '*.tif' -o -iname '*.tiff' \) 2>/dev/null | sort
}

# Whether $1 is a picture file this computer can read
is_image() {
    case "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" in
        *.jpg | *.jpeg | *.png | *.heic | *.heif | *.webp | *.tif | *.tiff) ;;
        *) return 1 ;;
    esac
    if [ "$IMG" = sips ]; then
        sips -g pixelWidth "$1" 2>/dev/null | grep -q 'pixelWidth: [0-9]'
    else
        "$IMG" "$1[0]" -format '%w' info: >/dev/null 2>&1
    fi
}

if [ "$DO_SAVER" = yes ]; then
    if [ -n "$SAVER_DIR" ]; then
        SAVER_DIR=$(expand_home "$SAVER_DIR")
        [ -e "$SAVER_DIR" ] || die "--screensaver: there's no folder at $SAVER_DIR"
        [ -d "$SAVER_DIR" ] || die "--screensaver needs a folder of photos, and $SAVER_DIR is a file. For one photo, put it in a folder by itself."
        SAVER_DIR=$(cd "$SAVER_DIR" && pwd)
    else
        SAVER_DIR="$HERE/screensaver"
    fi
    PHOTO_LIST=$(list_images "$SAVER_DIR")
    [ -n "$PHOTO_LIST" ] || die "No photos in $SAVER_DIR. Add JPG, PNG, HEIC, WebP, or TIFF files and run again."
    PHOTO_COUNT=$(printf '%s\n' "$PHOTO_LIST" | wc -l | tr -d ' ')
fi

if [ "$DO_LOGO" = yes ]; then
    if [ -n "$LOGO_FILE" ]; then
        LOGO_FILE=$(expand_home "$LOGO_FILE")
        [ -e "$LOGO_FILE" ] || die "--logo: there's no file at $LOGO_FILE"
        [ -d "$LOGO_FILE" ] && die "--logo needs one picture file, and $LOGO_FILE is a folder."
        is_image "$LOGO_FILE" || die "--logo: $LOGO_FILE isn't a picture this tool can read (JPG, PNG, HEIC, WebP, or TIFF)."
    else
        LOGO_FILE="$HERE/logo.png"
    fi
fi

STEP_TOTAL=4
printf '%swebOS Custom Screens%s\n' "$BOLD" "$RESET"

step "What will change"
if [ "$DO_SAVER" = yes ]; then
    if [ "$SAVER_DIR" = "$HERE/screensaver" ]; then
        info "${BOLD}Screensaver and no-signal screen:${RESET} this project's $PHOTO_COUNT photos (screensaver folder)"
    else
        info "${BOLD}Screensaver and no-signal screen:${RESET} $PHOTO_COUNT photos from $SAVER_DIR"
    fi
    [ "$SHUFFLE" = no ] && note "  without the shuffle helper"
else
    info "${BOLD}Screensaver and no-signal screen:${RESET} no change"
fi
if [ "$DO_LOGO" = no ]; then
    info "${BOLD}Power-off logo:${RESET} no change"
elif [ "$LOGO_FILE" = "$HERE/logo.png" ]; then
    info "${BOLD}Power-off logo:${RESET} this project's logo.png"
else
    info "${BOLD}Power-off logo:${RESET} $LOGO_FILE"
fi
if [ "$DEFAULTS" = yes ]; then
    note "No --screensaver or --logo given, so both screens get this project's pictures."
    note "To use your own, see ./install.sh --help"
fi
ask "Continue?" Y || { info "Stopped. Nothing changed."; exit 0; }

# --- The TV ---------------------------------------------------------------------------

step "Finding your TV"
ASKED_TV=$TV
find_tv
if [ -z "$ASKED_TV" ]; then
    ask "Use this TV?" Y || { info "Stopped. Nothing changed."; exit 0; }
fi

major=${TV_VERSION%%.*}
if [ "$major" != "$TESTED_WEBOS_MAJOR" ]; then
    warn "This tool is tested on webOS 23 (version $TESTED_WEBOS_MAJOR.x) only. Your TV runs $TV_VERSION."
    warn "It may not work, and ./uninstall.sh puts LG's screens back if it doesn't."
    ask "Try anyway?" N || { info "Stopped. Nothing changed."; exit 0; }
fi

info "Checking the TV..."
check=$(tv_run "S=/usr/palm/applications/com.webos.app.screensaver/qml/main.qml; A=/mnt/lg/appstore/preload/igallery/files/data/modernart; L=/usr/lib/qml/MasterBrand/LG_logo.png; echo saver=\$([ -f \$S ] && echo yes); echo art=\$([ -d \$A ] && echo yes); echo logo=\$([ -f \$L ] && echo yes); echo saver_mount=\$(findmnt -n -o SOURCE \$S | tail -n 1); echo art_mount=\$(findmnt -n -o SOURCE \$A | tail -n 1); echo logo_mount=\$(findmnt -n -o SOURCE \$L | tail -n 1); echo free_kb=\$(df -Pk /media/developer | awk 'NR==2 {print \$4}'); echo python=\$([ -x /usr/bin/python3 ] && echo yes)")
value() { printf '%s\n' "$check" | sed -n "s/^$1=//p"; }
ours() {
    case "$1" in
        "" | */webos-custom-screens/* | */webos-custom-screens.*) return 0 ;;
        *) return 1 ;;
    esac
}

if [ "$DO_SAVER" = yes ]; then
    ours "$(value saver_mount)" || die "Another mod (like Aerial or Custom Screensaver) already replaces this TV's screensaver. Turn it off in that app first, then run this again."
    ours "$(value art_mount)" || die "Another mod already replaces this TV's no-signal art. Turn it off first, then run this again."
    [ "$(value saver)" = yes ] || warn "This TV has no home and app screensaver file this tool knows. That screen stays as it is."
    [ "$(value art)" = yes ] || warn "This TV has no no-signal art folder this tool knows. That screen stays as it is."
    [ "$(value saver)" = yes ] || [ "$(value art)" = yes ] || DO_SAVER=no
    if [ "$DO_SAVER" = yes ] && [ "$SHUFFLE" = yes ] && [ "$(value python)" != yes ]; then
        warn "This TV has no Python, so the no-signal art shows photos in random order without the shuffle helper."
        SHUFFLE=no
    fi
fi
if [ "$DO_LOGO" = yes ]; then
    if [ "$(value logo)" != yes ]; then
        warn "This TV has no power-off logo file this tool knows. That screen stays as it is."
        DO_LOGO=no
    elif ! ours "$(value logo_mount)"; then
        warn "Another mod already replaces the power-off logo. That screen stays as it is."
        DO_LOGO=no
    fi
fi
[ "$DO_SAVER" = yes ] || [ "$DO_LOGO" = yes ] || die "Nothing on this TV that this tool can change."
ok "The TV is ready"

# --- Prepare the pictures ---------------------------------------------------------------

step "Preparing the pictures"

SRGB="/System/Library/ColorSync/Profiles/sRGB Profile.icc"
SRGB_ARGS=(-colorspace sRGB)
[ -f "$SRGB" ] && SRGB_ARGS=(-profile "$SRGB")
BUILD="$HERE/.build"
size_of() { sips -g pixelWidth -g pixelHeight "$1" | awk '/pixel/ {printf "%s ", $2}'; }

# 1920x1080 JPEG that fills the screen: scaled to cover 16:9, then center-cropped.
# The TV draws these screens at 1920x1080.
prepare_with_imagemagick() {
    "$IMG" "$1[0]" -auto-orient "${SRGB_ARGS[@]}" -resize 1920x1080^ -gravity center -extent 1920x1080 -strip -quality 92 "$2"
}

# Same result with macOS's built-in sips. sips can't read a photo's rotation tag, so a photo
# taken sideways on a phone stays sideways unless it was exported upright.
prepare_with_sips() {
    local tmp="$2.tmp.jpg" w h
    sips -s format jpeg "$1" --out "$tmp" >/dev/null || return 1
    read -r w h <<<"$(size_of "$tmp")"
    if [ $((w * 1080)) -ge $((h * 1920)) ]; then
        sips --resampleHeight 1080 "$tmp" >/dev/null
    else
        sips --resampleWidth 1920 "$tmp" >/dev/null
    fi
    read -r w h <<<"$(size_of "$tmp")"
    [ "$w" -ge 1920 ] || sips --resampleWidth 1920 "$tmp" >/dev/null
    read -r w h <<<"$(size_of "$tmp")"
    [ "$h" -ge 1080 ] || sips --resampleHeight 1080 "$tmp" >/dev/null
    sips -c 1080 1920 "$tmp" >/dev/null &&
        sips -m "$SRGB" -s formatOptions 92 "$tmp" --out "$2" >/dev/null
    local rc=$?
    rm -f "$tmp"
    return $rc
}

# prepare_logo SOURCE OUT WIDTH HEIGHT: a PNG that fits in WIDTHxHEIGHT, keeping transparency.
# ImageMagick also trims empty edges. The TV draws it centered on black.
prepare_logo() {
    local w h
    if [ "$IMG" = sips ]; then
        sips -s format png "$1" --out "$2" >/dev/null || return 1
        read -r w h <<<"$(size_of "$2")"
        if [ $((w * $4)) -ge $((h * $3)) ]; then
            sips --resampleWidth "$3" "$2" >/dev/null
        else
            sips --resampleHeight "$4" "$2" >/dev/null
        fi
    else
        "$IMG" "$1[0]" -auto-orient "${SRGB_ARGS[@]}" -trim +repage -resize "${3}x${4}" -strip "PNG32:$2"
    fi
}

if [ "$DO_SAVER" = yes ]; then
    [ "$IMG" = sips ] && warn "ImageMagick isn't installed, so photos taken sideways on a phone may show sideways. See the README."
    # Photos are kept between runs and redone when they change. Another folder starts fresh.
    if [ "$(cat "$BUILD/photos.from" 2>/dev/null)" != "$SAVER_DIR" ]; then
        rm -rf "$BUILD/photos"
    fi
    mkdir -p "$BUILD/photos"
    printf '%s\n' "$SAVER_DIR" >"$BUILD/photos.from"
    keep="$BUILD/keep.txt"
    : >"$keep"
    while IFS= read -r src; do
        # A plain file name keeps the TV's image paths simple: "Beach (1).HEIC" becomes "Beach__1_.jpg"
        name="$(basename "${src%.*}" | LC_ALL=C tr -c 'A-Za-z0-9._\n-' '_').jpg"
        echo "$name" >>"$keep"
        out="$BUILD/photos/$name"
        [ "$out" -nt "$src" ] && continue
        note "$(basename "$src")"
        if [ "$IMG" = sips ]; then
            prepare_with_sips "$src" "$out"
        else
            prepare_with_imagemagick "$src" "$out"
        fi || { rm -f "$out"; die "Couldn't prepare $(basename "$src")."; }
    done <<<"$PHOTO_LIST"
    for f in "$BUILD/photos"/*.jpg; do
        [ -f "$f" ] || continue
        grep -qxF "$(basename "$f")" "$keep" || rm -f "$f"
    done
    rm -f "$keep"
    ok "$PHOTO_COUNT photos, cropped to fill the screen"
fi

# The power-off logo, about the size of LG's: up to 640x320 on the TV's 1920x1080 screen
rm -rf "$BUILD/logo"
if [ "$DO_LOGO" = yes ]; then
    mkdir -p "$BUILD/logo"
    note "$(basename "$LOGO_FILE")"
    { prepare_logo "$LOGO_FILE" "$BUILD/logo/LG_logo.png" 640 320 &&
        prepare_logo "$LOGO_FILE" "$BUILD/logo/LG_logo_4k.png" 1280 640; } ||
        die "Couldn't prepare $(basename "$LOGO_FILE")."
    ok "Logo, sized to about LG's logo"
fi
ask "Send them to the TV?" Y || { info "Stopped. Nothing changed on the TV."; exit 0; }

# --- Send everything to the TV ------------------------------------------------------------

step "Sending to the TV"

STAGE="$BUILD/stage"
rm -rf "$STAGE" "$BUILD/bundle.tar"
mkdir -p "$STAGE"
cp "$HERE/tv/screensaver.qml" "$STAGE/main.qml"
cp "$HERE/tv/apply.sh" "$STAGE/apply.sh"
cp "$HERE/tv/shuffle.py" "$STAGE/shuffle.py"
if [ "$DO_SAVER" = yes ]; then
    mkdir -p "$STAGE/photos"
    cp "$BUILD/photos"/*.jpg "$STAGE/photos/"
    [ "$SHUFFLE" = no ] && : >"$STAGE/no-shuffle"
fi
[ "$DO_LOGO" = yes ] && cp -R "$BUILD/logo" "$STAGE/logo"
COPYFILE_DISABLE=1 tar --format=ustar -cf "$BUILD/bundle.tar" -C "$STAGE" . || die "Couldn't package the files."
rm -rf "$STAGE"

bundle_kb=$(($(wc -c <"$BUILD/bundle.tar") / 1024))
free_kb=$(value free_kb)
if [ -n "$free_kb" ] && [ "$free_kb" -lt $((bundle_kb * 2)) ]; then
    die "The TV doesn't have enough free space for these pictures."
fi

MY_IP=$(local_ip_for "$TV")
[ -n "$MY_IP" ] || die "Can't tell this computer's address on the TV's network."
PORT=$((49152 + RANDOM % 10000))

# The TV downloads the files from this computer, once. This computer listens only until then.
SERVER_PID=""
cleanup() {
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
    rm -f "$BUILD/bundle.tar"
}
trap cleanup EXIT
if [ "$(uname -s)" = Darwin ]; then
    # macOS's own nc: the macOS firewall lets Apple's tools accept the TV's connection
    {
        printf 'HTTP/1.0 200 OK\r\nContent-Type: application/x-tar\r\nContent-Length: %s\r\nConnection: close\r\n\r\n' \
            "$(wc -c <"$BUILD/bundle.tar" | tr -d ' ')"
        cat "$BUILD/bundle.tar"
    } | /usr/bin/nc -l "$PORT" >/dev/null 2>&1 &
else
    python3 - "$BUILD/bundle.tar" "$MY_IP" "$PORT" >/dev/null 2>&1 <<'PY' &
import http.server, os, sys
path, host, port = sys.argv[1], sys.argv[2], int(sys.argv[3])
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Length", str(os.path.getsize(path)))
        self.end_headers()
        with open(path, "rb") as f:
            self.wfile.write(f.read())
http.server.HTTPServer((host, port), Handler).handle_request()
PY
fi
SERVER_PID=$!
sleep 1

# On the TV: unpack into a new folder, carry over the screen this run doesn't change (photos
# and their no-shuffle choice, or the logo), swap the folders, then turn the screens on.
info "Sending to $TV..."
result=$(tv_run "D=$TV_DIR; rm -rf \$D.new && mkdir -p \$D.new && wget -q -T 20 -O - http://$MY_IP:$PORT/bundle.tar | tar -x -o -C \$D.new && [ -f \$D.new/apply.sh ] && { [ -d \$D.new/photos ] || [ ! -d \$D/photos ] || { mv \$D/photos \$D.new/ && { [ ! -f \$D/no-shuffle ] || mv \$D/no-shuffle \$D.new/; }; }; } && { [ -d \$D.new/logo ] || [ ! -d \$D/logo ] || mv \$D/logo \$D.new/; } && chmod -R a+rX \$D.new && chmod 755 \$D.new/apply.sh && rm -rf \$D.old && { [ ! -d \$D ] || mv \$D \$D.old; } && mv \$D.new \$D && mkdir -p ${TV_HOOK%/*} && printf '#!/bin/sh\nexec $TV_DIR/apply.sh\n' > $TV_HOOK && chmod 755 $TV_HOOK && \$D/apply.sh && rm -rf \$D.old && echo WCS_OK" 300)

printf '%s\n' "$result" | while IFS= read -r line; do
    case "$line" in
        "[+] "*) ok "${line#\[+\] }" ;;
        "[~] "*) warn "${line#\[~\] }" ;;
        "[-] "*) warn "${line#\[-\] }" ;;
    esac
done
if ! printf '%s\n' "$result" | grep -qx WCS_OK; then
    echo
    if ! printf '%s\n' "$result" | grep -q '^\[[+~-]\]'; then
        warn "The TV couldn't download the files from this computer ($MY_IP, port $PORT)."
        warn "A firewall on this computer may be blocking it. See Troubleshooting in the README."
    fi
    die "Install didn't finish. Your TV's screens are unchanged or partly changed. Run ./uninstall.sh to reset them."
fi

printf '\n%s%sDone!%s Your pictures are on the TV.\n' "$BOLD" "$GREEN" "$RESET"
[ "$DO_SAVER" = yes ] && info "See your photos: switch the TV to an HDMI input with nothing plugged in."
[ "$DO_LOGO" = yes ] && info "See your logo: turn the TV off with the remote."
[ "$DEFAULTS" = yes ] && info "Use your own pictures: see ./install.sh --help"
info "Undo everything: ./uninstall.sh"
echo
note "Tip: Telnet lets anyone on your network control the TV. You can turn it off in"
note "Homebrew Channel's settings now, and your pictures keep working. Turn it back on"
note "when you want to update or uninstall."
