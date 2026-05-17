# Kyber Linux Port (inofficial)

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

[v0.1.0-beta.2](https://github.com/simonlinuxcraft/kyber-linuxport-inofficial/releases/tag/v0.1.0-beta.2)
from 2026-05-09. Grab
[`KyberLinuxPort-x86_64.AppImage`](https://github.com/simonlinuxcraft/kyber-linuxport-inofficial/releases/download/v0.1.0-beta.2/KyberLinuxPort-x86_64.AppImage)
(231 MB).

Highlights since beta.1: BF2 entitlement error on non-English locales is
fixed, cold start dropped from around 87 s to 22 s, AppImage boots on
Fedora-atomic distros without needing libfuse2.

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

## Build

Flutter (master channel), Rust stable, GTK 3 dev packages, patchelf,
librsvg dev tooling.

```bash
git clone --recurse-submodules https://github.com/simonlinuxcraft/kyber-linuxport-inofficial.git
cd kyber-linuxport-inofficial/Kyber/Launcher
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
