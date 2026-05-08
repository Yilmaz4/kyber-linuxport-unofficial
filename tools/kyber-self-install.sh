#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 simonlinuxcraft
#
# kyber-self-install.sh — AppRun hook that registers desktop integration on
# first start and refreshes it when the AppImage version changes.
#
# Sourced by AppRun BEFORE linuxdeploy-plugin-gtk.sh, so dialog tools
# (zenity/kdialog) load against the system GTK and not the bundled one.
#
# This hook is a no-op when:
#   - $APPIMAGE is unset (e.g. running --appimage-extract-and-run)
#   - $KYBER_NO_AUTO_INSTALL is set (CI / packaging contexts)
#   - the marker file already matches the current AppImage's size+mtime
#
# Behaviour matrix:
#   first start, no marker        → ask user (zenity), install on confirm
#   marker present, ID matches    → no-op (fast path)
#   marker present, ID differs    → silent re-install (force update)
#   user declines first dialog    → write "declined" marker, don't ask again
#                                    until version changes

# Defensive: this hook is sourced under `set -e`. Any unexpected error must
# not break the launcher. Wrap everything in a function and trap.
_kyber_self_install_main() {
    [ -z "${APPIMAGE:-}" ] && return 0
    [ -n "${KYBER_NO_AUTO_INSTALL:-}" ] && return 0
    [ ! -f "$APPIMAGE" ] && return 0

    local current_id
    current_id="$(stat -c '%s-%Y' "$APPIMAGE" 2>/dev/null)" || return 0
    [ -z "$current_id" ] && return 0

    local state_dir="$HOME/.local/share/kyber-linuxport"
    local marker="$state_dir/.installed-version"
    local declined_marker="$state_dir/.declined-version"

    # Fast path: already installed for this exact AppImage.
    if [ -f "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$current_id" ]; then
        return 0
    fi

    # User previously declined for this exact AppImage — don't pester.
    if [ -f "$declined_marker" ] && [ "$(cat "$declined_marker" 2>/dev/null)" = "$current_id" ]; then
        return 0
    fi

    local is_update=0
    [ -f "$marker" ] && is_update=1

    # Confirm dialog — only on first install, not on version updates
    # (updates are silent, the user already opted in once).
    if [ "$is_update" = 0 ]; then
        local prompt_title="Kyber (Linux Port)"
        local prompt_text="Kyber als Anwendung registrieren?\n\nFügt Kyber zum Anwendungsmenü hinzu, installiert das Icon und registriert die qrc:// und nxm:// URL-Handler für EA-Login und Nexus Mods.\n\nDas AppImage wird nach ~/Applications/ kopiert.\n\nKann jederzeit deinstalliert werden."
        local user_choice=1

        if command -v zenity >/dev/null 2>&1; then
            zenity --question --no-wrap --title="$prompt_title" --text="$prompt_text" 2>/dev/null && user_choice=0
        elif command -v kdialog >/dev/null 2>&1; then
            kdialog --title "$prompt_title" --yesno "$(printf '%b' "$prompt_text")" 2>/dev/null && user_choice=0
        else
            # No dialog tool — auto-install with stderr notice. Endnutzer
            # auf Mint/GNOME/KDE haben praktisch immer zenity oder kdialog,
            # dieser Pfad ist nur für Headless-/Minimal-Systeme.
            echo "kyber-self-install: no zenity/kdialog found, installing automatically" >&2
            user_choice=0
        fi

        if [ "$user_choice" != 0 ]; then
            mkdir -p "$state_dir"
            echo "$current_id" > "$declined_marker"
            return 0
        fi
    fi

    _kyber_self_install_run "$current_id" "$is_update" || return 0
}

