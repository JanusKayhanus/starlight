cmake_minimum_required(VERSION 3.20)
project(Moonlight LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0" CACHE STRING "Minimum macOS version")

# Default to a Release build for single-config generators (Make/Ninja).
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)
endif()

# Depend only on the app bundle's Frameworks directory, and avoid embedding the
# absolute build-tree library directory as a runtime search path.
set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
set(CMAKE_INSTALL_RPATH "@executable_path/../Frameworks")

set(MOONLIGHT_DEPS "${CMAKE_CURRENT_SOURCE_DIR}/libs/mac")
set(MOONLIGHT_COMMON "${CMAKE_CURRENT_SOURCE_DIR}/moonlight-common-c")
set(MOONLIGHT_H264 "${CMAKE_CURRENT_SOURCE_DIR}/h264bitstream")

if(NOT EXISTS "${MOONLIGHT_DEPS}/lib/libSDL2.dylib")
    message(FATAL_ERROR "Missing macOS dependencies. Run 'python3 setup-deps.py'.")
endif()

# Prebuilt third-party dylibs, exposed as imported targets so the link line and
# the bundle copy/sign list can never drift apart. Each entry is "target:file".
set(MOONLIGHT_PREBUILT_LIBS
    "SDL2:libSDL2.dylib"
    "SDL2_ttf:libSDL2_ttf.dylib"
    "avcodec:libavcodec.63.dylib"
    "avutil:libavutil.61.dylib"
    "swscale:libswscale.10.dylib"
    "opus:libopus.0.dylib"
    "discord-rpc:libdiscord-rpc.dylib"
    "ssl:libssl.3.dylib"
    "crypto:libcrypto.3.dylib"
)

set(MOONLIGHT_PREBUILT_TARGETS "")
set(MOONLIGHT_BUNDLED_DYLIBS "")
foreach(_entry IN LISTS MOONLIGHT_PREBUILT_LIBS)
    string(REPLACE ":" ";" _parts "${_entry}")
    list(GET _parts 0 _target)
    list(GET _parts 1 _file)

    add_library(${_target} SHARED IMPORTED)
    set_target_properties(${_target} PROPERTIES
        IMPORTED_LOCATION "${MOONLIGHT_DEPS}/lib/${_file}")

    list(APPEND MOONLIGHT_PREBUILT_TARGETS ${_target})
    list(APPEND MOONLIGHT_BUNDLED_DYLIBS ${_file})
endforeach()

# libSDL2.dylib is sdl2-compat, which dlopen()s SDL3 from next to itself while
# it loads. We don't link SDL3, but it must still be bundled: without it,
# sdl2-compat blocks before main() on a modal "Failed loading SDL3" dialog.
list(APPEND MOONLIGHT_BUNDLED_DYLIBS libSDL3.dylib)

add_executable(Moonlight MACOSX_BUNDLE
    client/backend/richpresencemanager.cpp
    client/main.cpp
    client/cli.cpp
    client/cfprefs.cpp
    client/http.cpp
    client/identity.cpp
    client/pairing.cpp
    client/path.cpp
    client/serverinfo.cpp
    client/settings.cpp
    client/xml.cpp
    client/settings/mappingmanager.cpp
    client/settings/streamingpreferences.cpp
    client/streaming/awdlsuppressor.cpp
    client/streaming/macoswindowinfo.mm
    client/streaming/session.cpp
    client/streaming/streamutils.cpp
    client/streaming/audio/audio.cpp
    client/streaming/audio/renderers/sdlaud.cpp
    client/streaming/input/abstouch.cpp
    client/streaming/input/gamepad.cpp
    client/streaming/input/input.cpp
    client/streaming/input/keyboard.cpp
    client/streaming/input/macoscursor.mm
    client/streaming/input/mouse.cpp
    client/streaming/input/reltouch.cpp
    client/streaming/video/bandwidth.cpp
    client/streaming/video/ffmpeg.cpp
    client/streaming/video/ffmpeg-renderers/pacer/pacer.cpp
    client/streaming/video/ffmpeg-renderers/sdlvid.cpp
    client/streaming/video/ffmpeg-renderers/swframemapper.cpp
    client/streaming/video/ffmpeg-renderers/vt_avsamplelayer.mm
    client/streaming/video/ffmpeg-renderers/vt_base.mm
    client/streaming/video/ffmpeg-renderers/vt_metal.mm
    client/streaming/video/overlaymanager.cpp
)

