cmake_minimum_required(VERSION 3.20)
project(Moonlight LANGUAGES C CXX OBJC)

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
    client/main.cpp
    client/settings.cpp
    client/http.cpp
    client/input.cpp
    client/audio/sdlaud.cpp
    client/video/bandwidth.cpp
    client/video/ffmpeg.cpp
    client/video/sdlvid.cpp
    client/video/streamutils.cpp
    client/video/swframemapper.cpp
    client/video/vtrenderer.cpp
)

target_include_directories(Moonlight PRIVATE
    "${MOONLIGHT_DEPS}/include"
    "${MOONLIGHT_DEPS}/include/SDL2"
    "${MOONLIGHT_COMMON}/moonlight-common-c/src"
    "${MOONLIGHT_H264}"
)

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
    "${MOONLIGHT_DEPS}/lib/libavcodec.63.dylib"
    "${MOONLIGHT_DEPS}/lib/libavutil.61.dylib"
    "${MOONLIGHT_DEPS}/lib/libswscale.10.dylib"
    "${MOONLIGHT_DEPS}/lib/libopus.0.dylib"
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
    "-framework QuartzCore"
)

set_target_properties(Moonlight PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/client/Info.plist"
    MACOSX_BUNDLE_ICON_FILE "moonlight.icns"
    MACOSX_BUNDLE_BUNDLE_NAME "Moonlight"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.moonlight-stream.Moonlight"
    MACOSX_BUNDLE_BUNDLE_VERSION "6.2.1"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "6.2.1"
)

# Keep the app bundle icon next to the executable's Resources directory.
add_custom_command(TARGET Moonlight POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Resources"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/client/moonlight.icns"
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Resources/moonlight.icns"
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/scripts/add-bundle-rpath.sh"
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/MacOS/Moonlight"
    COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Frameworks"
)
foreach(DYLIB libSDL2.dylib libavcodec.63.dylib libavutil.61.dylib
              libswscale.10.dylib libopus.0.dylib libssl.3.dylib
              libcrypto.3.dylib)
    add_custom_command(TARGET Moonlight POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${MOONLIGHT_DEPS}/lib/${DYLIB}"
                "$<TARGET_BUNDLE_CONTENT_DIR:Moonlight>/Frameworks/${DYLIB}"
    )
endforeach()
