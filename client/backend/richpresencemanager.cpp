#include "richpresencemanager.h"

#include "SDL_compat.h"

#include <ctime>

RichPresenceManager::RichPresenceManager(StreamingPreferences& prefs, const std::string& gameName)
    : m_DiscordActive(false)
{
#ifdef HAVE_DISCORD
    if (prefs.richPresence) {
        DiscordEventHandlers handlers = {};
        handlers.ready = discordReady;
        handlers.disconnected = discordDisconnected;
        handlers.errored = discordErrored;
        Discord_Initialize("594668102021677159", &handlers, 0, nullptr);
        m_DiscordActive = true;
    }

    if (m_DiscordActive) {
        std::string stateStr = "Streaming " + gameName;

        DiscordRichPresence discordPresence = {};
        discordPresence.state = stateStr.c_str();
        discordPresence.startTimestamp = time(nullptr);
        discordPresence.largeImageKey = "icon";
        Discord_UpdatePresence(&discordPresence);
    }
#else
    (void)prefs;
    (void)gameName;
#endif
}

RichPresenceManager::~RichPresenceManager()
{
#ifdef HAVE_DISCORD
    if (m_DiscordActive) {
        Discord_ClearPresence();
        Discord_Shutdown();
    }
#endif
}

void RichPresenceManager::runCallbacks()
{
#ifdef HAVE_DISCORD
    if (m_DiscordActive) {
        Discord_RunCallbacks();
    }
#endif
}

#ifdef HAVE_DISCORD
void RichPresenceManager::discordReady(const DiscordUser* request)
{
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Discord integration ready for user: %s", request->username);
}

void RichPresenceManager::discordDisconnected(int errorCode, const char *message)
{
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Discord integration disconnected: %d %s", errorCode, message);
}

void RichPresenceManager::discordErrored(int errorCode, const char *message)
{
    SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                "Discord integration error: %d %s", errorCode, message);
}
#endif