target_include_directories(Moonlight PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/client"
    "${CMAKE_CURRENT_SOURCE_DIR}/awdl-helper"
    "${MOONLIGHT_DEPS}/include"
    "${MOONLIGHT_DEPS}/include/SDL2"
    "${MOONLIGHT_COMMON}/moonlight-common-c/src"
    "${MOONLIGHT_H264}"
)

target_compile_definitions(Moonlight PRIVATE HAVE_FFMPEG HAVE_DISCORD)

target_compile_options(Moonlight PRIVATE
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-deprecated-declarations
    -Wno-reorder-ctor
)

# Bundle everything under a single runtime search path (set globally above).
set_target_properties(Moonlight PROPERTIES
    INSTALL_RPATH "@executable_path/../Frameworks"
)

# Build the streaming protocol and bitstream helpers from source so the app
# has no dependency on qmake or any Qt-built artifacts.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(OPENSSL_ROOT_DIR "${MOONLIGHT_DEPS}")
set(OPENSSL_INCLUDE_DIR "${MOONLIGHT_DEPS}/include")
set(OPENSSL_SSL_LIBRARY "${MOONLIGHT_DEPS}/lib/libssl.3.dylib")
set(OPENSSL_CRYPTO_LIBRARY "${MOONLIGHT_DEPS}/lib/libcrypto.3.dylib")
set(OPENSSL_FOUND TRUE)
add_subdirectory("${MOONLIGHT_COMMON}/moonlight-common-c"
                 "${CMAKE_BINARY_DIR}/moonlight-common-c" EXCLUDE_FROM_ALL)

add_library(h264bitstream STATIC
    "${MOONLIGHT_H264}/h264_nal.c"
    "${MOONLIGHT_H264}/h264_stream.c"
)
target_include_directories(h264bitstream PUBLIC "${MOONLIGHT_H264}")

target_link_libraries(Moonlight PRIVATE
    ${MOONLIGHT_PREBUILT_TARGETS}
    moonlight-common-c
    h264bitstream
    "-framework VideoToolbox"
    "-framework AVFoundation"
    "-framework CoreVideo"
    "-framework CoreGraphics"
    "-framework CoreMedia"
    "-framework CoreFoundation"
    "-framework AppKit"
    "-framework Metal"
    "-framework MetalKit"
    "-framework QuartzCore"
)

# Privileged helper that suppresses AWDL (AirDrop) while streaming.
add_executable(MoonlightAWDLHelper awdl-helper/awdl-helper.c)
target_include_directories(MoonlightAWDLHelper PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/awdl-helper"
)

set_target_properties(Moonlight PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/client/Info.plist"
    MACOSX_BUNDLE_ICON_FILE "starlight.icns"
    MACOSX_BUNDLE_BUNDLE_NAME "Moonlight"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.moonlight-stream.Moonlight"
    MACOSX_BUNDLE_BUNDLE_VERSION "6.2.1"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "6.2.1"
)

# Keep the app bundle icon and runtime data files in the executable's
# Resources directory.
add_custom_command(TARGET Moonlight POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Resources"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/client/starlight.icns"
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Resources/starlight.icns"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/client/resources/ModeSeven.ttf"
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Resources/ModeSeven.ttf"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/client/resources/gamecontrollerdb.txt"
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Resources/gamecontrollerdb.txt"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/client/resources/vt_renderer.metal"
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Resources/vt_renderer.metal"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:MoonlightAWDLHelper>"
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/MacOS/MoonlightAWDLHelper"
    COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Frameworks"
)

foreach(DYLIB IN LISTS MOONLIGHT_BUNDLED_DYLIBS)
    add_custom_command(TARGET Moonlight POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${MOONLIGHT_DEPS}/lib/${DYLIB}"
                "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Frameworks/${DYLIB}"
    )
endforeach()

# Sign the bundle (including nested code). We must not re-sign the prebuilt
# third-party dylibs with a plain `codesign --force --sign -` (that makes SDL2
# abort during load), so use `--deep`, which re-signs them correctly.
add_custom_command(TARGET Moonlight POST_BUILD
    COMMAND codesign --force --deep --sign - --entitlements
            "${CMAKE_CURRENT_SOURCE_DIR}/client/Moonlight.entitlements"
            "$<TARGET_BUNDLE_DIR:Moonlight>"
    COMMENT "Signing Moonlight.app"
)
