#include "audio/sdl.h"
#include "http.h"
#include "input.h"
#include "settings.h"
#include "video/ffmpeg.h"
#include "video/streamutils.h"
#include "video/vtrenderer.h"

#include <Limelight.h>

#include <openssl/rand.h>
#include <opus_multistream.h>

#include <SDL.h>

#include <arpa/inet.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

namespace {

constexpr int kStreamWidth = 3456;
constexpr int kStreamHeight = 2160;
constexpr int kStreamFps = 60;
constexpr int kStreamBitrateKbps = 100000;

HostConfig g_host;
ClientConfig g_client;

SDL_Window* g_window = nullptr;
FFmpegVideoDecoder* g_decoder = nullptr;
SdlAudioRenderer* g_audioRenderer = nullptr;
OpusMSDecoder* g_opusDecoder = nullptr;
OPUS_MULTISTREAM_CONFIGURATION g_audioConfig = {};
int g_audioSampleCount = 0;
bool g_streamEnded = false;
int g_connectionError = 0;
DECODER_RENDERER_CALLBACKS g_videoCallbacks;

std::string xmlAttribute(const std::string& xml, const char* name)
{
    std::string needle = std::string(name) + "=\"";
    size_t start = xml.find(needle);
    if (start == std::string::npos) {
        return {};
    }
    start += needle.size();
    size_t end = xml.find('"', start);
    return end == std::string::npos ? std::string() : xml.substr(start, end - start);
}

std::string xmlTag(const std::string& xml, const char* tag)
{
    std::string open = std::string("<") + tag + ">";
    std::string close = std::string("</") + tag + ">";
    size_t start = xml.find(open);
    if (start == std::string::npos) {
        return {};
    }
    start += open.size();
    size_t end = xml.find(close, start);
    if (end == std::string::npos) {
        return {};
    }
    return xml.substr(start, end - start);
}

bool getEnvInt(const char* name, int* value)
{
    const char* env = getenv(name);
    if (env == nullptr) {
        return false;
    }
    *value = atoi(env);
    return true;
}

std::string randomUuidHex()
{
    unsigned char bytes[16];
    RAND_bytes(bytes, sizeof(bytes));
    char hex[33];
    for (int i = 0; i < 16; i++) {
        snprintf(&hex[i * 2], 3, "%02x", bytes[i]);
    }
    return std::string(hex, 32);
}

uint32_t bigEndianU32(const unsigned char* data)
{
    return ((uint32_t)data[0] << 24) | ((uint32_t)data[1] << 16) |
           ((uint32_t)data[2] << 8) | (uint32_t)data[3];
}

int videoSetup(int videoFormat, int width, int height, int frameRate, void*, int)
{
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Video stream is %dx%dx%d (format 0x%x)",
                width, height, frameRate, videoFormat);

    DECODER_PARAMETERS params = {};
    params.window = g_window;
    params.vds = VideoDecoderSelection::Auto;
    params.videoFormat = videoFormat;
    params.width = width;
    params.height = height;
    params.frameRate = frameRate;
    params.enableVsync = false;
    params.testOnly = false;

    auto* decoder = new FFmpegVideoDecoder(false);
    if (!decoder->initialize(&params)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Unable to initialize the video decoder");
        delete decoder;
        return -1;
    }

    g_decoder = decoder;

    g_videoCallbacks.capabilities = decoder->getDecoderCapabilities();
    if (g_videoCallbacks.capabilities & CAPABILITY_PULL_RENDERER) {
        g_videoCallbacks.submitDecodeUnit = nullptr;
    }

    return 0;
}

void videoStart()
{
}

void videoStop()
{
}

void videoCleanup()
{
    delete g_decoder;
    g_decoder = nullptr;
}

int submitDecodeUnit(PDECODE_UNIT du)
{
    if (g_decoder == nullptr) {
        return DR_OK;
    }
    return g_decoder->submitDecodeUnit(du);
}

int audioInit(int, const POPUS_MULTISTREAM_CONFIGURATION opusConfig, void*, int)
{
    g_audioRenderer = new SdlAudioRenderer();
    if (!g_audioRenderer->prepareForPlayback(opusConfig)) {
        delete g_audioRenderer;
        g_audioRenderer = nullptr;
        return -1;
    }

    g_audioConfig = *opusConfig;
    g_audioRenderer->remapChannels(&g_audioConfig);

    int error = 0;
    g_opusDecoder = opus_multistream_decoder_create(g_audioConfig.sampleRate,
                                                    g_audioConfig.channelCount,
                                                    g_audioConfig.streams,
                                                    g_audioConfig.coupledStreams,
                                                    g_audioConfig.mapping,
                                                    &error);
    if (g_opusDecoder == nullptr) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "opus_multistream_decoder_create failed: %d", error);
        delete g_audioRenderer;
        g_audioRenderer = nullptr;
        return -1;
    }

    g_audioSampleCount = 0;
    return 0;
}

void audioCleanup()
{
    opus_multistream_decoder_destroy(g_opusDecoder);
    g_opusDecoder = nullptr;
    delete g_audioRenderer;
    g_audioRenderer = nullptr;
}

