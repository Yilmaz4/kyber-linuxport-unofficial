#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 simonlinuxcraft
#
# build-appimage.sh — Bundle the Flutter Linux release build into a
# self-contained AppImage for the Kyber Linux Port.
#
# Prerequisites:
#   - flutter build linux --release  (run beforehand)
#   - tools/linuxdeploy-x86_64.AppImage
#   - tools/linuxdeploy-plugin-gtk.sh
#   - tools/appimagetool-x86_64.AppImage
#
# Output:
#   tools/KyberLinuxPort-x86_64.AppImage

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$REPO_ROOT/tools"
LAUNCHER_BUNDLE="$REPO_ROOT/Kyber/Launcher/build/linux/x64/release/bundle"
APPDIR="$TOOLS/KyberLinuxPort.AppDir"
OUTPUT="$TOOLS/KyberLinuxPort-x86_64.AppImage"

SOURCE_URL="https://github.com/simonlinuxcraft/kyber-linuxport-unofficial"

if [ ! -x "$LAUNCHER_BUNDLE/kyber_launcher" ]; then
  echo "ERROR: $LAUNCHER_BUNDLE/kyber_launcher not found." >&2
  echo "Run 'flutter build linux --release' from Kyber/Launcher first." >&2
  exit 1
fi

echo "==> Cleaning previous AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps" \
  "$APPDIR/usr/share/doc/kyber-linux"

echo "==> Copying Flutter bundle into AppDir/usr/"
cp -a "$LAUNCHER_BUNDLE/." "$APPDIR/usr/bin/"

echo "==> Copying licenses + GPL §6 source-availability marker"
cp "$REPO_ROOT/Kyber/LICENSE" "$APPDIR/usr/share/doc/kyber-linux/LICENSE"
cp "$REPO_ROOT/Kyber/NOTICE.md" "$APPDIR/usr/share/doc/kyber-linux/NOTICE.md"
cp "$REPO_ROOT/CHANGELOG.md" "$APPDIR/usr/share/doc/kyber-linux/CHANGELOG.md"
cat > "$APPDIR/usr/share/doc/kyber-linux/source-url.txt" <<EOF
Kyber Linux Port — Corresponding Source (GPLv3 §6(d))

The full corresponding source code for this AppImage is available at:

  $SOURCE_URL

The exact commit / tag matching this AppImage is identified in the
release page of that repository, alongside this binary.

For the wine-helper.exe binary embedded in this AppImage, see
$SOURCE_URL/blob/HEAD/Kyber/CLI/cli_payload/README.md
which carries the GPLv3 §6(b) written offer.
EOF

echo "==> Generating .desktop file"
cat > "$APPDIR/usr/share/applications/kyber-linux.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Kyber (Linux Port)
GenericName=Star Wars Battlefront II Mod Launcher
Comment=Unofficial Linux port of the Kyber mod launcher
Exec=kyber_launcher
Icon=kyber-linux
Terminal=false
Categories=Game;
StartupWMClass=kyber-linux
Keywords=BF2;Battlefront;Kyber;StarWars;
EOF

echo "==> Placing Kyber icon (rendered from SVG)"
# Kyber bundles the proper logo as SVG. The macOS asset bundle has a
# Flutter-default app_icon_*.png that does NOT show the Kyber logo, so we
# render the Kyber SVG instead. Multiple raster sizes plus the SVG go
# into the AppDir so desktop environments can pick the cleanest one.
LOGO_SVG="$REPO_ROOT/Kyber/Launcher/assets/icons/kyber-logo.svg"
if [ ! -f "$LOGO_SVG" ]; then
  echo "ERROR: Kyber logo SVG not found at $LOGO_SVG" >&2
  exit 1
fi
if ! command -v rsvg-convert >/dev/null; then
  echo "ERROR: rsvg-convert (librsvg2-bin) is required to render the icon." >&2
  exit 1
