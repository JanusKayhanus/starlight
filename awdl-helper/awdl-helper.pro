TARGET = MoonlightAWDLHelper
TEMPLATE = app

# Standalone command-line tool with no Qt dependencies, since it is
# copied out of the app bundle and runs as a root LaunchDaemon.
CONFIG -= qt app_bundle
CONFIG += console

# Include global qmake defs
include(../globaldefs.pri)

SOURCES += \
    awdl-helper.c

HEADERS += \
    awdlhelper.h
