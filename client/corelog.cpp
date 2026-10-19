#include "corelog.h"

#include <cstdarg>
#include <cstdio>

namespace {

void logToStderr(CoreLogLevel level, const char* message)
{
    const char* prefix = level == CoreLogLevel::Error ? "ERROR: " :
                         level == CoreLogLevel::Warning ? "WARN: " : "INFO: ";
    fprintf(stderr, "%s%s\n", prefix, message);
}

CoreLogHandler s_Handler = logToStderr;

} // namespace

void setCoreLogHandler(CoreLogHandler handler)
{
    s_Handler = handler != nullptr ? handler : logToStderr;
}

void coreLog(CoreLogLevel level, const char* format, ...)
{
    char message[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    s_Handler(level, message);
}
