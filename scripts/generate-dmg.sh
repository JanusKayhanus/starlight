#!/bin/bash
# Builds the Qt-free Moonlight app and creates a DMG.
# Requires create-dmg: https://github.com/sindresorhus/create-dmg

BUILD_CONFIG=${1:-Release}
ARCHS=${ARCHS:-"arm64;x86_64"}

fail()
{
	echo "$1" 1>&2
	exit 1
}

if [ "$BUILD_CONFIG" != "Debug" ] && [ "$BUILD_CONFIG" != "Release" ]; then
  fail "Invalid build configuration - expected 'Debug' or 'Release'"
fi

BUILD_ROOT=$PWD/build
SOURCE_ROOT=$PWD
BUILD_FOLDER=$BUILD_ROOT/build-$BUILD_CONFIG
INSTALLER_FOLDER=$BUILD_ROOT/installer-$BUILD_CONFIG
VERSION=${CI_VERSION:-$(cat "$SOURCE_ROOT/client/version.txt")}

if [ -n "$SIGNING_IDENTITY" ]; then
  git diff-index --quiet HEAD -- || fail "Signed release builds must not have unstaged changes!"
fi

echo Updating dependencies
python3 "$SOURCE_ROOT/setup-deps.py" || fail "Dependency download failed"

echo Cleaning output directories
rm -rf "$BUILD_FOLDER" "$INSTALLER_FOLDER"
mkdir -p "$BUILD_FOLDER" "$INSTALLER_FOLDER"

echo Configuring the project
cmake -S "$SOURCE_ROOT" -B "$BUILD_FOLDER" -G Ninja \
  -DCMAKE_BUILD_TYPE="$BUILD_CONFIG" \
  -DCMAKE_OSX_ARCHITECTURES="$ARCHS" || fail "CMake configure failed!"

echo Building Moonlight
cmake --build "$BUILD_FOLDER" -j"$(sysctl -n hw.logicalcpu)" || fail "Build failed!"

if [ -d "$BUILD_FOLDER/Moonlight.app.dSYM" ]; then
  echo Saving dSYM
  cp -R "$BUILD_FOLDER/Moonlight.app.dSYM" "$INSTALLER_FOLDER/Moonlight-$VERSION.dSYM"
fi

if [ -n "$SIGNING_IDENTITY" ]; then
  echo Signing app bundle
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" \
    "$BUILD_FOLDER/Moonlight.app" || fail "Signing failed!"
fi

if command -v create-dmg >/dev/null 2>&1; then
  echo Creating DMG
  create-dmg \
    --volname "Moonlight" \
    --window-size 600 400 \
    --icon-size 100 \
    --app-drop-link 450 200 \
    --icon "Moonlight.app" 150 200 \
    "$INSTALLER_FOLDER/Moonlight-$VERSION.dmg" \
    "$BUILD_FOLDER/Moonlight.app" || fail "create-dmg failed!"
else
  echo "create-dmg not found; leaving the app bundle at $BUILD_FOLDER/Moonlight.app"
fi

echo Build complete
