#include "dockshortcut.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QSvgRenderer>

#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>

#define SHORTCUT_MARKER_KEY @"MoonlightShortcut"
#define ICON_SIZE 1024

static QString tr(const char* text)
{
    return QCoreApplication::translate("DockShortcut", text);
}

// Quotes a string for safe use as a single POSIX shell word
static QString shellQuote(const QString& str)
{
    QString escaped = str;
    escaped.replace('\'', "'\\''");
    return '\'' + escaped + '\'';
}

static QString sanitizeFileName(QString name)
{
    name.replace('/', '-');
    name.replace(':', '-');
    name = name.trimmed();
    if (name.startsWith('.')) {
        name.remove(0, 1);
    }
    return name.isEmpty() ? QStringLiteral("Moonlight Shortcut") : name;
}

static QImage renderIcon(const QString& appName, const QUrl& boxArt)
{
    QImage icon(ICON_SIZE, ICON_SIZE, QImage::Format_ARGB32_Premultiplied);
    icon.fill(Qt::transparent);

    QPainter painter(&icon);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    QImage art;
    if (appName.compare("Desktop", Qt::CaseInsensitive) != 0 && boxArt.isLocalFile()) {
        art.load(boxArt.toLocalFile());
    }

    if (art.isNull()) {
        QSvgRenderer renderer(QStringLiteral(":/res/dock-shortcut.svg"));
        renderer.render(&painter, QRectF(0, 0, ICON_SIZE, ICON_SIZE));
        return icon;
    }

    // Draw the box art into the standard macOS icon grid (824pt body, 185pt corners)
    QRectF body(100, 100, 824, 824);

    for (int i = 0; i < 3; i++) {
        painter.setPen(Qt::NoPen);
        painter.setBrush(QColor(0, 0, 0, 16 + i * 8));
        painter.drawRoundedRect(body.adjusted(-4 + i * 2, 16 - i * 4, 4 - i * 2, 24 - i * 8), 185, 185);
    }

    QPainterPath clip;
    clip.addRoundedRect(body, 185, 185);
    painter.setClipPath(clip);

    // Box art is portrait, so crop it to fill the square body. Keep the top, where most
    // covers put the game's logo, rather than cutting it off with a centered crop.
    QSizeF scaled = QSizeF(art.size()).scaled(body.size(), Qt::KeepAspectRatioByExpanding);
    QRectF target(body.center().x() - scaled.width() / 2, body.top(),
                  scaled.width(), scaled.height());
    painter.drawImage(target, art);

    painter.setClipping(false);
    painter.setPen(QPen(QColor(255, 255, 255, 30), 2));
    painter.setBrush(Qt::NoBrush);
    painter.drawRoundedRect(body.adjusted(1, 1, -1, -1), 184, 184);

    return icon;
}

static void writeIcon(const QString& bundlePath, const QString& appName, const QUrl& boxArt)
{
    QString iconPath = bundlePath + "/Contents/Resources/icon.png";
    if (renderIcon(appName, boxArt).save(iconPath)) {
        NSImage* image = [[[NSImage alloc] initWithContentsOfFile:iconPath.toNSString()] autorelease];
        if (image != nil) {
            [[NSWorkspace sharedWorkspace] setIcon:image forFile:bundlePath.toNSString() options:0];
        }
    }
}

static QString shortcutDirPath()
{
    return QDir::homePath() + "/Applications/Moonlight Shortcuts";
}

static NSString* moonlightBundleId()
{
    return NSBundle.mainBundle.bundleIdentifier ?: @"com.moonlight-stream.Moonlight";
}

static QString shortcutBundleId(const QString& hostUuid, const QString& appName)
{
    return QString::fromNSString(moonlightBundleId()) + ".shortcut." +
            QCryptographicHash::hash((hostUuid + '/' + appName).toUtf8(), QCryptographicHash::Sha1).toHex().left(12);
}

