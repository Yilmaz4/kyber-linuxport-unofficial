#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 simonlinuxcraft
#
# kyber-vulkan-precheck.sh - AppRun hook that warns the user when the
# system has no real GPU driver and Vulkan only exposes a software
# renderer (Mesa llvmpipe / lavapipe / swrast).
#
# BF2's Frostbite engine boots its DX11 renderer through Wine+DXVK on top
# of the system Vulkan stack. On software-Vulkan the renderer fails with
# CreateTexture2D E_INVALIDARG after ~25 s and the game uploads a crash
# report on its own. The launcher then sees the LSX FIN and spams
# "gRPC server unavailable" for a while. That is a long way to learn
# "no GPU driver installed".
#
# Sourced by AppRun before linuxdeploy-plugin-gtk.sh so zenity loads
# against the system GTK and not the bundled one.
#
# Skips silently when vulkaninfo is not available, when KYBER_NO_VULKAN_PRECHECK
# is set, or when a real (non-software) GPU is among the reported devices.

_kyber_vulkan_precheck_main() {
    [ -n "${KYBER_NO_VULKAN_PRECHECK:-}" ] && return 0
    command -v vulkaninfo >/dev/null 2>&1 || return 0

    # --summary is the lightweight mode; the full output is large and slow.
    local summary
    summary="$(vulkaninfo --summary 2>/dev/null)" || return 0
    [ -z "$summary" ] && return 0

    # Collect every deviceName line from the summary. Format looks like:
    #   deviceName         = llvmpipe (LLVM 22.1.3, 256 bits)
    local gpus
    gpus="$(printf '%s\n' "$summary" \
        | awk -F'=' '/deviceName/ {sub(/^[[:space:]]+/,"",$2); sub(/[[:space:]]+$/,"",$2); print $2}' \
        | awk 'NF' | sort -u)"
    [ -z "$gpus" ] && return 0

    # If any reported device is NOT one of the known software renderers,
    # the host has a real GPU and we stay out of the way.
    if printf '%s\n' "$gpus" | grep -qiv -E '^(llvmpipe|lavapipe|swrast|softpipe)'; then
        return 0
    fi

    # Hash of the device set, so we only prompt once per unique result.
    # If the user later installs a real driver the hash changes and the
    # dialog will not appear again because the early-return above hits.
    local current_hash
    current_hash="$(printf '%s' "$gpus" | md5sum 2>/dev/null | awk '{print $1}')"
    [ -z "$current_hash" ] && return 0

    local state_dir="$HOME/.local/share/kyber-linuxport"
    local marker="$state_dir/.vulkan-precheck-shown"
    if [ -f "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$current_hash" ]; then
        return 0
    fi

    command -v zenity >/dev/null 2>&1 || command -v kdialog >/dev/null 2>&1 || return 0

    # Distro-specific install hint. ID and ID_LIKE come from /etc/os-release.
    local id id_like distro_hint
    id="$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")"
    id_like="$(. /etc/os-release 2>/dev/null && printf '%s' "${ID_LIKE:-}")"
    case "$id" in
        arch|cachyos|manjaro|endeavouros|garuda|artix)
            distro_hint="Arch family:
  AMD:    sudo pacman -S vulkan-radeon lib32-vulkan-radeon
  NVIDIA: sudo pacman -S nvidia-utils lib32-nvidia-utils
  Intel:  sudo pacman -S vulkan-intel lib32-vulkan-intel"
            ;;
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali|raspbian)
            distro_hint="Ubuntu/Debian family:
  AMD/Intel: sudo apt install mesa-vulkan-drivers libgl1-mesa-dri
  NVIDIA:    sudo ubuntu-drivers autoinstall   (Ubuntu)
             or install the proprietary nvidia-driver-XXX package"
            ;;
        fedora|nobara|bazzite|silverblue|kinoite|rocky|almalinux|centos|rhel)
            distro_hint="Fedora/RHEL family:
  AMD/Intel: sudo dnf install mesa-vulkan-drivers mesa-dri-drivers
  NVIDIA:    enable RPM Fusion, then sudo dnf install akmod-nvidia
             (Silverblue/Kinoite: layer via rpm-ostree install)"
            ;;
        opensuse-tumbleweed|opensuse-leap|opensuse|sles|suse)
            distro_hint="openSUSE/SUSE family:
  AMD/Intel: sudo zypper install Mesa libvulkan1
  NVIDIA:    sudo zypper install x11-video-nvidiaG06   (Tumbleweed/Leap)"
            ;;
        nixos)
            distro_hint="NixOS:
  Edit configuration.nix and enable hardware.opengl with
  hardware.opengl.driSupport = true; vendor-specific drivers
  via hardware.nvidia.* / boot.kernelParams. nixos-rebuild switch."
            ;;
        gentoo)
            distro_hint="Gentoo:
  Set VIDEO_CARDS in make.conf (amdgpu / nvidia / intel) and
  emerge --update --newuse @world to pull the Vulkan ICDs."
            ;;
        alpine|chimera|void)
            distro_hint="Alpine/Void/Chimera:
  AMD/Intel: install mesa-vulkan-* via your package manager.
  NVIDIA:    proprietary driver, distro-specific."
            ;;
        *)
            case " $id_like " in
                *' arch '*)
                    distro_hint="Arch-based:  sudo pacman -S vulkan-radeon | nvidia-utils | vulkan-intel"
                    ;;
                *' debian '*|*' ubuntu '*)
                    distro_hint="Debian-based:  sudo apt install mesa-vulkan-drivers (or vendor NVIDIA driver)"
                    ;;
                *' fedora '*|*' rhel '*|*' centos '*)
                    distro_hint="Fedora-based:  sudo dnf install mesa-vulkan-drivers (NVIDIA via RPM Fusion)"
                    ;;
                *' suse '*|*' opensuse '*)
                    distro_hint="openSUSE-based:  sudo zypper install Mesa libvulkan1"
                    ;;
                *)
                    distro_hint="Install your distribution's Vulkan driver package (search for 'mesa-vulkan' or vendor driver)."
                    ;;
            esac
            ;;
    esac

    local title="Kyber (Linux Port) - GPU check"
    local body
    body="$(printf 'No hardware GPU driver detected.\n\nVulkan only reports a software renderer:\n  %s\n\nBattlefront II needs a real GPU. The game will crash a few seconds after launch with CreateTexture2D E_INVALIDARG.\n\nIf you are in a virtual machine, you need GPU passthrough.\n\nOn bare metal, install the Vulkan driver for your card:\n\n%s\n\nYou can still launch the game from here, but expect it to crash.' \
        "$gpus" "$distro_hint")"

    if command -v zenity >/dev/null 2>&1; then
        LC_ALL=C.UTF-8 LANGUAGE=en zenity --warning --no-wrap --title="$title" --text="$body" 2>/dev/null || true
    else
        LC_ALL=C.UTF-8 LANGUAGE=en kdialog --title "$title" --sorry "$body" 2>/dev/null || true
    fi

    mkdir -p "$state_dir"
    printf '%s' "$current_hash" > "$marker"
    return 0
}

_kyber_vulkan_precheck_main || true
unset -f _kyber_vulkan_precheck_main
