cmake_minimum_required(VERSION 3.20)
project(Moonlight LANGUAGES C CXX OBJC OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum macOS version")

set(MOONLIGHT_DEPS "${CMAKE_CURRENT_SOURCE_DIR}/libs/mac")
set(MOONLIGHT_COMMON "${CMAKE_CURRENT_SOURCE_DIR}/moonlight-common-c")
set(MOONLIGHT_H264 "${CMAKE_CURRENT_SOURCE_DIR}/h264bitstream")

if(NOT EXISTS "${MOONLIGHT_DEPS}/lib/libSDL2.dylib")
    message(FATAL_ERROR "Missing macOS dependencies. Run 'python3 setup-deps.py'.")
endif()

add_executable(Moonlight MACOSX_BUNDLE
    client/backend/richpresencemanager.cpp
    client/main.cpp
    client/cli.cpp
    client/cfprefs.cpp
    client/http.cpp
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

target_link_directories(Moonlight PRIVATE "${MOONLIGHT_DEPS}/lib")

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
    "${MOONLIGHT_DEPS}/lib/libSDL2.dylib"
    "${MOONLIGHT_DEPS}/lib/libSDL2_ttf.dylib"
    "${MOONLIGHT_DEPS}/lib/libavcodec.63.dylib"
    "${MOONLIGHT_DEPS}/lib/libavutil.61.dylib"
    "${MOONLIGHT_DEPS}/lib/libswscale.10.dylib"
    "${MOONLIGHT_DEPS}/lib/libopus.0.dylib"
    "${MOONLIGHT_DEPS}/lib/libdiscord-rpc.dylib"
    "${MOONLIGHT_DEPS}/lib/libssl.3.dylib"
    "${MOONLIGHT_DEPS}/lib/libcrypto.3.dylib"
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
    MACOSX_BUNDLE_ICON_FILE "moonlight.icns"
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
            "${CMAKE_CURRENT_SOURCE_DIR}/client/moonlight.icns"
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Resources/moonlight.icns"
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
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/scripts/add-bundle-rpath.sh"
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/MacOS/Moonlight"
    COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Frameworks"
)
foreach(DYLIB libSDL2.dylib libSDL2_ttf.dylib libavcodec.63.dylib
              libavutil.61.dylib libswscale.10.dylib libopus.0.dylib
              libdiscord-rpc.dylib libssl.3.dylib libcrypto.3.dylib)
    add_custom_command(TARGET Moonlight POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${MOONLIGHT_DEPS}/lib/${DYLIB}"
                "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Frameworks/${DYLIB}"
    )
endforeach()

# LaunchServices requires a valid bundle signature even for local development.
add_custom_command(TARGET Moonlight POST_BUILD
    COMMAND codesign --force --deep --sign - --entitlements
            "${CMAKE_CURRENT_SOURCE_DIR}/client/Moonlight.entitlements"
            "$<TARGET_BUNDLE_DIR:Moonlight>"
)
