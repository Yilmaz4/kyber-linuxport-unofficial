# Kyber Linux Port (inofficial)

Inofficial Linux build of the [Kyber](https://kyber.gg) mod launcher for
*Star Wars: Battlefront II* (2017). Source-built from upstream
[ArmchairDevelopers/Kyber](https://github.com/ArmchairDevelopers/Kyber)
and [ArmchairDevelopers/Maxima](https://github.com/ArmchairDevelopers/Maxima),
packaged as a self-installing AppImage.

> **Inofficial / community port.** This project is **not** developed,
> endorsed, or supported by the [Kyber team](https://kyber.gg),
> ArmchairDevelopers, EA, Lucasfilm, or Disney. If you are on Windows
> please use the [official Kyber launcher](https://kyber.gg) — this
> repository only exists because the upstream launcher does not ship a
> Linux build. **Use at your own risk.** Bugs in this Linux port should
> be reported here, not to the upstream Kyber team.

---

> **Latest pre-release** &nbsp;·&nbsp; [`v0.1.0-beta.2` — Locale Lock + Cold-Start + Bazzite/Fedora compat](https://github.com/simonlinuxcraft/kyber-linuxport-inofficial/releases/tag/v0.1.0-beta.2) &nbsp;·&nbsp; 2026-05-09
>
> AppImage download: [`KyberLinuxPort-x86_64.AppImage`](https://github.com/simonlinuxcraft/kyber-linuxport-inofficial/releases/download/v0.1.0-beta.2/KyberLinuxPort-x86_64.AppImage) &nbsp;·&nbsp; 231 MB
>
> What's new since beta.1: BF2 "language not entitled" entitlement error fixed for non-English host locales, cold-start launch time down from ~87 s to ~22 s, AppImage now boots out-of-the-box on Bazzite / Fedora-atomic / Silverblue / Kinoite (no `libfuse2`-install thanks to the embedded type-2 runtime), launcher window comes back to the foreground after BF2 exits.
>
> See the [release notes](https://github.com/simonlinuxcraft/kyber-linuxport-inofficial/releases/tag/v0.1.0-beta.2) for the full per-component change list, known limitations, and the install steps.

---

## Status

Pre-release / private testing. The launcher boots, logs into Maxima via
FFI, browses servers, downloads mods, and launches BF2 through an
existing Wine prefix (Lutris / Steam-Proton / umu). The AppImage
self-registers desktop integration on first start.

See `CHANGELOG.md` for the per-release patch list.

## Repository layout

This repository is the **build / packaging layer**. The actual launcher
and CLI source live in two submodules:

```
kyber-linuxport-inofficial/
├── Kyber/                       → submodule: simonlinuxcraft/kyber @ ver/beta10
│   ├── Launcher/                  Flutter UI + Rust FFI
│   ├── CLI/                       kyber_cli (game-launch subprocess)
│   └── ThirdParty/Maxima/         submodule: simonlinuxcraft/Maxima @ linux-port-launcher
│
├── tools/                       AppImage build pipeline
│   ├── build-appimage.sh          flutter bundle → AppImage
│   ├── kyber-self-install.sh      AppRun hook (first-start desktop integration)
│   ├── install-appimage.sh        manual fallback installer
│   └── uninstall-appimage.sh
│
├── LICENSE                      GPLv3 (verbatim)
├── NOTICE.md                    third-party / vendored components
├── CHANGELOG.md                 per-release patch list
└── THIRD_PARTY_TOOLS.md         linuxdeploy / appimagetool provenance
```

Top-level directory is **not** itself an upstream Kyber/Maxima fork —
those are the two submodules.

## Installation (end users)

The AppImage is statically self-contained as far as the AppImage
runtime is concerned — no `libfuse2` install needed since beta.2,
which embeds the [type-2 runtime](https://github.com/AppImage/type2-runtime)
(probes FUSE3, falls back to FUSE2, auto-degrades to
`--appimage-extract-and-run` when neither is available). Tested
clean-boot on Ubuntu 22.04+ / Fedora 39+ / Bazzite / Silverblue /
Kinoite / Arch / openSUSE Tumbleweed. Kernel ≥ 4.x is the only hard
requirement.

### 1. Install runtime prerequisites

Only the self-install dialog needs anything beyond a baseline desktop
install — it uses **zenity** or **kdialog** for the first-start
confirmation, and optionally **notify-send** for a post-install
notification. Skip this step if you are happy to install Kyber
manually with `tools/install-appimage.sh` or you already have a
zenity / kdialog / libnotify package on your system.

| Distro | Command |
|---|---|
| **Ubuntu / Debian / Mint / Pop!_OS** | `sudo apt install zenity libnotify-bin` |
| **Fedora / RHEL / Nobara** | `sudo dnf install zenity libnotify` |
| **Arch / Manjaro / EndeavourOS** | `sudo pacman -S zenity libnotify` |
| **openSUSE Tumbleweed / Leap** | `sudo zypper install zenity libnotify-tools` |
| **Bazzite / Silverblue / Kinoite** | already provides zenity + libnotify in the base image; nothing to install |

Battlefront II itself must already be installed in a Wine prefix —
the launcher does not bootstrap Wine. **Lutris** is the tested path
(`lutris -i kyber-setup.yml`); **Steam-Proton** and **Bottles** also
work but are less tested.

#### Storage placement caveats

Two filesystem-level rules that catch most "AppImage won't start" reports:

- Place the AppImage on a Linux-native filesystem (ext4 / btrfs / xfs / f2fs).
  NTFS and exFAT mounts are typically `noexec` by default, which the
  kernel enforces at `execve()` regardless of the file mode bits.
- On systems where `/tmp` is a `tmpfs` smaller than ~2 GB the
  extract-and-run fallback (used when FUSE is unavailable) can run out
  of space. Workaround: `TMPDIR=$HOME/.cache/kyber-tmp ./AppImage`.

### 2. Download and run

```bash
mkdir -p ~/Applications
mv ~/Downloads/KyberLinuxPort-x86_64.AppImage ~/Applications/
chmod +x ~/Applications/KyberLinuxPort-x86_64.AppImage
~/Applications/KyberLinuxPort-x86_64.AppImage
```

On first start a zenity dialog asks whether to register Kyber as a
desktop application. On confirm, the AppRun hook installs icons in all
hicolor sizes, writes `.desktop` entries for the launcher and the qrc://
/ nxm:// URL handlers, and refreshes the desktop / icon caches.

### 3. Updating

Replace the AppImage in `~/Applications/` with the new release file
(same name). Next start re-registers desktop integration silently
(silent because version-update, no dialog).

### 4. Uninstalling

Run `tools/uninstall-appimage.sh` from the source tree, or remove
manually:

```bash
rm -rf ~/Applications/KyberLinuxPort-x86_64.AppImage \
       ~/Applications/KyberLinuxPort.extracted \
       ~/.local/share/applications/kyber-linuxport*.desktop \
       ~/.local/share/icons/hicolor/*/apps/kyber-linux.* \
       ~/.local/share/kyber-linuxport \
       ~/.local/share/kyber \
       ~/.local/share/com.example.kyber_launcher \
       ~/.config/com.example.kyber_launcher
update-desktop-database ~/.local/share/applications
gtk-update-icon-cache -f ~/.local/share/icons/hicolor
```

The Wine prefix in `~/.local/share/maxima/` is intentionally left in
place — it holds your BF2 install + save data.

## Building from source

Requires Flutter master, Rust stable, system GTK 3 / pixbuf / rsvg
development packages, plus `patchelf` (used by `tools/build-appimage.sh`
to fix Flutter's RUNPATH after linuxdeploy).

### Build dependencies

| Distro | Command |
|---|---|
| **Ubuntu / Debian / Mint** | `sudo apt install git curl unzip cmake clang ninja-build pkg-config patchelf libgtk-3-dev libglib2.0-dev libpango1.0-dev librsvg2-bin librsvg2-dev libxml2-dev` |
| **Fedora / RHEL / Nobara** | `sudo dnf install git curl unzip cmake clang ninja-build pkgconf-pkg-config patchelf gtk3-devel glib2-devel pango-devel librsvg2-tools librsvg2-devel libxml2-devel` |
| **Arch / Manjaro** | `sudo pacman -S git curl unzip cmake clang ninja pkg-config patchelf gtk3 glib2 pango librsvg libxml2` |
| **openSUSE Tumbleweed** | `sudo zypper install git curl unzip cmake clang ninja pkg-config patchelf gtk3-devel glib2-devel pango-devel librsvg-devel libxml2-devel` |

Plus toolchains:
- **Flutter** master channel — see <https://flutter.dev/docs/get-started/install/linux>
- **Rust** stable — `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh`

### Build

```bash
git clone --recurse-submodules https://github.com/simonlinuxcraft/kyber-linuxport-inofficial.git
cd kyber-linuxport-inofficial/Kyber/Launcher
flutter build linux --release
cd ../..
tools/build-appimage.sh
# → tools/KyberLinuxPort-x86_64.AppImage
```

The first `flutter build linux --release` after a clone takes 5–10 min
(cargo-fetch + Rust compile + Flutter bundle). Subsequent builds reuse
caches and finish in ~30 s. The AppImage step itself takes ~1 min.

## License

GPLv3 — see [`LICENSE`](LICENSE).

This is a derivative work of the upstream Kyber and Maxima codebases
(both GPLv3). All Linux-port modifications are also released under
GPLv3-only.

### Corresponding Source (GPLv3 §6)

For binary distributions of this AppImage, the corresponding source is
this repository at the commit / tag identified in the GitHub Release
that ships the binary. The binary embeds a `source-url.txt` pointing
back here.

For the bundled `wine-helper.exe` (vendored in
`Kyber/CLI/cli_payload/`), the corresponding source is the upstream
ACowAdonis tarball — see `Kyber/CLI/cli_payload/README.md` for the
GPLv3 §6(b) written offer.

### Third-party / vendored components

See [`NOTICE.md`](NOTICE.md) for the full list of third-party code,
fonts, and binaries bundled into the AppImage, with their licenses and
provenance.

## Contributing / Reporting issues

This is a small one-maintainer effort. Bug reports for the **Linux
port specifically** are welcome via GitHub Issues on this repository.

Please **do not** report Linux-port issues to the upstream Kyber team
or the Kyber Discord — they are not responsible for this port. If you
are unsure whether a bug is Linux-specific, file it here first; if it
turns out to reproduce on Windows too, I will point you at the
upstream tracker.
