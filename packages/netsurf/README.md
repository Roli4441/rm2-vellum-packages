# NetSurf - Vellum Package

Lightweight web browser for reMarkable tablets, converted from the
[Toltec package](https://github.com/toltec-dev/toltec/tree/stable/package/netsurf).

**Upstream:** https://github.com/alex0809/netsurf-reMarkable

## Conversion Notes (Toltec -> Vellum)

### What changed

| Aspect | Toltec | Vellum |
|--------|--------|--------|
| Package format | `.ipk` (opkg) | `.apk` (Alpine) |
| Recipe file | `package` (Bash) | `VELBUILD` (APKBUILD-based) |
| Build method | From source via Docker | Pre-built binary from release |
| Binary path | `/opt/bin/netsurf` | `/home/root/.vellum/bin/netsurf` |
| Resources path | `/opt/usr/share/netsurf/` | `/home/root/.vellum/share/netsurf/` |
| Config path | `/home/root/.netsurf/Choices` | `/home/root/.netsurf/Choices` (same) |
| Version format | `0.4.0-4` (debian-style) | `0.4.0-r0` (alpine: pkgver + pkgrel) |
| Checksums | SHA-256 | SHA-512 |
| Architecture | `rmall` | `armv7` |
| Launcher | Draft (`.draft` file) | N/A (manual launch) |

### Removed Toltec dependencies

- `display` - Toltec display management (not available in Vellum)
- `dejavu-fonts-ttf-*` - Font packages (replaced with system Noto fonts in Choices)
- `rm2fb-client` - Framebuffer compatibility (via `flags=(patch_rm2fb)`)

### Known limitations

1. **Architecture**: Only `armv7` - the upstream project only provides 32-bit ARM builds.
   No `aarch64` build exists for reMarkable Paper Pro.

2. **Fonts**: The `Choices` file references Noto system fonts (`/usr/share/fonts/ttf/noto/`).
   If fonts don't render correctly, update the paths in `/home/root/.netsurf/Choices`
   to match your device's font locations.

3. **No launcher integration**: The Toltec version used Draft launcher.
   AppLoad integration could be added in a future version.

4. **Framebuffer**: The Toltec version used `rm2fb` for display compatibility.
   On newer firmware with Vellum, display handling may differ.

5. **Old release**: v0.4 is from May 2021. The upstream project appears inactive.
