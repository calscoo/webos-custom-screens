#!/usr/bin/env bash
# Puts your pictures on a rooted LG webOS TV: photos on the screensaver and the no-signal
# screen, and a logo on the power-off screen. Run it again any time to update them.
#
#   ./install.sh                    use the photos and logo folders (samples when they're empty)
#   ./install.sh ~/Pictures/tv      use the photos in another folder
#   ./install.sh --logo ~/me.png    use this picture as the power-off logo
#   ./install.sh --no-logo          keep LG's power-off logo
#   ./install.sh --no-shuffle       leave out the shuffle helper (see README)
#   ./install.sh --tv 192.168.1.50  skip the TV search
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

PHOTOS=""
LOGO_SRC=""
USE_LOGO=yes
BUILD="$HERE/.build"
SHUFFLE=yes
TV=""
SRGB="/System/Library/ColorSync/Profiles/sRGB Profile.icc"

while [ $# -gt 0 ]; do
    case "$1" in
        --logo)
            LOGO_SRC=${2:-}
            [ -n "$LOGO_SRC" ] || die "--logo needs a picture, like --logo ~/Pictures/logo.png"
            shift
            ;;
        --no-logo) USE_LOGO=no ;;
        --no-shuffle) SHUFFLE=no ;;
        --tv)
            TV=${2:-}
            [ -n "$TV" ] || die "--tv needs the TV's address, like --tv 192.168.1.50"
            shift
            ;;
        -h | --help)
            sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*) die "Unknown option $1. See ./install.sh --help" ;;
        *) PHOTOS=$1 ;;
    esac
    shift
done
[ -n "$LOGO_SRC" ] && [ "$USE_LOGO" = no ] && die "Use --logo or --no-logo, not both."

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

SAMPLE_PHOTOS=no
if [ -n "$PHOTOS" ]; then
    [ -d "$PHOTOS" ] || die "There's no folder at $PHOTOS"
    PHOTO_LIST=$(list_images "$PHOTOS")
    [ -n "$PHOTO_LIST" ] || die "No photos in $PHOTOS. Put your photos there (JPG, PNG, HEIC, WebP, or TIFF) and run again."
else
    PHOTO_LIST=$(list_images "$HERE/photos")
    if [ -z "$PHOTO_LIST" ]; then
        PHOTO_LIST=$(list_images "$HERE/samples/photos")
        SAMPLE_PHOTOS=yes
    fi
fi
PHOTO_COUNT=$(printf '%s\n' "$PHOTO_LIST" | wc -l | tr -d ' ')

LOGO_FILE=""
SAMPLE_LOGO=no
if [ "$USE_LOGO" = yes ]; then
    if [ -n "$LOGO_SRC" ]; then
        [ -f "$LOGO_SRC" ] || die "There's no picture at $LOGO_SRC"
        LOGO_FILE=$LOGO_SRC
    else
        LOGO_FILE=$(list_images "$HERE/logo" | head -n 1)
        if [ -z "$LOGO_FILE" ]; then
            LOGO_FILE="$HERE/samples/logo.png"
            SAMPLE_LOGO=yes
        elif [ "$(list_images "$HERE/logo" | wc -l)" -gt 1 ]; then
            warn "The logo folder has more than one picture. Using $(basename "$LOGO_FILE")."
        fi
    fi
fi

step "Your pictures"
if [ "$SAMPLE_PHOTOS" = yes ]; then
    echo "  Photos: $PHOTO_COUNT sample photos (the photos folder is empty)"
else
    echo "  Photos: $PHOTO_COUNT from $(cd "$(dirname "$(printf '%s\n' "$PHOTO_LIST" | head -n 1)")" && pwd)"
fi
if [ "$USE_LOGO" = no ]; then
    echo "  Power-off logo: LG's"
elif [ "$SAMPLE_LOGO" = yes ]; then
    echo "  Power-off logo: the sample logo (the logo folder is empty)"
else
    echo "  Power-off logo: $(basename "$LOGO_FILE")"
fi

# --- The TV ---------------------------------------------------------------------------

ASKED_TV=$TV
find_tv
if [ -z "$ASKED_TV" ]; then
    ask "Put these on this TV?" Y || exit 0
fi

major=${TV_VERSION%%.*}
if [ "$major" != "$TESTED_WEBOS_MAJOR" ]; then
    warn "This tool is tested on webOS 23 (version $TESTED_WEBOS_MAJOR.x) only. Your TV runs $TV_VERSION."
    warn "It may not work, and ./uninstall.sh puts LG's screens back if it doesn't."
    ask "Try anyway?" N || exit 0
fi

step "Checking the TV..."
check=$(tv_run "S=/usr/palm/applications/com.webos.app.screensaver/qml/main.qml; A=/mnt/lg/appstore/preload/igallery/files/data/modernart; L=/usr/lib/qml/MasterBrand/LG_logo.png; echo saver=\$([ -f \$S ] && echo yes); echo art=\$([ -d \$A ] && echo yes); echo logo=\$([ -f \$L ] && echo yes); echo saver_mount=\$(findmnt -n -o SOURCE \$S | tail -n 1); echo art_mount=\$(findmnt -n -o SOURCE \$A | tail -n 1); echo logo_mount=\$(findmnt -n -o SOURCE \$L | tail -n 1); echo free_kb=\$(df -Pk /media/developer | awk 'NR==2 {print \$4}'); echo python=\$([ -x /usr/bin/python3 ] && echo yes)")
value() { printf '%s\n' "$check" | sed -n "s/^$1=//p"; }
ours() {
    case "$1" in
        "" | */webos-custom-screens/* | */webos-custom-screens.*) return 0 ;;
        *) return 1 ;;
    esac
}

