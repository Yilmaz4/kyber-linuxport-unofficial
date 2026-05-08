# Changelog

All notable changes to the Kyber Linux Port are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning tracks upstream Kyber, with port-specific patches noted separately.

## [Unreleased]

### Added
- `CHANGELOG.md` (this file) as the central change history for the Linux port.
- **Self-installing AppImage** — first-run desktop integration without a
  separate install script. The AppRun now sources a new
  `apprun-hooks/kyber-self-install.sh` before `linuxdeploy-plugin-gtk.sh`
  (so dialog tools load the system GTK, not the bundled one). On first
  start it asks via zenity/kdialog whether to register Kyber as an
  application and, on confirm, copies the AppImage to `~/Applications/`,
  extracts a stable copy for the qrc:// and nxm:// URL handlers, installs
  the hicolor icon set, writes the three `.desktop` entries, refreshes
  the desktop and icon caches, and registers the MIME handlers — all
  under `$HOME`, no sudo. A marker file at
  `~/.local/share/kyber-linuxport/.installed-version` (size+mtime of the
  AppImage) makes subsequent starts a fast no-op; on version updates the
  hook silently re-installs. A separate `.declined-version` marker
  remembers a "no" choice for the same AppImage so the dialog doesn't
  reappear on every launch. Set `KYBER_NO_AUTO_INSTALL=1` to skip the
  hook (CI / packaging contexts). `tools/install-appimage.sh` is still
  shipped as the manual fallback for headless or restricted setups.

### Changed
- SPDX license identifiers in self-authored files consolidated to
  `GPL-3.0-only` (previously inconsistent: `GPL-3.0-or-later` / `GPL-3.0`).
  Vendored cli_payload scripts retain their upstream `GPL-3.0-or-later`
  headers (the headers reflect the original ACowAdonis tarball license);
  the aggregate work is conveyed under `GPL-3.0-only`, which is a permitted
  choice within an `or-later` upstream.
- `NOTICE.md`: explicit aggregation-license clause and statement of
  the vendored-file header policy.