void audioDecodeAndPlay(char* sampleData, int sampleLength)
{
    if (g_audioRenderer == nullptr || g_opusDecoder == nullptr) {
        return;
    }

    if (g_audioSampleCount++ == 0) {
        SDL_SetThreadPriority(SDL_THREAD_PRIORITY_HIGH);
    }

    int sampleSize = g_audioRenderer->getAudioBufferSampleSize();
    int frameSize = sampleSize * g_audioConfig.channelCount;
    int desiredBufferSize = frameSize * g_audioConfig.samplesPerFrame;
    void* buffer = g_audioRenderer->getAudioBuffer(&desiredBufferSize);
    if (buffer == nullptr) {
        return;
    }

    int samplesDecoded = opus_multistream_decode_float(g_opusDecoder,
                                                       (unsigned char*)sampleData,
                                                       sampleLength,
                                                       (float*)buffer,
                                                       desiredBufferSize / frameSize,
                                                       0);
    if (samplesDecoded > 0) {
        g_audioRenderer->submitAudio(frameSize * samplesDecoded);
    }
}

void stageStarting(int stage)
{
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Starting: %s", LiGetStageName(stage));
}

void stageFailed(int stage, int errorCode)
{
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "Stage %s failed: %d", LiGetStageName(stage), errorCode);
    g_connectionError = errorCode;
    g_streamEnded = true;
}

void connectionStarted()
{
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Stream connected");
}

void connectionTerminated(int errorCode)
{
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Stream terminated: %d", errorCode);
    g_streamEnded = true;
}

void logMessage(const char* format, ...)
{
    va_list ap;
    va_start(ap, format);
    char buffer[1024];
    vsnprintf(buffer, sizeof(buffer), format, ap);
    va_end(ap);
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Moonlight: %s", buffer);
}

