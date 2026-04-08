#!/bin/bash
# NetSurf telepítő szkript reMarkable 2-höz (manuális teszt)
# Futtasd közvetlenül a tableten SSH-n keresztül!
#
# Használat:
#   chmod +x install-netsurf.sh
#   ./install-netsurf.sh install    # Telepítés
#   ./install-netsurf.sh uninstall  # Eltávolítás
#   ./install-netsurf.sh status     # Állapot ellenőrzés

set -e

APPDIR="/home/root/xovi/exthome/appload/netsurf"
CONFIGDIR="/home/root/.netsurf"
TMPDIR="/tmp/netsurf-install"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[HIBA]${NC} $1"; }

check_prerequisites() {
    echo "=== Előfeltételek ellenőrzése ==="

    # XOVI
    if [ -d "/home/root/xovi" ]; then
        ok "XOVI telepítve"
    else
        fail "XOVI nincs telepítve! Telepítsd előbb a XOVI-t."
        exit 1
    fi

    # AppLoad
    if [ -d "/home/root/xovi/exthome/appload" ]; then
        ok "AppLoad könyvtár létezik"
    else
        fail "AppLoad nincs telepítve! Telepítsd előbb: vellum add appload"
        exit 1
    fi

    # qtfb-shim
    if [ -f "/home/root/shims/qtfb-shim.so" ]; then
        ok "qtfb-shim.so megtalálva"
    else
        warn "qtfb-shim.so NEM található itt: /home/root/shims/qtfb-shim.so"
        warn "NetSurf valószínűleg nem fog elindulni nélküle."
    fi

    # libevdev
    local libevdev_found=""
    for p in /usr/lib/libevdev.so.2 /lib/libevdev.so.2 /usr/lib/arm-linux-gnueabihf/libevdev.so.2; do
        if [ -f "$p" ]; then
            libevdev_found="$p"
            break
        fi
    done
    if [ -n "$libevdev_found" ]; then
        ok "libevdev.so.2 megtalálva: $libevdev_found"
    else
        warn "libevdev.so.2 NEM található a rendszeren!"
        warn "Keresés minden lehetséges helyen..."
        find / -name "libevdev.so*" 2>/dev/null || true
    fi

    # Fontok ellenőrzése
    echo ""
    echo "=== Elérhető fontok ==="
    if [ -d "/usr/share/fonts" ]; then
        find /usr/share/fonts -name "*.ttf" 2>/dev/null | head -n 20
        ok "Fontok találhatók"
    else
        warn "Nincs font a /usr/share/fonts alatt!"
    fi

    # Szabad hely
    echo ""
    echo "=== Lemezterület ==="
    df -h /home
}

