# Third-Party Build Tools

The `tools/` directory carries three helper utilities used **only at
build time** to assemble the AppImage. They are not embedded into or
redistributed inside the produced AppImage.

## linuxdeploy

- **File**: `tools/linuxdeploy-x86_64.AppImage`
- **Project**: <https://github.com/linuxdeploy/linuxdeploy>
- **License**: MIT
- **Used for**: Walking the launcher binary's dependency graph and
  copying needed shared libraries into the AppDir, plus generating the
  default AppRun script (which we then patch with the
  `KYBER_SELF_INSTALL_HOOK` block in `tools/build-appimage.sh`).

## linuxdeploy-plugin-gtk

- **File**: `tools/linuxdeploy-plugin-gtk.sh`
- **Project**: <https://github.com/linuxdeploy/linuxdeploy-plugin-gtk>
- **License**: MIT
- **Used for**: GTK 3 environment setup at AppImage runtime - bundling
  GTK / GDK / pango / glib runtime data and writing the GTK AppRun
  hook. We extend this hook with a runtime
  `gdk-pixbuf-query-loaders`-regen block (see
  `tools/build-appimage.sh` `KYBER_PIXBUF_LOADERS_RUNTIME` sentinel).

## appimagetool

- **File**: `tools/appimagetool-x86_64.AppImage`
- **Project**: <https://github.com/AppImage/appimagetool>
- **License**: MIT
- **Used for**: Final step - squashing the AppDir into the
  `KyberLinuxPort-x86_64.AppImage` runtime + squashfs blob.

## Why bundled instead of fetched at build time

These three tools have their own release cadence and occasional
behaviour drift. Pinning them in-tree gives us reproducible builds
and avoids "build broke because upstream changed" scenarios. License
compatibility (MIT, redistribution allowed) makes this safe.

If you want to refresh them, fetch the latest upstream releases (URLs
above) and replace the files. The build script does not depend on a
specific version.

## Runtime-discovered Compatibility Tools (not bundled)

The optional **Custom Proton Path** feature (Settings -> Mod
Configuration on Linux) lets advanced users point Kyber at a Proton
build of their own choice instead of the default GE-Proton that
Maxima downloads. None of the Proton builds below are bundled, fetched,
or redistributed by this project; the user provides them themselves
(typically already installed via Steam, AUR, or a manual extract under
`~/.steam/steam/compatibilitytools.d/`). The feature is still labelled
**experimental** because each external Proton release ships its own Wine
+ DXVK + VKD3D combination that we do not regression-test against
Battlefront II; the default auto-managed build is the only path covered
by our own QA. Verified working in testing so far: GE-Proton 10.x
family, Proton-EM Latest, proton-cachyos 11.x. Newer Wine + DXVK in
those builds typically delivers smoother frame times than the bundled
default.

| Build | Upstream URL | License |
|---|---|---|
| GE-Proton | <https://github.com/GloriousEggroll/proton-ge-custom> | GPL-3.0-or-later (Proton itself); bundled DLLs (DXVK, VKD3D-Proton, MoltenVK) under their own permissive licenses |
| proton-cachyos | <https://github.com/CachyOS/proton-cachyos> | Same as GE-Proton (downstream fork) |
| Proton-EM (Experimental-Modified) | <https://github.com/Etaash-mathamsetty/Proton-EM> | Same as upstream Proton |
| Valve Stock Proton | <https://github.com/ValveSoftware/Proton> | BSD-3-Clause (Proton wrapper); bundled Wine under LGPL-2.1 |

Power users can also bypass the UI entirely by setting the
`KYBER_PROTON_PATH` environment variable to the absolute path of a
Proton directory before launching the AppImage. Resolution order is
ENV-var first, then sidecar file at
`~/.local/share/maxima/custom_proton_path`, then the default
auto-managed path.
