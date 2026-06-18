#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 simonlinuxcraft
#
# kyber-backend-pref.sh - apply the in-app "Native Wayland" toggle.
#
# The launcher's Settings (Mods / Proton / Wayland) writes a plain file that
# this hook reads BEFORE linuxdeploy-plugin-gtk.sh runs. That GTK hook does
# `export GDK_BACKEND="${GDK_BACKEND:-x11}"`, so whatever we export here wins;
# x11 stays the default when the file is absent. Hive (the app's store) is not
# readable from a shell, hence the plain-file contract.
#
# Sourced under `set -e`; keep it failure-proof.

_kyber_backend_pref() {
    local pref="${XDG_CONFIG_HOME:-$HOME/.config}/kyber-linuxport/backend"
    [ -r "$pref" ] || return 0
    [ "$(cat "$pref" 2>/dev/null)" = "wayland" ] || return 0
    # Only honour Wayland when a Wayland session is actually present. Forcing
    # GDK_BACKEND=wayland on an X11 session leaves GTK with no display to open
    # and the launcher fails to start, with no way back to the in-app toggle.
    # X11 -> ignore the pref and let the GTK hook default to x11.
    [ -n "${WAYLAND_DISPLAY:-}" ] || return 0
    export GDK_BACKEND=wayland
}

_kyber_backend_pref || true
unset -f _kyber_backend_pref