QString DockShortcut::create(const QString& hostUuid, const QString& hostName,
                            const QString& appName, const QUrl& boxArt, QString* bundlePathOut)
{ @autoreleasepool {
    QString label = appName.compare("Desktop", Qt::CaseInsensitive) == 0 ?
                hostName : QStringLiteral("%1 \u2013 %2").arg(hostName, appName);

    QDir shortcutDir(shortcutDirPath());
    if (!shortcutDir.mkpath(".")) {
        return tr("Unable to create %1").arg(shortcutDir.path());
    }

    QString bundlePath = shortcutDir.filePath(sanitizeFileName(label) + ".app");
    NSString* nsBundlePath = bundlePath.toNSString();
    NSURL* bundleUrl = [NSURL fileURLWithPath:nsBundlePath isDirectory:YES];

    NSString* moonlightId = moonlightBundleId();
    QString shortcutId = shortcutBundleId(hostUuid, appName);

    // Reuse an existing shortcut for this app, since it may already be in the Dock, but
    // replace one of the same name for a different app. Never touch anything we didn't create.
    if (QFileInfo::exists(bundlePath)) {
        NSDictionary* existing = [NSDictionary dictionaryWithContentsOfFile:[nsBundlePath stringByAppendingPathComponent:@"Contents/Info.plist"]];
        if (![existing[SHORTCUT_MARKER_KEY] boolValue]) {
            return tr("%1 already exists and is not a Moonlight shortcut.").arg(bundlePath);
        }
        if ([existing[@"CFBundleIdentifier"] isEqual:shortcutId.toNSString()]) {
            // Refresh the icon in case the box art or icon style changed
            writeIcon(bundlePath, appName, boxArt);
            *bundlePathOut = bundlePath;
            return QString();
        }
        QDir(bundlePath).removeRecursively();
    }

    QDir bundleDir(bundlePath);
    if (!bundleDir.mkpath("Contents/MacOS") || !bundleDir.mkpath("Contents/Resources")) {
        return tr("Unable to create %1").arg(bundlePath);
    }

    NSDictionary* plist = @{
        @"CFBundleExecutable": @"launch",
        @"CFBundleIdentifier": shortcutId.toNSString(),
        @"CFBundleName": label.toNSString(),
        @"CFBundleDisplayName": label.toNSString(),
        @"CFBundlePackageType": @"APPL",
        @"CFBundleShortVersionString": @"1.0",
        @"CFBundleVersion": @"1",
        @"LSUIElement": @YES,
        SHORTCUT_MARKER_KEY: @YES,
    };
    if (![plist writeToURL:[bundleUrl URLByAppendingPathComponent:@"Contents/Info.plist"] error:nil]) {
        return tr("Unable to write the shortcut's Info.plist");
    }

    // Launch a fresh Moonlight instance in CLI streaming mode. Prefer the Moonlight that created
    // the shortcut, since another copy with the same bundle ID may be installed, and fall back
    // to looking it up by bundle ID in case this copy has been moved.
    QString streamArgs = QStringLiteral("--args stream %1 %2").arg(shellQuote(hostUuid), shellQuote(appName));
    QString script = QStringLiteral("#!/bin/sh\n"
                                    "# Generated by Moonlight: streams \"%1\" from %2\n"
                                    "/usr/bin/open -n %5 %4 2>/dev/null ||\n"
                                    "    exec /usr/bin/open -n -b %3 %4\n")
            .arg(appName, hostName,
                 shellQuote(QString::fromNSString(moonlightId)), streamArgs,
                 shellQuote(QString::fromNSString(NSBundle.mainBundle.bundlePath)));

    QFile launcher(bundleDir.filePath("Contents/MacOS/launch"));
    if (!launcher.open(QIODevice::WriteOnly | QIODevice::Truncate) || launcher.write(script.toUtf8()) < 0) {
        return tr("Unable to write the shortcut's launcher");
    }
    launcher.close();
    launcher.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner |
                            QFileDevice::ReadGroup | QFileDevice::ExeGroup |
                            QFileDevice::ReadOther | QFileDevice::ExeOther);

    writeIcon(bundlePath, appName, boxArt);

    LSRegisterURL((CFURLRef)bundleUrl, true);

    *bundlePathOut = bundlePath;
    return QString();
}}