ours "$(value saver_mount)" || die "Another mod (like Aerial or Custom Screensaver) already replaces this TV's screensaver. Turn it off in that app first, then run this again."
ours "$(value art_mount)" || die "Another mod already replaces this TV's no-signal art. Turn it off first, then run this again."
[ "$(value saver)" = yes ] || warn "This TV has no home and app screensaver file this tool knows. That screen stays as it is."
[ "$(value art)" = yes ] || warn "This TV has no no-signal art folder this tool knows. That screen stays as it is."
if [ -n "$LOGO_FILE" ]; then
    if [ "$(value logo)" != yes ]; then
        warn "This TV has no power-off logo file this tool knows. That screen stays as it is."
        LOGO_FILE=""
    elif ! ours "$(value logo_mount)"; then
        warn "Another mod already replaces the power-off logo. That screen stays as it is."
        LOGO_FILE=""
    fi
fi
[ "$(value saver)" = yes ] || [ "$(value art)" = yes ] || [ -n "$LOGO_FILE" ] || die "Nothing on this TV that this tool can replace."
if [ "$SHUFFLE" = yes ] && [ "$(value python)" != yes ]; then
    warn "This TV has no Python, so the no-signal art shows photos in random order without the shuffle helper."
    SHUFFLE=no
fi
ok "Ready"

# --- Prepare the pictures ---------------------------------------------------------------

SRGB_ARGS=(-colorspace sRGB)
[ -f "$SRGB" ] && SRGB_ARGS=(-profile "$SRGB")
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

step "Preparing the pictures..."
[ "$IMG" = sips ] && warn "ImageMagick isn't installed, so photos taken sideways on a phone may show sideways. See the README."
mkdir -p "$BUILD/photos"
keep="$BUILD/keep.txt"
: >"$keep"
while IFS= read -r src; do
    # A plain file name keeps the TV's image paths simple: "Beach (1).HEIC" becomes "Beach__1_.jpg"
    name="$(basename "${src%.*}" | LC_ALL=C tr -c 'A-Za-z0-9._\n-' '_').jpg"
    echo "$name" >>"$keep"
    out="$BUILD/photos/$name"
    [ "$out" -nt "$src" ] && continue
    echo "  $(basename "$src")"
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

# The power-off logo, about the size of LG's: up to 640x320 on the TV's 1920x1080 screen
rm -rf "$BUILD/logo"
if [ -n "$LOGO_FILE" ]; then
    mkdir -p "$BUILD/logo"
    echo "  $(basename "$LOGO_FILE") (power-off logo)"
    { prepare_logo "$LOGO_FILE" "$BUILD/logo/LG_logo.png" 640 320 &&
        prepare_logo "$LOGO_FILE" "$BUILD/logo/LG_logo_4k.png" 1280 640; } ||
        die "Couldn't prepare $(basename "$LOGO_FILE")."
fi
ok "Pictures ready"

# --- Send everything to the TV ------------------------------------------------------------

STAGE="$BUILD/stage"
rm -rf "$STAGE" "$BUILD/bundle.tar"
mkdir -p "$STAGE/photos"
cp "$HERE/tv/screensaver.qml" "$STAGE/main.qml"
cp "$HERE/tv/apply.sh" "$STAGE/apply.sh"
[ "$SHUFFLE" = yes ] && cp "$HERE/tv/shuffle.py" "$STAGE/shuffle.py"
cp "$BUILD/photos"/*.jpg "$STAGE/photos/"
[ -n "$LOGO_FILE" ] && cp -R "$BUILD/logo" "$STAGE/logo"
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

step "Sending to the TV..."
result=$(tv_run "D=$TV_DIR; rm -rf \$D.new && mkdir -p \$D.new && wget -q -T 20 -O - http://$MY_IP:$PORT/bundle.tar | tar -x -o -C \$D.new && [ -f \$D.new/apply.sh ] && chmod -R a+rX \$D.new && chmod 755 \$D.new/apply.sh && rm -rf \$D.old && { [ ! -d \$D ] || mv \$D \$D.old; } && mv \$D.new \$D && mkdir -p ${TV_HOOK%/*} && printf '#!/bin/sh\nexec $TV_DIR/apply.sh\n' > $TV_HOOK && chmod 755 $TV_HOOK && \$D/apply.sh && rm -rf \$D.old && echo WCS_OK" 300)

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

step "Done! Your pictures are on the TV."
echo "  No-signal screen: switch the TV to an input with nothing plugged in."
[ -n "$LOGO_FILE" ] && echo "  Power-off logo: turn the TV off with the remote."
[ "$SAMPLE_PHOTOS" = yes ] && echo "  Those are sample photos. Put yours in the photos folder and run ./install.sh again."
[ "$SAMPLE_LOGO" = yes ] && [ -n "$LOGO_FILE" ] &&
    echo "  That's a sample logo. Put yours in the logo folder, or keep LG's with ./install.sh --no-logo."
echo "  Change pictures: update the photos or logo folder and run ./install.sh again."
echo "  Undo everything: ./uninstall.sh"
echo
echo "Tip: Telnet lets anyone on your network control the TV. You can turn it off in"
echo "Homebrew Channel's settings now, and your pictures keep working. Turn it back on"
echo "when you want to update or uninstall."