fi
if ! command -v convert >/dev/null; then
  echo "ERROR: ImageMagick (convert) is required to pad icons to square." >&2
  exit 1
fi
for size in 16 24 32 48 64 96 128 192 256 512; do
  mkdir -p "$APPDIR/usr/share/icons/hicolor/${size}x${size}/apps"
  # viewBox is 166x144 (wider than tall). --keep-aspect-ratio keeps the
  # logo from being stretched, then ImageMagick pads the result with
  # transparency back up to a square that linuxdeploy will accept.
  rsvg-convert -w "$size" -h "$size" --keep-aspect-ratio "$LOGO_SVG" \
    | convert - -background none -gravity center -extent "${size}x${size}" \
        "$APPDIR/usr/share/icons/hicolor/${size}x${size}/apps/kyber-linux.png"
done
mkdir -p "$APPDIR/usr/share/icons/hicolor/scalable/apps"
cp "$LOGO_SVG" "$APPDIR/usr/share/icons/hicolor/scalable/apps/kyber-linux.svg"
# linuxdeploy and appimagetool expect the desktop-icon at the AppDir root —
# the 256 raster works as the canonical .DirIcon.
cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/kyber-linux.png" \
  "$APPDIR/kyber-linux.png"

echo "==> Running linuxdeploy with GTK plugin"
cd "$TOOLS"
export NO_STRIP=1
export DEPLOY_GTK_VERSION=3
./linuxdeploy-x86_64.AppImage --appdir "$APPDIR" \
  --executable "$APPDIR/usr/bin/kyber_launcher" \
  --desktop-file "$APPDIR/usr/share/applications/kyber-linux.desktop" \
  --icon-file "$APPDIR/kyber-linux.png" \
  --plugin gtk

echo "==> Patching GTK AppRun hook with runtime loaders.cache regen"
# linuxdeploy regenerates apprun-hooks/linuxdeploy-plugin-gtk.sh on every
# run, dropping any manual edits. The default hook ships a loaders.cache
# with relative module names ("libpixbufloader-svg.so"), which fails to
# resolve at runtime — GTK then aborts when it tries to render a fallback
# image-missing.svg from a system icon theme (e.g. Papirus on Mint).
# Append a runtime regen block guarded by a sentinel so it survives
# rebuilds (linuxdeploy's freshly-written hook lacks the sentinel, so the
# block gets re-appended each time).
GTK_HOOK="$APPDIR/apprun-hooks/linuxdeploy-plugin-gtk.sh"
if [ -f "$GTK_HOOK" ] && ! grep -q "KYBER_PIXBUF_LOADERS_RUNTIME" "$GTK_HOOK"; then
cat >> "$GTK_HOOK" <<'HOOKEOF'

# KYBER_PIXBUF_LOADERS_RUNTIME — regenerate loaders.cache with absolute
# paths into a writable tmpdir; the AppDir's bundled cache has relative
# module names which GdkPixbuf cannot resolve at runtime.
_kyber_gdk_query="$APPDIR/usr/lib/gdk-pixbuf-2.0/gdk-pixbuf-query-loaders"
_kyber_gdk_loader_dir="$APPDIR/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders"
if [ -x "$_kyber_gdk_query" ] && [ -d "$_kyber_gdk_loader_dir" ]; then
    _kyber_gdk_cache_dir="$(mktemp -d)"
    GDK_PIXBUF_MODULEDIR="$_kyber_gdk_loader_dir" "$_kyber_gdk_query" \
        > "$_kyber_gdk_cache_dir/loaders.cache" 2>/dev/null || true
    export GDK_PIXBUF_MODULE_FILE="$_kyber_gdk_cache_dir/loaders.cache"
    unset _kyber_gdk_cache_dir
fi
unset _kyber_gdk_query _kyber_gdk_loader_dir
HOOKEOF
fi

