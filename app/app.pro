QT += core quick network quickcontrols2 svg
CONFIG += c++17

# macOS-only build. The application bundle name is what appears in the
# menu bar and the Dock.
TARGET = Moonlight

include(../globaldefs.pri)

# Precompile QML files to avoid writing qmlcache on portable versions.
!disable-prebuilts {
    CONFIG(release, debug|release) {
        CONFIG += qtquickcompiler
    }
}

TEMPLATE = app

DEFINES += QT_DEPRECATED_WARNINGS
DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000

# Prebuilt macOS dependencies (FFmpeg, OpenSSL, SDL2, Opus, Discord RPC)
!disable-prebuilts {
    !exists($$PWD/../libs/mac) {
        error("Missing dependencies. Please run 'python3 setup-deps.py' to fetch prebuilt libraries.")
    }

    INCLUDEPATH += $$PWD/../libs/mac/include $$PWD/../libs/mac/include/SDL2
    LIBS += -L$$PWD/../libs/mac/lib

    LIBS += -lssl.3 -lcrypto.3 -lavcodec.63 -lavutil.61 -lswscale.10 -lopus.0 -lSDL2 -lSDL2_ttf
    CONFIG += discord-rpc
}

LIBS += -lobjc -framework VideoToolbox -framework AVFoundation -framework CoreVideo -framework CoreGraphics -framework CoreMedia -framework AppKit -framework Metal -framework QuartzCore
CONFIG += ffmpeg

# Work around Qt 6.9's qyieldcpu.h relying on __yield() being declared by
# <arm_acle.h> on recent Xcode toolchains.
QMAKE_CXXFLAGS += -include $$PWD/arm_acle_compat.h

# AGL was removed from recent macOS SDKs. Qt only needs the OpenGL framework,
# but its framework metadata still passes -framework AGL. Filter it out at link
# time so builds keep working with current SDKs.
QMAKE_LIBS_OPENGL = -framework OpenGL
QMAKE_LINK = python3 $$PWD/../scripts/link-macos.py $$QMAKE_LINK

SOURCES += \
    backend/nvaddress.cpp \
    backend/nvapp.cpp \
    cli/pair.cpp \
    main.cpp \
    backend/computerseeker.cpp \
    backend/identitymanager.cpp \
    backend/nvcomputer.cpp \
    backend/nvhttp.cpp \
    backend/nvpairingmanager.cpp \
    backend/computermanager.cpp \
    backend/boxartmanager.cpp \
    backend/richpresencemanager.cpp \
    cli/commandlineparser.cpp \
    cli/listapps.cpp \
    cli/quitstream.cpp \
    cli/startstream.cpp \
    settings/compatfetcher.cpp \
    settings/mappingfetcher.cpp \
    settings/streamingpreferences.cpp \
    streaming/input/abstouch.cpp \
    streaming/input/gamepad.cpp \
    streaming/input/input.cpp \
    streaming/input/keyboard.cpp \
    streaming/input/mouse.cpp \
    streaming/input/reltouch.cpp \
    streaming/session.cpp \
    streaming/audio/audio.cpp \
    streaming/audio/renderers/sdlaud.cpp \
    gui/computermodel.cpp \
    gui/appmodel.cpp \
    streaming/bandwidth.cpp \
    streaming/streamutils.cpp \
    backend/autoupdatechecker.cpp \
    path.cpp \
    settings/mappingmanager.cpp \
    gui/sdlgamepadkeynavigation.cpp \
    streaming/video/overlaymanager.cpp \
    backend/systemproperties.cpp

HEADERS += \
    SDL_compat.h \
    arm_acle_compat.h \
    backend/nvaddress.h \
    backend/nvapp.h \
    cli/pair.h \
    settings/compatfetcher.h \
    settings/mappingfetcher.h \
    utils.h \
    backend/computerseeker.h \
    backend/identitymanager.h \
    backend/nvcomputer.h \
    backend/nvhttp.h \
    backend/nvpairingmanager.h \
    backend/computermanager.h \
    backend/boxartmanager.h \
    backend/richpresencemanager.h \
    cli/commandlineparser.h \
    cli/listapps.h \
    cli/quitstream.h \
    cli/startstream.h \
    settings/streamingpreferences.h \
    streaming/input/input.h \
    streaming/session.h \
    streaming/audio/renderers/renderer.h \
    streaming/audio/renderers/sdl.h \
    gui/computermodel.h \
    gui/appmodel.h \
    streaming/video/decoder.h \
    streaming/bandwidth.h \
    streaming/streamutils.h \
    backend/autoupdatechecker.h \
    path.h \
    settings/mappingmanager.h \
    gui/sdlgamepadkeynavigation.h \
    streaming/video/overlaymanager.h \
    backend/systemproperties.h

