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
- **Used for**: GTK 3 environment setup at AppImage runtime — bundling
  GTK / GDK / pango / glib runtime data and writing the GTK AppRun
  hook. We extend this hook with a runtime
  `gdk-pixbuf-query-loaders`-regen block (see
  `tools/build-appimage.sh` `KYBER_PIXBUF_LOADERS_RUNTIME` sentinel).

## appimagetool

- **File**: `tools/appimagetool-x86_64.AppImage`
- **Project**: <https://github.com/AppImage/appimagetool>
- **License**: MIT
- **Used for**: Final step — squashing the AppDir into the
  `KyberLinuxPort-x86_64.AppImage` runtime + squashfs blob.

## Why bundled instead of fetched at build time

These three tools have their own release cadence and occasional
behaviour drift. Pinning them in-tree gives us reproducible builds
and avoids "build broke because upstream changed" scenarios. License
compatibility (MIT, redistribution allowed) makes this safe.

If you want to refresh them, fetch the latest upstream releases (URLs
above) and replace the files. The build script does not depend on a
specific version.