echo "==> Bundling SVG pixbuf loader (linuxdeploy-plugin-gtk skips it)"
# linuxdeploy-plugin-gtk pulls in PNG/JPEG/etc pixbuf loaders but not the
# SVG one because librsvg is an extra dep chain. GTK falls back to
# image-missing.svg from the system icon theme on missing assets, which
# crashes the launcher with "Unable to load image-loading module:
# libpixbufloader-svg.so". Bundle the loader, its deps, and the query-loaders
# binary (needed to regenerate loaders.cache at runtime with the correct
# absolute FUSE mount path — loaders.cache paths must be absolute).
SYS_LOADERS=/usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders
GDK_QUERY_LOADERS=/usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/gdk-pixbuf-query-loaders
APPDIR_LOADERS="$APPDIR/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders"

if [ -f "$SYS_LOADERS/libpixbufloader-svg.so" ] && [ ! -f "$APPDIR_LOADERS/libpixbufloader-svg.so" ]; then
  cp "$SYS_LOADERS/libpixbufloader-svg.so" "$APPDIR_LOADERS/"
  for lib in librsvg-2.so.2 libxml2.so.2 libpangocairo-1.0.so.0 libpango-1.0.so.0 libpangoft2-1.0.so.0; do
    src="/lib/x86_64-linux-gnu/$lib"
    [ ! -f "$src" ] && src="/usr/lib/x86_64-linux-gnu/$lib"
    [ ! -e "$APPDIR/usr/lib/$lib" ] && [ -f "$src" ] && cp -L "$src" "$APPDIR/usr/lib/" || true
  done
fi

# Bundle gdk-pixbuf-query-loaders so the AppRun hook can regenerate
# loaders.cache at startup with the real $APPDIR (= FUSE mount point).
# GDK-Pixbuf requires absolute paths in loaders.cache — relative paths
# silently fail because the library prefixes them with the process cwd,
# not with the FUSE mount root. The FUSE mount path is only known at
# runtime, so the cache must be written then, not at build time.
mkdir -p "$APPDIR/usr/lib/gdk-pixbuf-2.0"
[ ! -f "$APPDIR/usr/lib/gdk-pixbuf-2.0/gdk-pixbuf-query-loaders" ] && \
  cp "$GDK_QUERY_LOADERS" "$APPDIR/usr/lib/gdk-pixbuf-2.0/gdk-pixbuf-query-loaders"

echo "==> Bundling Kyber self-install AppRun hook"
# kyber-self-install.sh registers the desktop integration on first start
# (and refreshes it on version updates). It runs BEFORE the GTK hook so
# zenity/kdialog use the system GTK rather than the bundled AppImage GTK.
cp "$TOOLS/kyber-self-install.sh" "$APPDIR/apprun-hooks/kyber-self-install.sh"
chmod +x "$APPDIR/apprun-hooks/kyber-self-install.sh"

echo "==> Bundling kyber-playmode recovery script"
# Recovery script for users whose inject keeps failing. AppRun catches
# --playmode and runs this directly via Steam, no launcher in between.
cp "$TOOLS/kyber-playmode.sh" "$APPDIR/usr/bin/kyber-playmode"
chmod +x "$APPDIR/usr/bin/kyber-playmode"

# linuxdeploy regenerates AppRun from scratch every run, so this patch is
# applied each build (sentinel-guarded for idempotency within a single run).
APPRUN="$APPDIR/AppRun"
if [ -f "$APPRUN" ] && ! grep -q "KYBER_SELF_INSTALL_HOOK" "$APPRUN"; then
  python3 - "$APPRUN" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
src = p.read_text()
# Insert before the linuxdeploy-plugin-gtk source line so the dialog tool
# (zenity/kdialog) uses the system GTK, not the AppImage's bundled GTK.
needle = 'source "$this_dir"/apprun-hooks/"linuxdeploy-plugin-gtk.sh"'
inject = (
    '# KYBER_SELF_INSTALL_HOOK\n'
    'if [ -f "$this_dir"/apprun-hooks/kyber-self-install.sh ]; then\n'
    '    source "$this_dir"/apprun-hooks/kyber-self-install.sh || true\n'
    'fi\n'
    '\n'
)
if needle in src and 'KYBER_SELF_INSTALL_HOOK' not in src:
    src = src.replace(needle, inject + needle, 1)
    p.write_text(src)
