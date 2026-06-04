#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 simonlinuxcraft
#
# kyber-steamdeck-hint.sh - AppRun hook that shows a one-time note on
# SteamOS / Steam Deck explaining the EA login flow there.
#
# On Steam Deck (Desktop Mode) the EA login opens in the system browser,
# which is usually a Flatpak browser. A Flatpak browser does not hand the
# qrc:// OAuth redirect back to the launcher, so the automatic callback
# never arrives and the login appears to hang. The launcher's login screen
# has a paste field for exactly this case; this hook points the user at it
# before they spend time troubleshooting.
#
# Sourced by AppRun before linuxdeploy-plugin-gtk.sh so zenity/kdialog load
# against the system GTK and not the bundled one.
#
# Skips silently when not on SteamOS/Steam Deck, when KYBER_NO_STEAMDECK_HINT
# is set, or when it has already been shown once.

_kyber_steamdeck_hint_main() {
    [ -n "${KYBER_NO_STEAMDECK_HINT:-}" ] && return 0

    # Detect Steam Deck / SteamOS. The Steam client exports SteamDeck=1 in
    # Game Mode; SteamOS sets ID=steamos in /etc/os-release. Require one of
    # these explicit signals so a normal Arch box (SteamOS 3 is Arch-based)
    # is never matched.
    local is_deck=0
    [ "${SteamDeck:-}" = "1" ] && is_deck=1
    [ -n "${SteamOS:-}" ] && is_deck=1
    if [ "$is_deck" = 0 ] && [ -r /etc/os-release ]; then
        local id
        id="$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")"
        [ "$id" = "steamos" ] && is_deck=1
    fi
    [ "$is_deck" = 0 ] && return 0

    local state_dir="$HOME/.local/share/kyber-linuxport"
    local marker="$state_dir/.steamdeck-hint-shown"
    [ -f "$marker" ] && return 0

    command -v zenity >/dev/null 2>&1 || command -v kdialog >/dev/null 2>&1 || return 0

    local title="Kyber (Linux Port) - Steam Deck"
    local body
    body="$(printf 'Running on SteamOS / Steam Deck.\n\nUse Desktop Mode for the launcher.\n\nEA login: the launcher opens the EA sign-in page in your browser. On Steam Deck the browser is usually a Flatpak app, which does not hand the login back to the launcher automatically, so the login can look stuck.\n\nIf that happens, use the field under "Browser did not return to the launcher?" on the login screen: after signing in, copy the link or code the browser tried to open and paste it there.\n\nAlternative: run the launcher inside a Distrobox container with webkit2gtk installed.\n\n(This note is shown once.)')"

    if command -v zenity >/dev/null 2>&1; then
        LC_ALL=C.UTF-8 LANGUAGE=en zenity --info --no-wrap --title="$title" --text="$body" 2>/dev/null || true
    else
        LC_ALL=C.UTF-8 LANGUAGE=en kdialog --title "$title" --msgbox "$body" 2>/dev/null || true
    fi

    mkdir -p "$state_dir"
    : > "$marker"
    return 0
}

_kyber_steamdeck_hint_main || true
unset -f _kyber_steamdeck_hint_main
