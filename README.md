# Kyber Linux Port (unofficial)

Unofficial Linux build of the [Kyber](https://kyber.gg) mod launcher for
Star Wars: Battlefront II (2017). The upstream launcher is Windows only,
so this just packages the existing source from
[ArmchairDevelopers/Kyber](https://github.com/ArmchairDevelopers/Kyber)
and [ArmchairDevelopers/Maxima](https://github.com/ArmchairDevelopers/Maxima)
into an AppImage that runs on Linux.

This is a community fork. Not endorsed by the Kyber team, ArmchairDevelopers,
EA, Lucasfilm, or Disney. If you're on Windows, use the
[official launcher](https://kyber.gg). Bugs in this Linux build go here,
not to upstream Kyber.

## Latest release

The latest build is
[v0.1.0-beta.5.1](https://github.com/simonlinuxcraft/kyber-linuxport-unofficial/releases/tag/v0.1.0-beta.5.1)
from 2026-05-22.

v0.1.0-beta.5.1 is a hotfix on top of beta.5 for three launch problems
found from Discord bug reports: BF2 now injects on the first launch
after a fresh install, the manual game-path override is no longer
ignored, and the EA Desktop language patch reaches the right Wine
prefix. If beta.5.1 is unstable on your machine, beta.5 stays a safe
fallback.

What is new since beta.4: the launcher no longer kills itself when BF2
starts, the every-two-minutes connection drop is gone, the in-game
voice settings no longer crash, and proximity chat can list audio
devices on Linux while you are in a match. There is also a manual
game-path override for installs Steam does not auto-detect, and a
CachyOS hint plus a Vulkan pre-flight check that warn before a launch
that would only crash. The game runs under gamemode when it is
installed, and updates now keep your downloaded mods, plugins and
mod collections.

Older releases are listed in [`CHANGELOG.md`](CHANGELOG.md).

## Heads up

This is a beta and a one-person port, so expect rough edges. The inject
works on the common setups now, but voice chat is not fully proven yet,
Nexus mod downloads can still fail, and some distro or GPU combinations
do not work at all (a VM without GPU passthrough will not run BF2, for
example).

It also assumes a healthy system underneath. A working Steam-Proton or
Lutris install of BF2, a real GPU with proper Vulkan drivers, and a
normal desktop audio stack. The launcher cannot fix a broken Proton
prefix or missing graphics drivers. A well set up system is the
baseline here, not something the AppImage brings along.

## Dependencies

The AppImage bundles most of its libraries but still needs the system
GTK and WebKit stack plus FUSE. A missing one of these is the most
common reason a fresh install misbehaves, so pull them in up front.

Debian, Ubuntu, Mint:

```bash
sudo apt install libwebkit2gtk-4.1-0 libgtk-3-0 libfuse2 librsvg2-2 libnotify4 gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav zenity gamemode
```

Arch, CachyOS:

```bash
sudo pacman -S --needed webkit2gtk-4.1 gtk3 fuse2 librsvg libnotify gst-plugins-bad gst-plugins-ugly gst-libav zenity gamemode
```

Fedora: the equivalent webkit2gtk4.1, gtk3, fuse, librsvg2, libnotify
and gstreamer1 plugin packages.

webkit, gtk3, librsvg, libnotify and fuse are required, the app will
not start cleanly without them. The gstreamer plugins make the EA
login splash video play (silent without them, not fatal). zenity
drives the first-start dialog. gamemode is optional but recommended,
it keeps the CPU governor on performance for smoother frames. libmpv
is bundled inside the AppImage, you do not install it yourself.

## Install

You need BF2 already installed via Steam-Proton (or Lutris). The launcher
doesn't bootstrap Wine itself.

```bash
mkdir -p ~/Applications
mv ~/Downloads/KyberLinuxPort-x86_64.AppImage ~/Applications/
chmod +x ~/Applications/KyberLinuxPort-x86_64.AppImage
~/Applications/KyberLinuxPort-x86_64.AppImage
```

On first start a small zenity dialog asks if you want a desktop entry.
Say yes if you want the launcher in your app menu. Most distros have
zenity preinstalled. If the dialog doesn't show up, install it via your
package manager.

Tested on Ubuntu 24.04 with an Nvidia RTX 3060. Other distros should work
since the AppImage bundles its own runtime, but I haven't verified every
one personally.

## Advanced (optional)

### Custom Proton path

The default flow downloads a known-good GE-Proton into
`~/.local/share/maxima/wine/proton/` and runs BF2 from there. That is the
only tested-stable path and the recommended default for most users.

Advanced users can override the Proton build used for BF2. Settings ->
Mod Configuration -> "Custom Proton Path (Experimental)" opens a dialog
that browses for or scans the standard Steam compatibility-tools folders.
Verified to work in testing: GE-Proton 10.x family, Proton-EM Latest,
proton-cachyos 11.x. Newer builds with Wine 10 + DXVK 2.x can give
noticeably smoother frame times than the bundled default, at the cost of
losing the tested-stable safety net.

Equivalent power-user env var:

```bash
KYBER_PROTON_PATH="$HOME/.steam/steam/compatibilitytools.d/Proton-EM Latest" \
  ~/Applications/KyberLinuxPort-x86_64.AppImage
```

Resolution order is env var first, then a sidecar file at
`~/.local/share/maxima/custom_proton_path` (written by the UI), then the
auto-managed default.

Implementation: when a custom path is active, the launcher transparently
swaps `~/.local/share/maxima/wine/proton` for a symlink to the chosen
build (originals are moved aside to `proton.maxima-backup`). The Wine
prefix itself stays the shared BF2 Steam compat-prefix, so save games and
EA App login survive switching between default and custom. "Reset to
default" in the dialog restores the symlink instantly without re-download.

## Build

Flutter (master channel), Rust stable, GTK 3 dev packages, patchelf,
librsvg dev tooling.

```bash
git clone --recurse-submodules https://github.com/simonlinuxcraft/kyber-linuxport-unofficial.git
cd kyber-linuxport-unofficial/Kyber/Launcher
flutter build linux --release
cd ../..
tools/build-appimage.sh
```

Output ends up in `tools/KyberLinuxPort-x86_64.AppImage`. First build
takes a few minutes (cargo fetch, Rust compile, Flutter bundle).
Subsequent builds are usually around 30 seconds. AppImage packaging
itself adds about a minute.

## License

GPLv3, see [`LICENSE`](LICENSE). This is a derivative work of the
upstream Kyber and Maxima codebases, both GPLv3. Linux-port changes are
GPLv3-only.

For binary distributions, the corresponding source is this repo at the
release tag. The AppImage embeds a `source-url.txt` pointing back here.
The bundled `wine-helper.exe` from ACowAdonis has its own source offer
in `Kyber/CLI/cli_payload/README.md`.

See [`NOTICE.md`](NOTICE.md) for the full list of third-party components
shipped in the AppImage.

## Contributing

Small one-person project. If you hit a Linux-specific bug, open an issue
here. Don't report Linux-specific bugs to the upstream Kyber team, they
didn't write this part. If you're not sure whether something is
Linux-specific, file it here anyway and I'll redirect if it turns out to
be upstream.