PYEOF
fi

# --playmode shortcut: skip everything launcher-side, drop straight
# into kyber-playmode. Has to be patched into AppRun every build
# because linuxdeploy rewrites AppRun from scratch. Sentinel keeps
# the patch idempotent within one run.
if [ -f "$APPRUN" ] && ! grep -q "KYBER_PLAYMODE_BRANCH" "$APPRUN"; then
  python3 - "$APPRUN" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
src = p.read_text()
needle = '# KYBER_SELF_INSTALL_HOOK'
inject = (
    '# KYBER_PLAYMODE_BRANCH\n'
    'if [ "${1:-}" = "--playmode" ]; then\n'
    '    shift\n'
    '    exec "$this_dir"/usr/bin/kyber-playmode "$@"\n'
    'fi\n'
    '\n'
)
if needle in src and 'KYBER_PLAYMODE_BRANCH' not in src:
    src = src.replace(needle, inject + needle, 1)
    p.write_text(src)
PYEOF
fi

echo "==> Restoring Flutter RUNPATH"
# linuxdeploy rewrites the launcher's RUNPATH from '$ORIGIN/lib' (Flutter's
# default, pointing at bundle-local plugin libs) to '$ORIGIN/../lib' so it
# can pull in centralised system deps. That breaks dynamically-loaded
# plugin libs (rhttp, media_kit, etc.) which the Dart side opens by bare
# filename via DynamicLibrary.open. Restore the Flutter convention; the
# system deps linuxdeploy added in usr/lib/ are still found because GTK's
# linker glue brings them in via NEEDED entries on the GTK libs themselves.
patchelf --set-rpath '$ORIGIN/lib' "$APPDIR/usr/bin/kyber_launcher"

echo "==> Building AppImage"
# AppImage runtime selection.
#
# We embed the modern type-2 runtime from AppImage/type2-runtime instead
# of letting `appimagetool` use its default runtime. The default is FUSE2-
# only and silently fails to start on FUSE3-only distros (Bazzite,
# Fedora Silverblue, Kinoite — all immutable Fedora-based, where libfuse2
# cannot be installed). The type-2 runtime is statically PIE-linked,
# probes FUSE3 first, falls back to FUSE2, and auto-degrades to
# `--appimage-extract-and-run` when neither is available.
#
# Net effect: a single AppImage that boots out-of-the-box on Ubuntu,
# Fedora (regular + atomic / Silverblue / Bazzite), Arch and derivatives.
#
# When the runtime file is missing we fall back to the bundled default
# so the build does not silently regress on a fresh checkout.
RUNTIME_FILE="$TOOLS/type2-runtime-x86_64"
RUNTIME_ARGS=()
if [[ -f "$RUNTIME_FILE" ]]; then
    echo "    Using type-2 runtime from $RUNTIME_FILE"
    RUNTIME_ARGS+=( --runtime-file "$RUNTIME_FILE" )
else
    echo "    WARNING: $RUNTIME_FILE missing — falling back to default FUSE2 runtime."
    echo "    Built AppImage will NOT start on Bazzite / Silverblue / Fedora atomic."
    echo "    Download via: gh release download continuous --repo AppImage/type2-runtime --pattern 'runtime-x86_64' --output tools/type2-runtime-x86_64"
fi
ARCH=x86_64 ./appimagetool-x86_64.AppImage --no-appstream "${RUNTIME_ARGS[@]}" "$APPDIR" "$OUTPUT"

echo
echo "==> Done"
echo "AppImage: $OUTPUT"
ls -lh "$OUTPUT"
