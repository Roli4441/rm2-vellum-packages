# NetSurf - Vellum Package

Lightweight web browser for reMarkable 2 tablets, converted from the
[Toltec package](https://github.com/toltec-dev/toltec/tree/stable/package/netsurf)
with [AppLoad](https://github.com/asivery/rm-appload) integration.

**Upstream:** https://github.com/alex0809/netsurf-reMarkable

## How it works

After installation, NetSurf appears as an app in AppLoad. It runs as a
fullscreen framebuffer application using the `qtfb-shim` for display
compatibility with the latest reMarkable OS.

### File locations

| What | Path |
|------|------|
| App directory | `/home/root/xovi/exthome/appload/netsurf/` |
| Binary | `.../netsurf/nsfb` |
| Resources | `.../netsurf/resources/` |
| Config | `/home/root/.netsurf/Choices` |
| AppLoad manifest | `.../netsurf/external.manifest.json` |

### Dependencies

- **appload** (Vellum package) - XOVI app launcher extension
- **qtfb-shim** (installed by appload) - framebuffer compatibility
- **libevdev.so.2** - auto-copied from system during install

## Configuration

Edit `/home/root/.netsurf/Choices` to customize:

- `scale:150` - UI scale factor (increase for larger elements)
- `font_size:180` - base font size for e-ink readability
- `fb_osk:1` - on-screen keyboard enabled
- `fb_toolbar_size:60` - toolbar height in pixels
- Font paths (default: system Noto fonts)

## Troubleshooting

### NetSurf won't start

1. Check `libevdev.so.2` is present in the app directory:
   ```
   ls /home/root/xovi/exthome/appload/netsurf/libevdev.so.2
   ```
   If missing, find it on your system:
   ```
   find / -name "libevdev.so*" 2>/dev/null
   cp /usr/lib/libevdev.so.2 /home/root/xovi/exthome/appload/netsurf/
   ```

2. Verify the shim exists:
   ```
   ls /home/root/shims/qtfb-shim.so
   ```

### Fonts don't render

The default config points to Noto system fonts at `/usr/share/fonts/ttf/noto/`.
If those paths don't exist on your firmware version, update
`/home/root/.netsurf/Choices` with correct font paths:
```
find /usr/share/fonts -name "*.ttf" 2>/dev/null
```

### App doesn't appear in launcher

Refresh AppLoad after installation (swipe down or restart xochitl).

## Conversion notes (Toltec -> Vellum)

| Aspect | Toltec | Vellum |
|--------|--------|--------|
| Package format | `.ipk` (opkg) | `.apk` (Alpine) |
| Binary path | `/opt/bin/netsurf` | `xovi/exthome/appload/netsurf/nsfb` |
| Resources | `/opt/usr/share/netsurf/` | `.../appload/netsurf/resources/` |
| Launcher | Draft (`.draft` file) | AppLoad (`external.manifest.json`) |
| Display compat | `rm2fb-client` | `qtfb-shim` via AppLoad |
| Fonts | DejaVu (Toltec package) | Noto (system fonts) |
| Architecture | `rmall` | `armv7` |
| Checksums | SHA-256 | SHA-512 |
