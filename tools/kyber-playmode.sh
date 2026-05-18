#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Recovery launch: start BF2 directly without going through the Kyber
# launcher and its DLL inject.
#
# Use this when the launcher's inject step keeps failing on your distro
# and you just want to play. You'll get vanilla BF2: Kyber features
# (custom servers, lobby browser, party voice, mods) won't be active.
#
# Invoked from the AppImage via `--playmode`:
#   ./KyberLinuxPort-x86_64.AppImage --playmode
# or from a terminal:
#   bash kyber-playmode.sh

set -u

log() { echo "[kyber-playmode] $*" >&2; }

BF2_APPID=1237950

# Prefer the system `steam` binary. It knows the user's Steam library
# locations, picks the right Proton version, and reuses BF2's existing
# compatdata prefix. Same path the Big Picture "Play" button hits.
if command -v steam >/dev/null 2>&1; then
  log "Launching BF2 via Steam (AppID $BF2_APPID)"
  exec steam -applaunch "$BF2_APPID" "$@"
fi

# Fallback: steam:// URL handler. Works for Steam-as-Flatpak setups that
# register the URL scheme but don't put `steam` on PATH.
if command -v xdg-open >/dev/null 2>&1; then
  log "Launching BF2 via xdg-open steam://run/$BF2_APPID"
  exec xdg-open "steam://run/$BF2_APPID"
fi

log "Couldn't find a Steam binary or xdg-open."
log "Install Steam (or a desktop integration that registers steam:// URLs)"
log "and rerun."
exit 1
