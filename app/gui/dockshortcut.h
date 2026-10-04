#pragma once

#include <QString>
#include <QUrl>

namespace DockShortcut {

// Creates a small launcher app in ~/Applications/Moonlight Shortcuts that starts
// streaming the specified app on the specified host, or reuses the existing one.
// The user drags it from the launcher onto the Dock.
//
// Returns an empty string and sets bundlePath on success, or returns a user-facing
// error message on failure.
QString create(const QString& hostUuid, const QString& hostName,
               const QString& appName, const QUrl& boxArt, QString* bundlePath);

}
