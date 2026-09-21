#!/bin/sh
# Build RadeonSI (with Zink and softpipe) and EGL/OpenGL ES for Android (arm64, API 34), and
# package the libraries into dist/.
#
# usage: ./build.sh [path-to-android-ndk]
#   The NDK can also come from ANDROID_NDK_HOME or ANDROID_NDK_ROOT.
#   BUILD_DIR overrides the build directory (default: build-android).
#   GALLIUM_DRIVERS overrides the drivers (default: radeonsi,zink,softpipe).
# Requires: meson, ninja, python3 (mako, packaging), flex, bison, and the NDK's llvm-strip.
set -eu

cd "$(dirname "$0")"

NDK="${1:-${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}}"
if [ -z "$NDK" ] || [ ! -d "$NDK" ]; then
   echo "error: pass the Android NDK path or set ANDROID_NDK_HOME" >&2
   exit 1
fi

case "$(uname -s)" in
   Linux*) HOST=linux-x86_64; EXE=; WRAP= ;;
   Darwin*) HOST=darwin-x86_64; EXE=; WRAP= ;;
   MINGW*|MSYS*|CYGWIN*) HOST=windows-x86_64; EXE=.exe; WRAP=.cmd ;;
   *) echo "error: unsupported host $(uname -s)" >&2; exit 1 ;;
esac

BIN="$NDK/toolchains/llvm/prebuilt/$HOST/bin"
if [ ! -x "$BIN/aarch64-linux-android34-clang$WRAP" ] && [ ! -f "$BIN/aarch64-linux-android34-clang$WRAP" ]; then
   echo "error: no API 34 arm64 compiler in $BIN" >&2
   exit 1
fi

if [ ! -f "$BIN/llvm-strip$EXE" ]; then
   echo "error: llvm-strip not found in $BIN" >&2
   exit 1
fi

PYTHON=python3
command -v "$PYTHON" >/dev/null 2>&1 || PYTHON=python
for tool in meson ninja "$PYTHON" flex bison; do
   if ! command -v "$tool" >/dev/null 2>&1; then
      echo "error: $tool not found in PATH" >&2
      exit 1
   fi
done

BUILD="${BUILD_DIR:-build-android}"
DRIVERS="${GALLIUM_DRIVERS:-radeonsi,zink,softpipe}"
mkdir -p "$BUILD"

cat > "$BUILD/cross.ini" <<EOF
[binaries]
c = '$BIN/aarch64-linux-android34-clang$WRAP'
cpp = '$BIN/aarch64-linux-android34-clang++$WRAP'
ar = '$BIN/llvm-ar$EXE'
strip = '$BIN/llvm-strip$EXE'

[properties]
cpp_link_args = ['-static-libstdc++']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF

if [ ! -f "$BUILD/build.ninja" ]; then
   meson setup "$BUILD" --cross-file "$BUILD/cross.ini" \
      -Dbuildtype=debugoptimized -Db_ndebug=true \
      -Dplatforms=android -Dplatform-sdk-version=34 -Dandroid-stub=true -Dandroid-strict=false \
      -Dandroid-libbacktrace=disabled \
      -Dgallium-drivers="$DRIVERS" -Dvulkan-drivers= -Dvulkan-layers= -Dtools= \
      -Degl=enabled -Dopengl=true -Dgles1=disabled -Dgles2=enabled -Dglx=disabled -Dgbm=disabled \
      -Degl-lib-suffix=_mesa -Dgles-lib-suffix=_mesa \
      -Dllvm=disabled -Dzstd=disabled -Dlmsensors=disabled -Dperfetto=false -Dvideo-codecs= \
      -Dallow-fallback-for=libdrm,perfetto --force-fallback-for=expat,libdrm,zlib \
      -Dlibdrm:default_library=static -Dexpat:default_library=static -Dzlib:default_library=static \
      -Dc_args=-march=armv8.2-a -Dcpp_args=-march=armv8.2-a
fi

ninja -C "$BUILD" src/egl/libEGL_mesa.so src/gallium/targets/dri/libgallium_dri.so \
   src/mesa/glapi/es2api/libGLESv2_mesa.so

mkdir -p "$BUILD/stripped" dist
for lib in src/egl/libEGL_mesa.so src/gallium/targets/dri/libgallium_dri.so \
           src/mesa/glapi/es2api/libGLESv2_mesa.so; do
   "$BIN/llvm-strip$EXE" -o "$BUILD/stripped/$(basename "$lib")" "$BUILD/$lib"
done
"$PYTHON" android/package.py "$BUILD/stripped" dist