int runStream(const std::string& serverInfo)
{
    const int httpsPort = atoi(xmlTag(serverInfo, "HttpsPort").c_str()) ?: 47984;
    const int currentGameId = atoi(xmlTag(serverInfo, "currentgame").c_str());
    const int serverCodecModeSupport = atoi(xmlTag(serverInfo, "ServerCodecModeSupport").c_str());

    std::string appVersion = xmlTag(serverInfo, "appversion");
    std::string gfeVersion = xmlTag(serverInfo, "GfeVersion");
    if (appVersion.empty()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "serverinfo did not include an app version");
        return 1;
    }

    STREAM_CONFIGURATION config;
    LiInitializeStreamConfiguration(&config);

    getEnvInt("MOONLIGHT_WIDTH", &config.width);
    getEnvInt("MOONLIGHT_HEIGHT", &config.height);
    getEnvInt("MOONLIGHT_FPS", &config.fps);
    getEnvInt("MOONLIGHT_BITRATE", &config.bitrate);
    if (config.width == 0) config.width = kStreamWidth;
    if (config.height == 0) config.height = kStreamHeight;
    if (config.fps == 0) config.fps = kStreamFps;
    if (config.bitrate == 0) config.bitrate = kStreamBitrateKbps;

    config.packetSize = 1392;
    config.streamingRemotely = STREAM_CFG_LOCAL;
    config.audioConfiguration = AUDIO_CONFIGURATION_STEREO;
    // H.264 keeps the initial Qt-free build on the well-tested VideoToolbox +
    // SDL path. The host is a Sunshine server and can encode H.264.
    config.supportedVideoFormats = VIDEO_FORMAT_H264;
    config.colorSpace = COLORSPACE_REC_709;
    config.colorRange = COLOR_RANGE_LIMITED;
    config.encryptionFlags = ENCFLG_ALL;
    config.clientRefreshRateX100 = 0;

    unsigned char riKey[16];
    unsigned char riIv[16];
    RAND_bytes(riKey, sizeof(riKey));
    RAND_bytes(riIv, sizeof(riIv));
    memcpy(config.remoteInputAesKey, riKey, sizeof(riKey));
    memcpy(config.remoteInputAesIv, riIv, sizeof(riIv));

    char riKeyHex[33];
    for (int i = 0; i < 16; i++) {
        snprintf(&riKeyHex[i * 2], 3, "%02x", riKey[i]);
    }
    uint32_t riKeyId = bigEndianU32(riIv);

    std::string verb = (currentGameId == g_host.appId) ? "resume" : "launch";
    char query[2048];
    snprintf(query, sizeof(query),
             "?uniqueid=%s&uuid=%s&appid=%d&mode=%dx%dx%d&additionalStates=1&sops=1"
             "&rikey=%s&rikeyid=%u&localAudioPlayMode=0&surroundAudioInfo=%d"
             "&remoteControllersBitmap=0&gcmap=0&gcpersist=0&corever=1",
             g_client.uniqueId.c_str(), randomUuidHex().c_str(), g_host.appId,
             config.width, config.height, config.fps, riKeyHex, riKeyId,
             SURROUNDAUDIOINFO_FROM_AUDIO_CONFIGURATION(config.audioConfiguration));

    std::string launchResponse;
    std::string error;
    std::string path = "/" + verb + query;
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Requesting %s", path.c_str());
    if (!httpsGet(g_host.address, (uint16_t)httpsPort, path,
                  g_client.certPem, g_client.keyPem, g_host.serverCertPem,
                  launchResponse, error)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Launch failed: %s", error.c_str());
        return 1;
    }

    std::string rtspSessionUrl = xmlTag(launchResponse, "sessionUrl0");
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Launch response: %s", launchResponse.c_str());

    std::string statusCode = xmlAttribute(launchResponse, "status_code");
    if (!statusCode.empty() && statusCode != "200") {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "Host rejected the launch: %s (%s)",
                     xmlAttribute(launchResponse, "status_message").c_str(),
                     statusCode.c_str());
        return 1;
    }

    SERVER_INFORMATION hostInfo;
    LiInitializeServerInformation(&hostInfo);
    hostInfo.address = g_host.address.c_str();
    hostInfo.serverInfoAppVersion = appVersion.c_str();
    hostInfo.serverInfoGfeVersion = gfeVersion.empty() ? nullptr : gfeVersion.c_str();
    hostInfo.rtspSessionUrl = rtspSessionUrl.empty() ? nullptr : rtspSessionUrl.c_str();
    hostInfo.serverCodecModeSupport = serverCodecModeSupport;
    (void)serverCodecModeSupport;

    LiInitializeVideoCallbacks(&g_videoCallbacks);
    g_videoCallbacks.setup = videoSetup;
    g_videoCallbacks.start = videoStart;
    g_videoCallbacks.stop = videoStop;
    g_videoCallbacks.cleanup = videoCleanup;
    g_videoCallbacks.submitDecodeUnit = submitDecodeUnit;

    AUDIO_RENDERER_CALLBACKS audioCallbacks;
    LiInitializeAudioCallbacks(&audioCallbacks);
    audioCallbacks.init = audioInit;
    audioCallbacks.cleanup = audioCleanup;
    audioCallbacks.decodeAndPlaySample = audioDecodeAndPlay;
    audioCallbacks.capabilities = CAPABILITY_SUPPORTS_ARBITRARY_AUDIO_DURATION;

    CONNECTION_LISTENER_CALLBACKS connCallbacks;
    LiInitializeConnectionCallbacks(&connCallbacks);
    connCallbacks.stageStarting = stageStarting;
    connCallbacks.stageFailed = stageFailed;
    connCallbacks.connectionStarted = connectionStarted;
    connCallbacks.connectionTerminated = connectionTerminated;
    connCallbacks.logMessage = logMessage;

    int err = LiStartConnection(&hostInfo, &config, &connCallbacks,
                                &g_videoCallbacks, &audioCallbacks,
                                nullptr, 0, nullptr, 0);
    if (err != 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "LiStartConnection failed: %d", err);
        return 1;
    }

    enableRelativeMouse();

    SDL_Event event;
    while (!g_streamEnded) {
        if (g_decoder != nullptr) {
            g_decoder->renderFrameOnMainThread();
        }

        if (SDL_WaitEventTimeout(&event, 1) == 0) {
            continue;
        }

        if (handleInputEvent(event)) {
            break;
        }
    }

    LiInterruptConnection();

    // Tear down the decoder while the connection is still alive so its
    // pull-mode thread is woken and joined before LiStopConnection runs.
    delete g_decoder;
    g_decoder = nullptr;

    LiStopConnection();
    return g_connectionError == 0 ? 0 : 1;
}

} // namespace

int main(int argc, char** argv)
{
    std::string error;
    if (!loadMoonlightSettings(g_host, g_client, error)) {
        fprintf(stderr, "Settings error: %s\n", error.c_str());
        return 1;
    }

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Launching %s on %s (%s:%u)",
                g_host.appName.c_str(), g_host.name.c_str(),
                g_host.address.c_str(), g_host.httpPort);

    std::string serverInfo;
    std::string serverInfoPath = "/serverinfo?uniqueid=0123456789ABCDEF&uuid=" + randomUuidHex();
    if (!httpGet(g_host.address, g_host.httpPort, serverInfoPath, serverInfo, error)) {
        fprintf(stderr, "serverinfo failed: %s\n", error.c_str());
        return 1;
    }

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_GAMECONTROLLER | SDL_INIT_TIMER) != 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_SetHint(SDL_HINT_RENDER_DRIVER, "metal");
    SDL_SetHint(SDL_HINT_VIDEO_MINIMIZE_ON_FOCUS_LOSS, "0");

    g_window = SDL_CreateWindow("DESKTOP-BUO46UK - Desktop",
                                0, 0, kStreamWidth, kStreamHeight,
                                SDL_WINDOW_FULLSCREEN_DESKTOP |
                                SDL_WINDOW_ALLOW_HIGHDPI |
                                SDL_WINDOW_METAL |
                                SDL_WINDOW_RESIZABLE);
    if (g_window == nullptr) {
        fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    int result = runStream(serverInfo);

    SDL_DestroyWindow(g_window);
    g_window = nullptr;
    SDL_Quit();
    return result;
}
