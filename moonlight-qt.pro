TEMPLATE = subdirs
SUBDIRS = \
    moonlight-common-c \
    qmdnsengine \
    app \
    h264bitstream \
    awdl-helper

# Build the dependencies in parallel before the final app
app.depends = qmdnsengine moonlight-common-c h264bitstream awdl-helper

# Support debug and release builds from command line for CI
CONFIG += debug_and_release
