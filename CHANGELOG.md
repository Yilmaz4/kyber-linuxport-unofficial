# Changelog

All notable changes to the Kyber Linux Port are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning tracks upstream Kyber, with port-specific patches noted separately.

## [0.1.0-beta.6.4.1] - 2026-06-06 - Steam Deck Fixes

Follow-up to beta.6.4. The launcher still failed to start on Steam Deck and
SteamOS after the webkit fix, this time with a crypto library mismatch, and
the manual paste login could silently do nothing. Also fixes two Linux-only
auth paths that broke session recovery. Still a test/pre-release; if it
misbehaves, beta.6.3 stays a safe fallback.

### Fixed

- The launcher still crashed on startup on Steam Deck/SteamOS after beta.6.4,
  now with "undefined symbol: nettle_rsa_oaep_sha384_decrypt". The AppImage
  bundled its own gnutls/nettle/hogweed, but an older hogweed than rolling
  distros ship. The system's newer gnutls then bound against the bundled older
  hogweed and aborted before the UI. These crypto libraries are no longer
  bundled, so the whole TLS stack comes from the system as a consistent set.
- The manual sign-in code field could sit on "Submitting sign-in code..."
  forever. The code is delivered to the login flow's local callback, which only
  runs while a login is in progress; pasting with no active login hit a closed
  port and was silently ignored. The field now tells you to start the login
  first instead of appearing to hang.
- Session recovery did nothing on Linux. The "invalid grant" re-login and the
  "expired session" exit button both deleted the stale auth file at a hardcoded
  Windows path, which on Linux pointed nowhere, so the stale token was never
  cleared and the expired-session restart never ran. Both now use the correct
  per-platform path.
- The login could get stuck on the loading spinner if EA returned an "invalid
  grant" while no stored auth file was present; it now surfaces the error
  instead of hanging.
- EA sign-in errors are now shown in plain language with what to do next, and
  the full error text is selectable and scrollable instead of being cut off in
  the dialog.

### Changed

- The "Mod Configuration" settings tile is now labelled "Mods / Proton", since
  the custom Proton path setting lives there and Proton is Linux-specific.

## [0.1.0-beta.6.4] - 2026-06-04 - Steam Deck Support

Makes the launcher start on Steam Deck and SteamOS by dropping the bundled
webkit2gtk dependency, which was unused on Linux but crashed startup on
systems without a system webkit. Also shrinks the AppImage by about 47 MB
and makes the manual paste login easy to find on the Deck. A test/pre-release
hotfix; if it misbehaves, beta.6.3 stays a safe fallback.

### Fixed

- The launcher failed to start on Steam Deck/SteamOS with a "missing
  libwebkit2gtk" error. webkit2gtk (122 MB) was pulled in only by an unused
  webview plugin; the EA login uses the external browser, so webkit is never
  used on Linux. It also looks for helper processes at a hardcoded path that
  does not exist on immutable systems, so the process crashed before the UI.
  The webview plugin is now stubbed out on Linux and webkit is no longer
  bundled.

### Changed

- On Steam Deck/SteamOS the EA login's manual code field is shown expanded by
  default, with a hint, and can be reopened from the error screen if the first
  attempt times out. The Deck's Flatpak browser does not hand the qrc://
  callback back to the launcher, so pasting the code is the reliable path.
- Settings shows the unofficial Linux-port version next to the upstream Kyber
  client version.
- GTK input-method warnings on minimal systems are quieted.
- GDK_BACKEND can be set to wayland for native Wayland (default stays x11).

### Added

- A one-time hint on first launch on SteamOS/Steam Deck pointing at the paste
  login and the Distrobox alternative.

## [0.1.0-beta.6.3] - 2026-06-03 - Login Reliability

Fixes the EA login hanging forever on sandboxed browsers and Steam Deck,
adds a manual code fallback for when the browser callback never arrives,
and makes a silently-failing game launch finally report why it stopped.
If beta.6.3 misbehaves, beta.6.2 stays a safe fallback.