do_install() {
    echo ""
    echo "========================================="
    echo "  NetSurf telepítés - reMarkable 2"
    echo "========================================="
    echo ""

    check_prerequisites

    echo ""
    echo "=== Letöltés ==="
    mkdir -p "$TMPDIR"
    cd "$TMPDIR"

    echo "nsfb.tar.gz letöltése..."
    if ! curl -sL -o nsfb.tar.gz \
        "https://github.com/alex0809/netsurf-reMarkable/releases/download/v0.4/nsfb.tar.gz"; then
        fail "Nem sikerült letölteni nsfb.tar.gz"
        exit 1
    fi
    ok "nsfb.tar.gz letöltve ($(du -h nsfb.tar.gz | cut -f1))"

    echo "LICENSE letöltése..."
    curl -sL -o LICENSE \
        "https://github.com/alex0809/netsurf-reMarkable/releases/download/v0.4/LICENSE"
    ok "LICENSE letöltve"

    echo ""
    echo "=== Kicsomagolás ==="
    tar -xzf nsfb.tar.gz
    ok "nsfb.tar.gz kicsomagolva"

    echo ""
    echo "=== Telepítés: $APPDIR ==="
    mkdir -p "$APPDIR"
    mkdir -p "$APPDIR/resources"

    # Bináris
    cp nsfb "$APPDIR/nsfb"
    chmod 755 "$APPDIR/nsfb"
    ok "nsfb bináris telepítve"

    # Erőforrások
    cp -r resources/* "$APPDIR/resources/"
    ok "Erőforrás fájlok telepítve"

    # Ikon
    cp resources/netsurf.png "$APPDIR/icon.png"
    ok "Ikon telepítve"

    # libevdev.so.2
    if [ ! -f "$APPDIR/libevdev.so.2" ]; then
        # Először a rendszeren keressük
        for libpath in /usr/lib/libevdev.so.2 /lib/libevdev.so.2 /usr/lib/arm-linux-gnueabihf/libevdev.so.2; do
            if [ -f "$libpath" ]; then
                cp "$libpath" "$APPDIR/libevdev.so.2"
                ok "libevdev.so.2 másolva innen: $libpath"
                break
            fi
        done
    fi
    if [ ! -f "$APPDIR/libevdev.so.2" ]; then
        # Ha nincs a rendszeren, letöltjük a repoból
        echo "libevdev.so.2 nincs a rendszeren, letöltés a repoból..."
        if curl -sL -o "$APPDIR/libevdev.so.2" \
            "https://raw.githubusercontent.com/Roli4441/rm2-vellum-packages/claude/vellum-package-manager-kgTeQ/packages/netsurf/libevdev.so.2"; then
            ok "libevdev.so.2 letöltve a repoból"
        else
            fail "libevdev.so.2 letöltése sikertelen!"
            fail "NetSurf nem fog elindulni nélküle."
        fi
    fi

    # AppLoad manifest
    cat > "$APPDIR/external.manifest.json" << 'MANIFEST'
{
    "name": "NetSurf",
    "application": "nsfb",
    "args": ["-v", "-r", "/home/root/xovi/exthome/appload/netsurf/resources"],
    "workingDirectory": "/home/root/xovi/exthome/appload/netsurf",
    "environment": {
        "HOME": "/home/root",
        "NETSURF_FB_RESPATH": "/home/root/xovi/exthome/appload/netsurf/resources/",
        "QTFB_SHIM_MODEL": "0",
        "QTFB_SHIM_INPUT_MODE": "NATIVE",
        "LD_LIBRARY_PATH": "/usr/lib:.",
        "LD_PRELOAD": "/home/root/shims/qtfb-shim.so"
    },
    "qtfb": true,
    "aspectRatio": "original",
    "disablesWindowedMode": true
}
MANIFEST
    ok "external.manifest.json létrehozva"

    # Choices konfiguráció
    mkdir -p "$CONFIGDIR"
    if [ ! -f "$CONFIGDIR/Choices" ]; then
        # Fontútvonalak detektálása
        local sans_font serif_font mono_font
        sans_font=$(find /usr/share/fonts -iname "*NotoSans-Regular*" -o -iname "*DejaVuSans.ttf" 2>/dev/null | head -n 1)
        serif_font=$(find /usr/share/fonts -iname "*NotoSerif-Regular*" -o -iname "*DejaVuSerif.ttf" 2>/dev/null | head -n 1)
        mono_font=$(find /usr/share/fonts -iname "*NotoMono*" -o -iname "*DejaVuSansMono.ttf" 2>/dev/null | head -n 1)

        # Fallbackok
        [ -z "$sans_font" ] && sans_font=$(find /usr/share/fonts -name "*.ttf" 2>/dev/null | head -n 1)
        [ -z "$serif_font" ] && serif_font="$sans_font"
        [ -z "$mono_font" ] && mono_font="$sans_font"

        if [ -n "$sans_font" ]; then
            ok "Fontok detektálva: $sans_font"
        else
            warn "Nem találtam TTF fontokat! A Choices fájlban kézzel kell megadni."
            sans_font="/usr/share/fonts/ttf/noto/NotoSans-Regular.ttf"
            serif_font="/usr/share/fonts/ttf/noto/NotoSerif-Regular.ttf"
            mono_font="/usr/share/fonts/ttf/noto/NotoMono-Regular.ttf"
        fi

        cat > "$CONFIGDIR/Choices" << CHOICES
homepage_url:about:welcome
fb_download_directory:/home/root/Downloads
fb_xochitl_restart_command:systemctl restart xochitl

scale:150
font_size:180
enable_javascript:0

fb_face_sans_serif:${sans_font}
fb_face_sans_serif_bold:${sans_font}
fb_face_sans_serif_italic:${sans_font}
fb_face_sans_serif_italic_bold:${sans_font}
fb_face_serif:${serif_font}
fb_face_serif_bold:${serif_font}
fb_face_cursive:${serif_font}
fb_face_monospace:${mono_font}
fb_face_monospace_bold:${mono_font}
fb_face_fantasy:${sans_font}

fb_toolbar_size:60
fb_furniture_size:40
fb_osk:1
CHOICES
        ok "Choices konfiguráció létrehozva (detektált fontokkal)"
    else
        ok "Choices már létezik, nem írom felül"
    fi

    # Takarítás
    rm -rf "$TMPDIR"

    echo ""
    echo "========================================="
    echo -e "  ${GREEN}Telepítés kész!${NC}"
    echo "========================================="
    echo ""
    echo "Következő lépések:"
    echo "  1. Frissítsd az AppLoad-ot (húzd le az értesítéseket vagy"
    echo "     indítsd újra a xochitl-t: systemctl restart xochitl)"
    echo "  2. Keresd a 'NetSurf' alkalmazást az AppLoad-ban"
    echo "  3. Ha nem indul el, futtasd: $0 status"
    echo ""
    echo "Eltávolítás: $0 uninstall"
}

do_uninstall() {
    echo "=== NetSurf eltávolítás ==="

    if [ -d "$APPDIR" ]; then
        rm -rf "$APPDIR"
        ok "AppLoad könyvtár törölve: $APPDIR"
    else
        warn "AppLoad könyvtár nem létezik: $APPDIR"
    fi

    echo ""
    read -p "Töröljem a konfigurációt is ($CONFIGDIR)? [i/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ii]$ ]]; then
        rm -rf "$CONFIGDIR"
        ok "Konfiguráció törölve"
    else
        ok "Konfiguráció megtartva"
    fi

    echo ""
    ok "Eltávolítás kész. Indítsd újra a xochitl-t: systemctl restart xochitl"
}

do_status() {
    echo "=== NetSurf állapot ==="
    echo ""

    # Fájlok
    echo "--- Fájlok ---"
    for f in \
        "$APPDIR/nsfb" \
        "$APPDIR/external.manifest.json" \
        "$APPDIR/icon.png" \
        "$APPDIR/libevdev.so.2" \
        "$APPDIR/resources/default.css" \
        "$CONFIGDIR/Choices" \
        "/home/root/shims/qtfb-shim.so"; do
        if [ -f "$f" ]; then
            ok "$f"
        else
            fail "$f  HIÁNYZIK!"
        fi
    done

    # Bináris ellenőrzés
    echo ""
    echo "--- Bináris info ---"
    if [ -f "$APPDIR/nsfb" ]; then
        file "$APPDIR/nsfb"
        echo ""
        echo "Szükséges könyvtárak:"
        readelf -d "$APPDIR/nsfb" 2>/dev/null | grep NEEDED || echo "(readelf nem elérhető)"
    fi

    # Futtathatóság teszt
    echo ""
    echo "--- Indítási teszt (száraz futtatás) ---"
    if [ -f "$APPDIR/nsfb" ]; then
        export LD_LIBRARY_PATH="/usr/lib:$APPDIR"
        ldd "$APPDIR/nsfb" 2>&1 || echo "(ldd nem elérhető, skip)"
    fi

    # Font teszt
    echo ""
    echo "--- Choices font útvonalak ellenőrzése ---"
    if [ -f "$CONFIGDIR/Choices" ]; then
        while IFS=: read -r key value; do
            if [[ "$key" == fb_face_* ]]; then
                if [ -f "$value" ]; then
                    ok "$key -> $value"
                else
                    fail "$key -> $value  NEM LÉTEZIK!"
                fi
            fi
        done < "$CONFIGDIR/Choices"
    else
        warn "Choices fájl nem található"
    fi
}

case "${1:-}" in
    install)   do_install ;;
    uninstall) do_uninstall ;;
    status)    do_status ;;
    *)
        echo "Használat: $0 {install|uninstall|status}"
        echo ""
        echo "  install    - NetSurf letöltése és telepítése"
        echo "  uninstall  - NetSurf eltávolítása"
        echo "  status     - Telepítés állapotának ellenőrzése"
        exit 1
        ;;
esac