_kyber_self_install_run() {
    local current_id="$1"
    local is_update="$2"

    local apps_dir="$HOME/Applications"
    local appimage_dst="$apps_dir/KyberLinuxPort-x86_64.AppImage"
    local extract_dir="$apps_dir/KyberLinuxPort.extracted"
    local desktop_dir="$HOME/.local/share/applications"
    local state_dir="$HOME/.local/share/kyber-linuxport"
    local marker="$state_dir/.installed-version"
    local declined_marker="$state_dir/.declined-version"

    mkdir -p "$apps_dir" "$desktop_dir" "$state_dir"

    # 1. Copy AppImage to ~/Applications/ if it isn't there yet.
    # Realpath-compare to handle the case where it's already at the target.
    local src_real dst_real
    src_real="$(readlink -f "$APPIMAGE" 2>/dev/null || echo "$APPIMAGE")"
    dst_real="$(readlink -f "$appimage_dst" 2>/dev/null || echo "$appimage_dst")"
    if [ "$src_real" != "$dst_real" ]; then
        cp "$APPIMAGE" "$appimage_dst" || return 1
        chmod +x "$appimage_dst" || true
    fi

    # 2. Re-extract for stable URL-handler paths. FUSE mount paths change
    # every run, so qrc:// and nxm:// .desktop files cannot point at $APPDIR.
    rm -rf "$extract_dir"
    (
        cd "$apps_dir" && "$appimage_dst" --appimage-extract >/dev/null 2>&1
    ) || return 1
    mv "$apps_dir/squashfs-root" "$extract_dir" || return 1

    # 3. Install icons from the extracted AppDir.
    local size src dst
    for size in 16 24 32 48 64 96 128 192 256 512; do
        src="$extract_dir/usr/share/icons/hicolor/${size}x${size}/apps/kyber-linux.png"
        [ -f "$src" ] || continue
        dst="$HOME/.local/share/icons/hicolor/${size}x${size}/apps"
        mkdir -p "$dst"
        cp "$src" "$dst/kyber-linux.png"
    done
    if [ -f "$extract_dir/usr/share/icons/hicolor/scalable/apps/kyber-linux.svg" ]; then
        mkdir -p "$HOME/.local/share/icons/hicolor/scalable/apps"
        cp "$extract_dir/usr/share/icons/hicolor/scalable/apps/kyber-linux.svg" \
            "$HOME/.local/share/icons/hicolor/scalable/apps/kyber-linux.svg"
    fi

    # 4. Clean leftover .desktop files from previous installs (legacy names).
    rm -f \
        "$desktop_dir/kyber.desktop" \
        "$desktop_dir/kyber-bf2.desktop" \
        "$desktop_dir/kyber-bf2-nxm.desktop" \
        "$desktop_dir/kyber-bf2-linuxport.desktop" \
        "$desktop_dir/kyber-bf2-linuxport-qrc.desktop" \
        "$desktop_dir/kyber-bf2-linuxport-nxm.desktop" \
        "$desktop_dir/kyber-nxm-handler.desktop" \
        "$desktop_dir/maxima-qrc.desktop"

    # 5. Write the three .desktop entries — main + qrc + nxm handlers.
    # Absolute icon path avoids Papirus/custom-theme fallthrough to a
    # generic placeholder when the bare icon name isn't carried by the theme.
    local icon_abs="$HOME/.local/share/icons/hicolor/256x256/apps/kyber-linux.png"
    local nxm_bin="$extract_dir/usr/bin/cli/bin/nxm_handler.sh"
    local qrc_bin="$extract_dir/usr/bin/cli/maxima-bootstrap"

    cat > "$desktop_dir/kyber-linuxport.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Kyber (Linux Port)
GenericName=Star Wars Battlefront II Mod Launcher
Comment=Unofficial Linux port of the Kyber mod launcher
Exec=env -u GIO_MODULE_DIR __GL_MaxFramesAllowed=1 $appimage_dst
Icon=$icon_abs
Terminal=false
Categories=Game;
StartupWMClass=kyber-linux
Keywords=BF2;Battlefront;Kyber;StarWars;
EOF

    cat > "$desktop_dir/kyber-linuxport-qrc.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Kyber QRC Handler
Comment=Receives qrc:// OAuth redirects for the Kyber EA login flow.
Exec=$qrc_bin %u
NoDisplay=true
Terminal=false
StartupNotify=false
MimeType=x-scheme-handler/qrc;
EOF

    cat > "$desktop_dir/kyber-linuxport-nxm.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Kyber NXM Handler
Comment=Receives nxm:// links from Nexus Mods and forwards them to the Kyber launcher.
Exec=$nxm_bin %u
NoDisplay=true
Terminal=false
StartupNotify=false
MimeType=x-scheme-handler/nxm;
EOF

    # 6. Refresh caches and register MIME handlers.
    update-desktop-database "$desktop_dir" 2>/dev/null || true
    gtk-update-icon-cache -t -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    xdg-mime default kyber-linuxport-qrc.desktop x-scheme-handler/qrc 2>/dev/null || true
    xdg-mime default kyber-linuxport-nxm.desktop x-scheme-handler/nxm 2>/dev/null || true

    # 7. Persist marker, drop any stale "declined" marker.
    echo "$current_id" > "$marker"
    rm -f "$declined_marker"

    # 8. Visual feedback. On updates we stay silent; on first install
    # a passive notification confirms the desktop entry was added.
    if [ "$is_update" = 0 ] && command -v notify-send >/dev/null 2>&1; then
        notify-send --icon="$icon_abs" \
            "Kyber (Linux Port)" \
            "Wurde zu deinen Anwendungen hinzugefügt." 2>/dev/null || true
    fi

    return 0
}

# Run, swallowing any errors so a broken self-install never blocks the app.
_kyber_self_install_main || true
unset -f _kyber_self_install_main _kyber_self_install_run