### Fixed

- EA login could hang forever with no feedback. Sign-in opens the system
  browser and waits for EA to hand the auth code back to a local callback
  server. If that callback never arrived, the launcher waited on the socket
  indefinitely and the login spinner never stopped. The wait now times out
  after 5 minutes with a clear error that names the workaround, and the
  local callback port is released so the next attempt can rebind it.

- The qrc:// login handler went stale after the first launch on installed
  AppImages. The launcher re-registered the handler on every start at the
  AppImage's temporary mount path, which changes each run, overwriting the
  stable handler the installer had set up. From the second launch on, the
  handler pointed at a dead path and the EA login callback silently failed.
  Packaged builds now keep the installer's stable handler instead of
  re-pointing it at the mount.

- A game launch that exited immediately logged only "Game stopped" with no
  reason, which made the recent "launches but nothing happens" reports
  impossible to diagnose. The launcher now logs the launch helper's exit
  status, so the log shows whether umu/Proton failed to start or the game
  itself exited right away.

- Two harmless exceptions were thrown on every Linux start and sent to crash
  tracking: a MissingPluginException from the protocol-handler plugin (which
  has no Linux backend; nxm:// links are handled by a separate watcher) and
  a gRPC "Invalid token" error from a module-version check that ran before
  login. Both are now guarded, so they no longer clutter the log or crash
  reports.

### Added

- Manual code entry for EA login. EA redirects the signed-in browser to a
  qrc:// link that the system is supposed to hand back to the launcher. A
  sandboxed browser (the default Flatpak build of Zen, for example, and most
  Steam Deck setups) routes that link through the desktop portal, which does
  not deliver an unregistered scheme like qrc:// to a host application, so
  the launcher never got the code. When the automatic callback does not
  arrive, the login screen now offers a field to paste the sign-in link or
  code straight from the browser. It is fed to the same local callback, so
  login completes without depending on the browser handing the link back. A
  native (non-sandboxed) default browser, or signing in to the EA app first,
  still works automatically.

## [0.1.0-beta.6.2] - 2026-05-27 - Custom Steam Path Detection

A hotfix on top of beta.6.1 for users whose Steam library lives outside
the default locations. If beta.6.2 misbehaves, beta.6.1 stays a safe
fallback.

### Fixed

- BF2 launches were silently broken on systems where Steam is installed
  in a non-standard path (for example `~/Games/Steam` instead of
  `~/.steam/steam`, `~/.local/share/Steam`, or `/mnt/Games/SteamLibrary`).
  The compatdata symlink setup probed a hardcoded list of library roots
  and missed those installs, even though Steam itself had BF2 registered
  via `libraryfolders.vdf`. Maxima's wine prefix then pointed at an empty
  directory and the launch hung with no UI feedback. Detection now reuses
  the same `libraryfolders.vdf` resolver that already finds the BF2
  install directory, and derives the compatdata path arithmetically from
  there. The hardcoded list stays as a fallback for environments where
  the vdf chain is missing. Users who set `STEAM_LIBRARY_ROOT` as a
  workaround on earlier releases can unset it.

## [0.1.0-beta.6.1] - 2026-05-25 - Wineserver Hotfix

A hotfix on top of beta.6 for one problem around switching Proton
versions, found from CachyOS bug reports on the day of the release.
If beta.6.1 is unstable on your machine, beta.6 stays a safe fallback.

### Fixed

- Switching Proton via Settings > Mod Configuration could silently leave
  BF2 unable to launch when a wineserver from the previous BF2 session
  was still attached to the Maxima prefix. The stale wineserver and the
  newly-routed Wine binary then fought over the prefix and the next
  launch hung with no UI feedback. The dialog now detects this case
  before writing the sidecar, shows a "Wineserver still running"
  confirmation, and offers a "Kill wineserver and retry" action. The
  kill is prefix-scoped, so wineservers belonging to other Wine games
  are never touched. No-op Save with the same Proton path is never
  blocked.

## [0.1.0-beta.6] - 2026-05-25 - Custom Proton Support

Adds an experimental custom Proton path option and automatic shader cache
invalidation when switching Proton versions. If beta.6 is unstable on your
machine, beta.5.1 stays a safe fallback.

### Added

- Custom Proton path setting under Settings > Mod Configuration. Point the
  launcher at any Proton build (GE-Proton, Proton-EM, proton-cachyos, etc.)
  instead of the bundled GE-Proton. Routing goes through a wine/proton symlink
  so save games and EA App login stay shared across Proton versions. The setting
  carries a visible warning that it leaves the tested-stable path. Verified
  working with GE-Proton 10.x, Proton-EM Latest, and proton-cachyos 11.x.
- Shader cache invalidation on Proton switch. BF2's vkd3d-proton.cache is
  cleared automatically when the active Proton version changes, preventing the
  yellow-stripe and shadow-flicker artifacts that appear when an old cache built
  against a different Wine/DXVK pipeline is reused. A manual "Clear shader
  cache" button in the Custom Proton dialog is also available.

## [0.1.0-beta.5.1] - 2026-05-22 - Launch Hotfix

A hotfix on top of beta.5 for three problems around starting BF2,
found from Discord bug reports. If beta.5.1 is unstable on your
machine, beta.5 stays a safe fallback.

### Fixed

- BF2 failed to inject on the first launch after a fresh install. The
  vivoxsdk.dll link into the Wine prefix was created before the prefix
  existed, so the first injection failed with Wine loader error 126.
  The link is now also placed right before injecting, when the prefix
  is guaranteed to exist. The second launch always worked; now the
  first one does too.
- The manual game-path override from beta.5 was ignored at launch.
  Install checks in the launcher and in Maxima still ran and rejected
  a hand-set BF2 path as not installed. Both are now skipped when an
  explicit path is set.
- The EA Desktop language patch never applied on a Maxima-managed Wine
  prefix. It looked under prefix/pfx/drive_c while the real location is
  prefix/drive_c, so on non-English hosts BF2 could still raise the
  Origin language-entitlement error.

## [0.1.0-beta.5] - 2026-05-22 - Stability and Voice

Fixes from the days after beta.4, mostly off CachyOS bug reports on
Discord.

### Fixed

- Starting BF2 could kill the launcher itself. When the game PID
  could not be resolved the launcher ran `killPid(0)`, which signals
  its own process group. Guarded now, and it routes to the recovery
  dialog instead.
- Connection drops. A 2-minute refresh timer checked the wrong thing
  and dropped a live session to Normal every two minutes. Also a
  DLL-connect grace window, stale-instance cleanup when gRPC goes
  unavailable, and a server-select race guard.
- Voice settings crashed in-game. The push-to-talk key could hold a
  value too large for a 32-bit field, which threw on every tick and
  flooded the log. The key is clamped now and unsupported keys are
  rejected in the picker.
- Proximity chat showed "no devices found" on Linux. The device list
  is pulled from the running game now, so input and output devices
  can be picked while in a match.

### Added

- Manual game-path override for BF2 installs that Steam
  auto-detection misses. In Settings and in the game-not-found
  dialog.
- CachyOS startup hint and a Vulkan pre-flight check, bundled as
  AppRun hooks. Warns when the system only has software rendering
  (llvmpipe) before the game launches into a crash.
- The game runs under feral gamemode when `gamemoderun` is on PATH,
  so the CPU governor stays on performance for the match. Wraps only
  the game launch, not the launcher. `KYBER_DISABLE_GAMEMODE=1` opts
  out.

### Changed

- Maxima: `KYBER_DISABLE_WINEGSTREAMER` is opt-in now, and wine
  stderr is captured on failure so bug reports carry more.
- The installer keeps downloaded mods, plugins and mod collections
  across an update now. cli/, locale/ and module/ still get
  refreshed, mods/ and launcher/ are left alone.

## [0.1.0-beta.4] - 2026-05-18 - Inject Path Fixed

Two inject bugs that aderius tracked down on Discord, both fixed now.

### Fixed

- wine-helper now runs through host wine64 directly. The old D-Bus
  container routing in `umu-wrapper.sh` only matched hex AppIDs, but
  BF2 is decimal 1237950, so it never worked. Diagnosed by aderius.
- `vivoxsdk.dll` gets symlinked into Wine's `system32` before each
  launch. Without it, Wine couldn't resolve `Kyber.dll`'s static
  import and the inject failed with OS error 126. Diagnosed by aderius.

### Added

- Recovery dialog when the inject fails. Was a silent notification
  before. Now you get Retry and "Use CLI Launch" buttons, plus the
  raw error to copy for bug reports. BF2 is killed cleanly before
  the retry.
- `--playmode` flag on the AppImage. Skips the launcher and starts
  BF2 directly through Steam. Last resort if nothing else works.

### Changed

- First-start dialog is English everywhere now (German systems were
  getting "Ja/Nein" against an English prompt).
- Self-install no longer re-extracts the AppImage on every launch.
  A marker inside the extract dir plus `cp -p` for mtime preserve
  keeps things in sync.
- `notify-send` fires before and after the extract so the launcher
  doesn't look frozen during that step.
- Icon isn't stretched anymore. The Kyber SVG is 166x144, the build
  script used to force it into a square box.

### Internal

- `umu-wrapper.sh` checks `wine64` exists before exec.
- `kyber-self-install.sh` guards its `--appimage-extract` call against
  recursive triggering on FUSE3-only distros.
- CLI fallback (`startGameViaCli`) is now public, only invoked from
  the recovery dialog. The CLI path doesn't run the full locale lock,
  so BF2's Origin language dialog can still show up there.


## [0.1.0-beta.3] - 2026-05-17 - Fresh-Prefix BF2 Detection Fix

Quick follow-up release because CachyOS testers (and anyone with a
fresh-out-of-the-box Steam-Proton install) were hitting a "GAME NOT
FOUND" dialog even though BF2 was clearly installed and the Proton
prefix was sitting right there.

### Fixed

- Launcher now writes the `Software\EA Games\STAR WARS Battlefront II`
  Wine registry section itself on every game launch, instead of relying
  on the EA installer having run at some point. On Linux, Steam-Proton
  never runs the EA installer, so on a clean prefix that registry key
  simply does not exist, and Maxima's `is_installed()` check fails. The
  install directory is resolved from Steam's library metadata
  (`read_game_path("bf2")`), formatted as a Wine `Z:`-path, and written
  to both the regular and `WoW6432Node` versions of the key. Behaviour
  for users with an already-existing entry is unchanged.
- A few diagnostic loglines that were silently swallowed now actually
  show up at `WARN` level when the Steam-library lookup can't find BF2
  - useful if your setup needs `STEAM_LIBRARY_ROOT` to point at a
  non-default library path.

### Internal

- README rewritten in a less corporate tone, with the install/build
  sections trimmed down to what actually matters. AI-flavoured comments
  in `linux_setup.rs` and the Maxima registry helpers got cleaned up
  in the same pass.
- Spelling pass: "unofficial" instead of the older "inofficial"
  everywhere in the source tree (README, in-app strings, build scripts).

## [0.1.0-beta.2] - 2026-05-09 - Locale Lock, Cold-Start, Bazzite/Fedora Compat

### Added
- **Steam game-path auto-detection** - `read_game_path()` is now
  implemented for Linux in the bundled Maxima patch set. The previous
  `todo!()` stub caused the launcher's `get_game_dir(slug)` FFI call to
  return an empty string on Linux, blocking any feature that needed the
  installed BF2 directory. The new implementation maps known BF2 slugs
  (`bf2`, `swbf2`, `starwarsbattlefront2`, `STAR WARS Battlefront II`,
  …) to Steam app id `1237950`, walks the Steam library candidates in
  the same order as `linux_setup.rs` (with `STEAM_LIBRARY_ROOT` env
  override and Flatpak Steam added), parses `libraryfolders.vdf` and
  the per-game `appmanifest_<id>.acf` with a small inline regex parser
  (no new Cargo dependency), and returns
  `<library>/steamapps/common/<installdir>/`. macOS keeps a separate
  `todo!()` stub. Inline unit tests cover the slug map and both
  parsers.
- **AppImage container self-update (configurable endpoint)** - new
  `AppImageUpdateService` updates the AppImage file itself, not just
  the in-app module bundle. Runs only when launched from an AppImage
  (`$APPIMAGE` env present) and an update endpoint is configured via
  `KYBER_UPDATE_URL` (no default - Source repo is private, so the
  classic `gh-releases-zsync` flow does not apply yet). Manifest format
  is JSON `{version, download_url, sha256}`. The service downloads to
  `${APPIMAGE}.new.<tag>`, verifies SHA-256, `chmod 0755`, atomic
  renames over the running file, and exec's into it. Version comparison
  uses semver via the existing `version` package - bare string equality
  was insufficient because `PackageInfo.buildNumber` is undefined on
  Linux/AppImage builds and would have either masked legitimate updates
  or triggered them on every boot. `$APPIMAGE` is canonicalised through
  `resolveSymbolicLinksSync()` so the rename hits the real file even
  when the user invokes the AppImage via a symlink. Before exec'ing the
  new binary the service verifies it is executable (`test -x`) - on
  `noexec` mounts (`~/Applications/` on a data partition) chmod sets
  the inode bit but `execve()` still fails, so the running launcher
  aborts the restart and survives instead of leaving the user with no
  process. Original `Platform.executableArguments` are forwarded to the
  new instance so `--server` and protocol-handler invocations
  (`kyber qrc://...`) survive the restart. Wired through
  `injection_container.dart` and called from
  `app_initialization_service.dart` ahead of the existing in-app
  module update check, so a freshly downloaded image hands off to the
  new launcher version on first boot. The legacy
  `LinuxSelfUpdateService` keeps handling in-app module updates and is
  not affected by this change.

### Fixed
- **BF2 "language not entitled" entitlement error** - the layered Wine
  registry locale-lock (`maxima-lib/src/unix/wine.rs`) now writes
  `HKCU\Environment\LANG`/`LC_ALL=en_US.UTF-8`, propagates an explicit
  English locale on the `maxima-bootstrap` spawn (`core/launch.rs`),
  and re-applies the four locale-critical keys
  (`HKCU\Control Panel\International\{Locale,LocaleName,sLanguage}`,
  `HKCU\Software\Valve\Steam\language`) just-in-time before the BF2
  spawn. A new `verify_locale_is_english()` probe queries the live
  registry values via `reg query` so a regression now leaves a paper
  trail in the launcher log instead of being a silent prefix-state
  mystery. Critical-failure entries (BF2 catalog, Origin Games,
  Control Panel\International, Valve\Steam) abort the launch hard
  with a typed error rather than `Ok(())` after a swallowed warning.
  Verified live: all four critical keys read back as English at spawn
  time on a German-locale host (`LANG=de_DE.UTF-8`).

### Performance
- **Verify-first locale skip** - `setup_wine_registry()` and the
  pre-spawn JIT lock now run a four-key `reg query` pre-flight via
  `verify_locale_is_english()` and short-circuit both write paths
  when the prefix is already in the desired English state. On warm
  launches (the common case once a previous launch succeeded) this
  avoids 19 sequential `reg add` calls through umu-run +
  pressure-vessel - measured launch overhead drops from ~73s to ~24s
  (-49s, -67%). Cold launches and tampered prefixes fall through to
  the full write path unchanged. Each individual umu-run call is
  ~3s of pressure-vessel container spawn dominated; the optimisation
  works by removing redundant calls, not by changing how each call
  works.
- **Pre-spawn verify removed** - the four-key `reg query` probe in
  `Kyber/ThirdParty/Maxima/maxima-lib/src/core/launch.rs` (between
  `setup_wine_registry()` and the bootstrap spawn) was a strict
  duplicate of the pre-flight verify already performed at the top of
  `setup_wine_registry()`, with license-fetch / cloud-sync between the
  two not touching the Wine registry. Removing it saves ~14s of
  umu-run round-trips on every game launch (warm and cold). If the
  language-entitlement regression ever returns the recovery path is a
  single-key probe of `HKCU\Software\Valve\Steam\language` (the only
  key Steam itself sometimes rewrites between launches) - see the
  comment block at the spawn site for the recipe.
- **Launcher window refocus on game exit** - `IngameViewCubit.unloadServer()`
  in `lib/features/server_browser/providers/ingame_view_cubit.dart`
  now calls `windowManager.restore() + .show() + .focus()` after the
  LSX stream completes. BF2 takes the foreground when it launches and
  on a typical Linux DE the launcher window stays minimised in the
  task bar after the game exits - the user landed on the desktop
  instead of back in the launcher. Refocusing is gated to Linux and
  Windows; macOS retains its own window-management semantics. Errors
  from `windowManager` are swallowed and logged at warning level so a
  flaky Wayland implementation cannot block the cubit's normal
  cleanup path.

- **Cold-start direct-file registry patch** -
  `Kyber/Launcher/rust/src/linux_setup.rs` now ships
  `patch_wine_registry_for_bf2()` which writes the BF2 locale-critical
  keys (`HKCU\Control Panel\International`, `HKCU\Software\Valve\Steam`,
  `HKCU\Environment`, `HKLM\Software\Electronic Arts\EA Desktop`,
  `HKLM\Software\Origin`, `HKLM\Software\Origin Games\1035052`,
  `HKLM\Software\WoW6432Node\Origin Games\1035052`) directly into the
  Wine prefix's `user.reg` / `system.reg` files via in-place text
  edits. Replaces (or appends) keys, replaces (or appends) entire
  sections - runs in &lt;100 ms vs. the ~45s the equivalent 15
  sequential `reg add` calls through umu-run + pressure-vessel cost
  in `setup_wine_registry()`. Combined with the verify-first skip
  above, a cold launch on an existing Wine prefix drops from ~87s
  to ~13s (-74s, -85%). The patch is invoked from `init_app()` and
  again from `start_game()` (covers the case where the prefix was
  freshly created by the bootstrap between the two calls). It
  detects a running `wineserver` via `pgrep -x wineserver` and
  skips itself when active - Wine serialises the registry on
  shutdown and would otherwise clobber our direct writes. On a
  brand-new Wine prefix where the registry files do not exist yet
  the patch is a no-op and the existing `setup_wine_registry()`
  umu-run path runs full as before; the cold-start regression is
  bounded to the very first launch on a fresh install.

### AppImage pipeline
- **Type-2 runtime for Bazzite / Fedora-atomic / Silverblue / Kinoite
  out-of-the-box support** - `tools/build-appimage.sh` now embeds the
  type-2 runtime from `AppImage/type2-runtime` (commit `3d17002`,
  `tools/type2-runtime-x86_64`, ~944 KB, statically PIE-musl-linked) via
  `appimagetool --runtime-file`. The default `appimagetool` runtime is
  FUSE2-only and silently fails to mount on immutable Fedora-based
  distributions where `libfuse2` is not installable. The type-2 runtime
  probes FUSE3 first, falls back to FUSE2, and auto-degrades to
  `--appimage-extract-and-run` when neither is available. Net effect:
  one AppImage that boots out-of-the-box on Ubuntu (incl. 24.04 with
  AppArmor caveats), Fedora (Workstation + Silverblue + Kinoite + Bazzite),
  Arch + derivatives. The runtime is musl-statically linked so glibc
  version is irrelevant - only kernel ≥ 4.x is required.
  - `xxd` of the built AppImage now shows `AI\x02` at byte offset 8
    (Type-2 magic), and `--appimage-version` reports the type-2 commit
    hash.
  - Build falls back to the bundled FUSE2-default runtime with a clear
    warning when `tools/type2-runtime-x86_64` is missing on a fresh
    checkout.
  - Verified on the maintainer's Ubuntu box via the `APPIMAGE_EXTRACT_AND_RUN=1`
    proxy test that simulates the no-FUSE path.
  - Known limitations (documentation only - no code fix possible):
    `tmpfs` on `/tmp` smaller than 2 GB will refuse the extract-mode
    fallback (workaround: `TMPDIR=$HOME/.cache/kyber-tmp ./AppImage`),
    and AppImages on NTFS / exFAT partitions hit `noexec` mounts
    (workaround: keep on the home filesystem).

### Security
- **Self-update hardening: mandatory SHA-256, path-traversal block,
  atomic lock** - three security-relevant fixes in
  `LinuxSelfUpdateService`:
  - The server's SHA-256 hash is now mandatory; tarballs without an
    advertised hash are rejected instead of being accepted with a
    warning. Combined with the previous behaviour this had been an
    unverified-download path that could chain into the issue below.
  - `_extractTarGz` now validates every archive entry before delegating
    to `extractArchiveToDisk`. Entries whose canonicalised target
    escapes the staging directory (`../../etc/...`) are refused, and
    symbolic links inside the archive are refused outright.
  - The flock acquired in `claim()` switched from
    `FileLock.blockingExclusive` to `FileLock.exclusive` (non-blocking).
    Two concurrent self-updates now fail fast on the second instance
    instead of serialising launcher boots behind an in-progress
    multi-minute download.

## [0.1.0-beta.1] - 2026-05-08 - First Private Beta

First tagged build of the unofficial Kyber Linux Port. Distributed as a
self-installing AppImage to a closed group of testers; not for general
release. Source for this tag is GPLv3 - see `LICENSE`.

### Added
- `CHANGELOG.md` (this file) as the central change history for the Linux port.
- **Self-installing AppImage** - first-run desktop integration without a
  separate install script. The AppRun now sources a new
  `apprun-hooks/kyber-self-install.sh` before `linuxdeploy-plugin-gtk.sh`
  (so dialog tools load the system GTK, not the bundled one). On first
  start it asks via zenity/kdialog whether to register Kyber as an
  application and, on confirm, copies the AppImage to `~/Applications/`,
  extracts a stable copy for the qrc:// and nxm:// URL handlers, installs
  the hicolor icon set, writes the three `.desktop` entries, refreshes
  the desktop and icon caches, and registers the MIME handlers - all
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
  (`maxima_helper.dart`). Logs continue to be written to `kyber.log` -
  only the on-screen console is suppressed, matching the Windows GUI
  default.
- Console-window suppression made effective: empirical verification via
  `/proc/<bf2-pid>/environ` showed that the BF2 process inside the
  pressure-vessel container does NOT inherit Linux-side env vars (Dart
  `Process.start` environment, kyber_cli env, umu-wrapper `export` - none
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
- **Mod download leading-slash bug on Linux** - every mod download
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
- GPLv3 pre-release audit completed (mandatory items A1-A5 plus B1-B7).
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

[0.1.0-beta.6]: https://github.com/simonlinuxcraft/kyber-linuxport-unofficial/compare/v0.1.0-beta.5.1...v0.1.0-beta.6
[0.1.0-beta.5.1]: https://github.com/simonlinuxcraft/kyber-linuxport-unofficial/compare/v0.1.0-beta.5...v0.1.0-beta.5.1
[0.1.0-beta.5]: https://github.com/simonlinuxcraft/kyber-linuxport-unofficial/compare/v0.1.0-beta.4...v0.1.0-beta.5