- Replaced proprietary fonts:
  - **Univers Next Pro Medium Condensed** (Linotype/Monotype, all rights
    reserved) → **Barlow Condensed Medium / MediumItalic** (SIL OFL 1.1,
    https://github.com/jpt/barlow). The `BattlefrontUI` family name in
    `pubspec.yaml` is retained, so no Dart code change was required.
  - **Aurebesh** by Pixel Sagas Foundry (proprietary "all rights reserved")
    → **Aurebesh Rodian** by AurekFonts (MIT,
    https://github.com/AurekFonts/Aurebesh_Rodian).
  - License files (`Barlow-OFL.txt`, `AurebeshRodian-LICENSE.txt`) are
    bundled alongside the font files as required by OFL §1 and MIT.

### Fixed
- Kyber-Module debug-console window ("`KYBER (2.0.0-beta8)`") opening on
  every game launch on Linux. Fix: the launcher now sets
  `KYBER_HIDE_CONSOLE=1` in the env map of the `kyber_cli` subprocess
  (`maxima_helper.dart`). Logs continue to be written to `kyber.log` —
  only the on-screen console is suppressed, matching the Windows GUI
  default.
- Console-window suppression made effective: empirical verification via
  `/proc/<bf2-pid>/environ` showed that the BF2 process inside the
  pressure-vessel container does NOT inherit Linux-side env vars (Dart
  `Process.start` environment, kyber_cli env, umu-wrapper `export` — none
  reach BF2). Workaround: `umu-wrapper.sh` now writes
  `KYBER_HIDE_CONSOLE=1` into the Wine registry under `HKCU\Environment`
  immediately before launching BF2. Wine seeds the Win32 PEB env from
  this registry key at process start, so Kyber.dll's `std::getenv` check
  in `Program.cpp:139` finally sees the variable.
- `wine.rs::run_wine_command` (in both Maxima submodules,
  `Kyber/ThirdParty/Maxima/` and `Kyber/CLI/ThirdParty/Maxima/`):
  detached stdin (`Stdio::null()`) and silenced stderr / stdout for
  silent invocations, so Wine no longer pops up a `wineconsole` for
  console-subsystem helpers like `wine-helper.exe`.
- **Mod download leading-slash bug on Linux** — every mod download
  failed with `PathNotFoundException: Cannot open file, path =
  'home/<user>/.local/share/kyber/mods/<mod>.zip.download'` (note the
  missing leading `/`). `download_orchestrator.dart:219-220` was
  prepending `/` to the absolute base path only on macOS to compensate
  for the `background_downloader` plugin stripping the leading slash
  when `BaseDirectory.root` is used; the same compensation is required
  on Linux. Fix: extend the conditional to
  `Platform.isMacOS || Platform.isLinux`. Windows, which uses drive-letter
  absolute paths (`C:\...`), continues to need no prefix.

### Compliance
- GPLv3 pre-release audit completed (mandatory items A1–A5 plus B1–B7).
- `linux_self_update_service.dart`: SPDX header added.
- `Launcher/rust/Cargo.toml` and `CLI/rust/Cargo.toml`: `license` field
  added.
- About dialog: `applicationLegalese` updated; a Kyber Linux Port entry
  registered via `LicenseRegistry.addLicense()`; source URL linked in
  About.
- `wine-helper.exe`: §6(b) written-offer documented in
  `Kyber/CLI/cli_payload/README.md` (request via GitHub Issues).
- Maxima submodule patches committed on `linux-port-patches` branches in
  both submodule trees, with `CHANGES.md` carrying the §5(a) modification
  notice.

### AppImage pipeline (initial distribution)
- `tools/install-appimage.sh` companion script: removes stale .desktop
  entries / icons from previous source-build and `.deb` installs, copies
  the AppImage to `~/Applications/`, extracts a static copy for stable URL
  handlers, writes three `.desktop` files (main launcher + qrc handler
  for EA login redirects + nxm handler for Nexus Mods downloads), refreshes
  the desktop and icon caches, and registers the qrc/nxm scheme defaults.
  Idempotent. Wine prefix at `~/.local/share/maxima/` is left untouched.
  `tools/uninstall-appimage.sh` reverses everything except the prefix.
- `tools/build-appimage.sh` recipe: assembles the AppDir from the Flutter
  release bundle, embeds the GPL `LICENSE`, `NOTICE.md`, `CHANGELOG.md`
  and a `usr/share/doc/kyber-bf2/source-url.txt` (GPLv3 §6(d)).
- Bundled `libpixbufloader-svg.so` + `librsvg-2.so.2` + `libxml2.so.2`
  manually because `linuxdeploy-plugin-gtk` skips them (they bring in
  large extra deps). Without the SVG loader GTK crashes on first attempt
  to render `image-missing.svg` from the system icon theme. The
  `loaders.cache` is regenerated post-copy with paths relative to
  `AppDir`.
- Post-linuxdeploy `patchelf --set-rpath '$ORIGIN/lib'` step on
  `usr/bin/kyber_launcher`: linuxdeploy rewrites the Flutter binary's
  RUNPATH to `$ORIGIN/../lib`, which breaks dynamic loading of bundle-local
  Flutter plugins (rhttp, media_kit, etc.) that the Dart side opens via
  `DynamicLibrary.open('libfoo.so')` by bare filename. Restoring
  `$ORIGIN/lib` keeps the Flutter convention while still letting the GTK
  system deps in `usr/lib/` resolve via the GTK libs' own NEEDED entries.
- Source tarball (`git archive --recurse-submodules`) attached as a
  release asset alongside the AppImage.

---

[Unreleased]: https://github.com/simonlinuxcraft/kyber-linuxport-inofficial/compare/HEAD...HEAD