# FFmpeg decoder and the renderers that are available on macOS:
# VideoToolbox with Metal, VideoToolbox with AVSampleBufferDisplayLayer,
# and a software (SDL) fallback.
ffmpeg {
    message(FFmpeg decoder selected)

    DEFINES += HAVE_FFMPEG
    SOURCES += \
        streaming/video/ffmpeg.cpp \
        streaming/video/ffmpeg-renderers/sdlvid.cpp \
        streaming/video/ffmpeg-renderers/swframemapper.cpp \
        streaming/video/ffmpeg-renderers/pacer/pacer.cpp

    HEADERS += \
        streaming/video/ffmpeg.h \
        streaming/video/ffmpeg-renderers/renderer.h \
        streaming/video/ffmpeg-renderers/sdlvid.h \
        streaming/video/ffmpeg-renderers/swframemapper.h \
        streaming/video/ffmpeg-renderers/pacer/pacer.h
}

macx {
    message(VideoToolbox renderer selected)

    SOURCES += \
        streaming/video/ffmpeg-renderers/vt_base.mm \
        streaming/video/ffmpeg-renderers/vt_avsamplelayer.mm \
        streaming/video/ffmpeg-renderers/vt_metal.mm \
        streaming/input/macoscursor.mm \
        streaming/awdlsuppressor.cpp \
        gui/dockshortcut.mm \
        gui/macoswindow.mm

    INCLUDEPATH += $$PWD/../awdl-helper

    HEADERS += \
        streaming/video/ffmpeg-renderers/vt.h \
        streaming/input/macoscursor.h \
        streaming/awdlsuppressor.h \
        gui/dockshortcut.h \
        gui/macoswindow.h
}

discord-rpc {
    message(Discord integration enabled)

    LIBS += -ldiscord-rpc
    DEFINES += HAVE_DISCORD
}

RESOURCES += \
    resources.qrc \
    qml.qrc

TRANSLATIONS += \
    languages/qml_zh_CN.ts \
    languages/qml_de.ts \
    languages/qml_fr.ts \
    languages/qml_nb_NO.ts \
    languages/qml_ru.ts \
    languages/qml_es.ts \
    languages/qml_ja.ts \
    languages/qml_vi.ts \
    languages/qml_th.ts \
    languages/qml_ko.ts \
    languages/qml_hu.ts \
    languages/qml_nl.ts \
    languages/qml_sv.ts \
    languages/qml_tr.ts \
    languages/qml_uk.ts \
    languages/qml_zh_TW.ts \
    languages/qml_el.ts \
    languages/qml_hi.ts \
    languages/qml_it.ts \
    languages/qml_pt.ts \
    languages/qml_pt_BR.ts \
    languages/qml_pl.ts \
    languages/qml_cs.ts \
    languages/qml_he.ts \
    languages/qml_ckb.ts \
    languages/qml_lt.ts \
    languages/qml_et.ts \
    languages/qml_bg.ts \
    languages/qml_eo.ts \
    languages/qml_ta.ts

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

LIBS += -L$$OUT_PWD/../moonlight-common-c/ -lmoonlight-common-c
INCLUDEPATH += $$PWD/../moonlight-common-c/moonlight-common-c/src
DEPENDPATH += $$PWD/../moonlight-common-c/moonlight-common-c/src

LIBS += -L$$OUT_PWD/../qmdnsengine/ -lqmdnsengine
INCLUDEPATH += $$PWD/../qmdnsengine/qmdnsengine/src/include $$PWD/../qmdnsengine
DEPENDPATH += $$PWD/../qmdnsengine/qmdnsengine/src/include $$PWD/../qmdnsengine

LIBS += -L$$OUT_PWD/../h264bitstream/ -lh264bitstream
INCLUDEPATH += $$PWD/../h264bitstream
DEPENDPATH += $$PWD/../h264bitstream

# Create Info.plist in object dir with the correct version string
system(cp $$PWD/Info.plist $$OUT_PWD/Info.plist)
system(sed -i -e 's/VERSION/$$cat(version.txt)/g' $$OUT_PWD/Info.plist)

QMAKE_INFO_PLIST = $$OUT_PWD/Info.plist

APP_BUNDLE_RESOURCES.files = moonlight.icns
APP_BUNDLE_RESOURCES.path = Contents/Resources

APP_BUNDLE_PLIST.files = $$OUT_PWD/Info.plist
APP_BUNDLE_PLIST.path = Contents

# Privileged helper that suppresses AWDL while streaming. It's installed
# from here as a LaunchDaemon when first needed.
APP_BUNDLE_AWDL_HELPER.files = $$OUT_PWD/../awdl-helper/MoonlightAWDLHelper
APP_BUNDLE_AWDL_HELPER.path = Contents/MacOS

QMAKE_BUNDLE_DATA += APP_BUNDLE_RESOURCES APP_BUNDLE_PLIST APP_BUNDLE_AWDL_HELPER

!disable-prebuilts {
    APP_BUNDLE_FRAMEWORKS.files = $$files(../libs/mac/Frameworks/*.framework, true) $$files(../libs/mac/lib/*.dylib, true)
    APP_BUNDLE_FRAMEWORKS.path = Contents/Frameworks

    QMAKE_BUNDLE_DATA += APP_BUNDLE_FRAMEWORKS

    QMAKE_RPATHDIR += @executable_path/../Frameworks
}

VERSION = "$$cat(version.txt)"
DEFINES += VERSION_STR=\\\"$$cat(version.txt)\\\"
