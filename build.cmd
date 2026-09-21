@echo off
rem Build RadeonSI (with Zink and softpipe) and EGL/OpenGL ES for Android (arm64, API 34), and
rem package the libraries into dist\.
rem
rem usage: build.cmd [path-to-android-ndk]
rem   The NDK can also come from ANDROID_NDK_HOME or ANDROID_NDK_ROOT.
rem   BUILD_DIR overrides the build directory (default: build-android).
rem   GALLIUM_DRIVERS overrides the drivers (default: radeonsi,zink,softpipe).
rem Requires: meson, ninja, python (mako, packaging), win_flex and win_bison (winflexbison) or
rem flex and bison, and the NDK's llvm-strip.
setlocal

cd /d "%~dp0"

set "NDK=%~1"
if "%NDK%"=="" set "NDK=%ANDROID_NDK_HOME%"
if "%NDK%"=="" set "NDK=%ANDROID_NDK_ROOT%"
if "%NDK%"=="" goto :no_ndk
if not exist "%NDK%\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android34-clang.cmd" goto :no_ndk

if not exist "%NDK%\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe" (
   echo error: llvm-strip.exe not found in the NDK 1>&2
   exit /b 1
)

set "BIN=%NDK:\=/%/toolchains/llvm/prebuilt/windows-x86_64/bin"

for %%T in (meson ninja python) do (
   where %%T >nul 2>nul || (
      echo error: %%T not found in PATH 1>&2
      exit /b 1
   )
)
where win_flex >nul 2>nul || where flex >nul 2>nul || (
   echo error: neither win_flex nor flex found in PATH 1>&2
   exit /b 1
)
where win_bison >nul 2>nul || where bison >nul 2>nul || (
   echo error: neither win_bison nor bison found in PATH 1>&2
   exit /b 1
)

if "%BUILD_DIR%"=="" (set "BUILD=build-android") else (set "BUILD=%BUILD_DIR%")
if "%GALLIUM_DRIVERS%"=="" (set "DRIVERS=radeonsi,zink,softpipe") else (set "DRIVERS=%GALLIUM_DRIVERS%")
if not exist "%BUILD%" mkdir "%BUILD%"

> "%BUILD%\cross.ini" (
   echo [binaries]
   echo c = '%BIN%/aarch64-linux-android34-clang.cmd'
   echo cpp = '%BIN%/aarch64-linux-android34-clang++.cmd'
   echo ar = '%BIN%/llvm-ar.exe'
   echo strip = '%BIN%/llvm-strip.exe'
   echo.
   echo [properties]
   echo cpp_link_args = ['-static-libstdc++']
   echo.
   echo [host_machine]
   echo system = 'android'
   echo cpu_family = 'aarch64'
   echo cpu = 'aarch64'
   echo endian = 'little'
)

if exist "%BUILD%\build.ninja" goto :build
call meson setup "%BUILD%" --cross-file "%BUILD%\cross.ini" ^
   -Dbuildtype=debugoptimized -Db_ndebug=true ^
   -Dplatforms=android -Dplatform-sdk-version=34 -Dandroid-stub=true -Dandroid-strict=false ^
   -Dandroid-libbacktrace=disabled ^
   -Dgallium-drivers=%DRIVERS% -Dvulkan-drivers= -Dvulkan-layers= -Dtools= ^
   -Degl=enabled -Dopengl=true -Dgles1=disabled -Dgles2=enabled -Dglx=disabled -Dgbm=disabled ^
   -Degl-lib-suffix=_mesa -Dgles-lib-suffix=_mesa ^
   -Dllvm=disabled -Dzstd=disabled -Dlmsensors=disabled -Dperfetto=false -Dvideo-codecs= ^
   -Dallow-fallback-for=libdrm,perfetto --force-fallback-for=expat,libdrm,zlib ^
   -Dlibdrm:default_library=static -Dexpat:default_library=static -Dzlib:default_library=static ^
   -Dc_args=-march=armv8.2-a -Dcpp_args=-march=armv8.2-a
if errorlevel 1 exit /b 1

:build
ninja -C "%BUILD%" src/egl/libEGL_mesa.so src/gallium/targets/dri/libgallium_dri.so src/mesa/glapi/es2api/libGLESv2_mesa.so
if errorlevel 1 exit /b 1

if not exist "%BUILD%\stripped" mkdir "%BUILD%\stripped"
if not exist dist mkdir dist
for %%L in (src\egl\libEGL_mesa.so src\gallium\targets\dri\libgallium_dri.so src\mesa\glapi\es2api\libGLESv2_mesa.so) do (
   "%NDK%\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe" -o "%BUILD%\stripped\%%~nxL" "%BUILD%\%%L"
   if errorlevel 1 exit /b 1
)
python android\package.py "%BUILD%\stripped" dist
exit /b %errorlevel%

:no_ndk
echo error: pass the Android NDK path or set ANDROID_NDK_HOME 1>&2
exit /b 1
