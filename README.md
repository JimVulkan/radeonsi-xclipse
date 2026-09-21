# RadeonSI for Samsung Xclipse

A port of Mesa's RadeonSI OpenGL driver to Samsung Xclipse GPUs on Android, based on Mesa 26.2.3.
It provides desktop OpenGL 4.6 and OpenGL ES through EGL. The Xclipse 920 (Exynos 2200) is
supported.

## Requirements

Tools:

| Tool | Version | Notes |
|---|---|---|
| Android NDK | r29 tested | the API 34 aarch64 compiler and `llvm-strip` |
| Meson | 1.4.0 or newer | |
| Ninja | any recent | |
| Python | 3.10 or newer | with `mako` (0.8.0 or newer) and `packaging` |
| flex and bison | any recent | on Windows, `win_flex` and `win_bison` from winflexbison work too |

```sh
pip install mako packaging
```

Dependencies are fetched by Meson on the first configure, so that step needs network access:

| Library | Version | Use |
|---|---|---|
| libdrm | 2.4.133 | linked statically, with the two patches in `subprojects/packagefiles/` |
| zlib | 1.3.1 | linked statically |
| Expat | 2.5.0 | required by the configure step, not linked into the libraries |

No Android platform libraries are needed: the build uses Mesa's Android stubs.

## Building

```sh
./build.sh /path/to/android-ndk      # Linux, macOS
build.cmd C:\path\to\android-ndk     # Windows
```

The NDK path can also come from `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT`. The build goes to
`build-android/` (set `BUILD_DIR` to change it). The script builds `libEGL_mesa.so`,
`libGLESv2_mesa.so` and `libgallium_dri.so` (RadeonSI, Zink and softpipe), strips them, and writes
a zip with them and `NOTICE.txt` to `dist/`.

`tools/glprobe/` has a small program that checks the libraries from `adb shell`.

## Compatibility

Currently, the driver works only on the Xclipse 920. Other models are not compatible for now.

## Runtime switches

| Property | Environment | Effect |
|---|---|---|
|-----| `MESA_LOADER_DRIVER_OVERRIDE` | `radeonsi` selects this driver |
| `debug.mesa_xclipse_present_probe` | `MESA_XCLIPSE_PRESENT_PROBE` | `n` logs what every n-th presented frame contains |
| `debug.mesa_xclipse_hnd_dump` |-----| `1` logs each window buffer's gralloc handle |

## Disclaimer

This project was developed with heavy use of AI tools. Every change is built and tested on a
Galaxy S22 Ultra (SM-S908B, Xclipse 920) before it is published.

## License

The Xclipse changes are MIT licensed (`LICENSE`). Files from Mesa keep the license in their
headers, mostly MIT; `THIRD_PARTY_NOTICES.md` lists the files under other licenses and `LICENSES/`
has the full texts. The notices for everything compiled into the libraries ship in the package as
`NOTICE.txt`.

This project is not affiliated with or endorsed by Samsung, AMD or the Mesa project. Samsung,
Exynos and Xclipse are trademarks of Samsung Electronics. AMD and Radeon are trademarks of Advanced
Micro Devices.
