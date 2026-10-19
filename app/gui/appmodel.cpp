#include "appmodel.h"

#include <QSettings>

#include <climits>

#include "dockshortcut.h"

#include <QDrag>
#include <QMimeData>
#include <QPixmap>

AppModel::AppModel(QObject *parent)
    : QAbstractListModel(parent)
{
    connect(&m_BoxArtManager, &BoxArtManager::boxArtLoadComplete,
            this, &AppModel::handleBoxArtLoaded);
}

void AppModel::initialize(ComputerManager* computerManager, int computerIndex, bool showHiddenGames)
{
    m_ComputerManager = computerManager;
    connect(m_ComputerManager, &ComputerManager::computerStateChanged,
            this, &AppModel::handleComputerStateChanged);

    Q_ASSERT(computerIndex < m_ComputerManager->getComputers().count());
    m_Computer = m_ComputerManager->getComputers().at(computerIndex);
    m_CurrentGameId = m_Computer->currentGameId;
    m_ShowHiddenGames = showHiddenGames;

    for (const QString& id : QSettings().value(customOrderKey()).toStringList()) {
        m_CustomOrder.append(id.toInt());
    }

    updateAppList(m_Computer->appList);
}

int AppModel::getRunningAppId()
{
    return m_CurrentGameId;
}

QString AppModel::getRunningAppName()
{
    if (m_CurrentGameId != 0) {
        for (int i = 0; i < m_AllApps.count(); i++) {
            if (m_AllApps[i].id == m_CurrentGameId) {
                return m_AllApps[i].name;
            }
        }
    }

    return nullptr;
}

Session* AppModel::createSessionForApp(int appIndex)
{
    Q_ASSERT(appIndex < m_VisibleApps.count());
    NvApp app = m_VisibleApps.at(appIndex);

    return new Session(m_Computer, app);
}

int AppModel::getDirectLaunchAppIndex()
{
    for (int i = 0; i < m_VisibleApps.count(); i++) {
        if (m_VisibleApps[i].directLaunch) {
            return i;
        }
    }

    return -1;
}

int AppModel::rowCount(const QModelIndex &parent) const
{
    // For list models only the root node (an invalid parent) should return the list's size. For all
    // other (valid) parents, rowCount() should return 0 so that it does not become a tree model.
    if (parent.isValid())
        return 0;

    return m_VisibleApps.count();
}

QVariant AppModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return QVariant();

    Q_ASSERT(index.row() < m_VisibleApps.count());
    NvApp app = m_VisibleApps.at(index.row());

    switch (role)
    {
    case NameRole:
        return app.name;
    case RunningRole:
        return m_Computer->currentGameId == app.id;
    case BoxArtRole:
        // FIXME: const-correctness
        return const_cast<BoxArtManager&>(m_BoxArtManager).loadBoxArt(m_Computer, app);
    case HiddenRole:
        return app.hidden;
    case AppIdRole:
        return app.id;
    case DirectLaunchRole:
        return app.directLaunch;
    case AppCollectorGameRole:
        return app.isAppCollectorGame;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> AppModel::roleNames() const
{
    QHash<int, QByteArray> names;

    names[NameRole] = "name";
    names[RunningRole] = "running";
    names[BoxArtRole] = "boxart";
    names[HiddenRole] = "hidden";
    names[AppIdRole] = "appid";
    names[DirectLaunchRole] = "directLaunch";
    names[AppCollectorGameRole] = "appCollectorGame";

    return names;
}

void AppModel::quitRunningApp()
{
    m_ComputerManager->quitRunningApp(m_Computer);
}

bool AppModel::isAppCurrentlyVisible(const NvApp& app)
{
    for (const NvApp& visibleApp : std::as_const(m_VisibleApps)) {
        if (app.id == visibleApp.id) {
            return true;
        }
    }

    return false;
}

QVector<NvApp> AppModel::getVisibleApps(const QVector<NvApp>& appList)
{
    QVector<NvApp> visibleApps;

    for (const NvApp& app : appList) {
        // Don't immediately hide games that were previously visible. This
        // allows users to easily uncheck the "Hide App" checkbox if they
        // check it by mistake.
        if (m_ShowHiddenGames || !app.hidden || isAppCurrentlyVisible(app)) {
            visibleApps.append(app);
        }
    }

    return visibleApps;
}

void AppModel::updateAppList(QVector<NvApp> newList)
{
    m_AllApps = newList;

    QVector<NvApp> newVisibleList = getVisibleApps(applyCustomOrder(newList));

    // Process removals and updates first
    for (int i = 0; i < m_VisibleApps.count(); i++) {
        const NvApp& existingApp = m_VisibleApps.at(i);

        bool found = false;
        for (const NvApp& newApp : std::as_const(newVisibleList)) {
            if (existingApp.id == newApp.id) {
                // If the data changed, update it in our list
                if (existingApp != newApp) {
                    m_VisibleApps.replace(i, newApp);
                    emit dataChanged(createIndex(i, 0), createIndex(i, 0));
                }

                found = true;
                break;
            }
        }

        if (!found) {
            beginRemoveRows(QModelIndex(), i, i);
            m_VisibleApps.removeAt(i);
            endRemoveRows();
            i--;
        }
    }

    // Process additions now. The remaining apps are already in the new list's order,
    // so each new app goes in wherever the lists first differ.
    for (int i = 0; i < newVisibleList.count(); i++) {
        if (i >= m_VisibleApps.count() || m_VisibleApps.at(i).id != newVisibleList.at(i).id) {
            beginInsertRows(QModelIndex(), i, i);
            m_VisibleApps.insert(i, newVisibleList.at(i));
            endInsertRows();
        }
    }

    Q_ASSERT(newVisibleList == m_VisibleApps);
}

QString AppModel::customOrderKey()
{
    QReadLocker lock(&m_Computer->lock);
    return QStringLiteral("launcher/appOrder/") + m_Computer->uuid;
}

QVector<NvApp> AppModel::applyCustomOrder(QVector<NvApp> appList)
{
    if (m_CustomOrder.isEmpty()) {
        return appList;
    }

    // Apps the user hasn't arranged keep their alphabetical order, after the arranged ones
    std::stable_sort(appList.begin(), appList.end(), [this](const NvApp& app1, const NvApp& app2) {
        qsizetype rank1 = m_CustomOrder.indexOf(app1.id), rank2 = m_CustomOrder.indexOf(app2.id);
        return (rank1 < 0 ? INT_MAX : rank1) < (rank2 < 0 ? INT_MAX : rank2);
    });
    return appList;
}

void AppModel::moveApp(int fromIndex, int toIndex)
{
    if (fromIndex == toIndex || fromIndex < 0 || toIndex < 0 ||
            fromIndex >= m_VisibleApps.count() || toIndex >= m_VisibleApps.count()) {
        return;
    }

    // Move the app next to its new neighbor in the full list too, which keeps hidden
    // apps in place and the visible list in the same order as the full one
    int movedId = m_VisibleApps.at(fromIndex).id;
    int neighborId = m_VisibleApps.at(toIndex).id;

    QVector<int> order;
    for (const NvApp& app : applyCustomOrder(m_AllApps)) {
        if (app.id != movedId) {
            order.append(app.id);
        }
    }
    order.insert(order.indexOf(neighborId) + (toIndex > fromIndex ? 1 : 0), movedId);
    m_CustomOrder = order;

    // beginMoveRows() takes the destination index from before the move
    beginMoveRows(QModelIndex(), fromIndex, fromIndex, QModelIndex(), toIndex > fromIndex ? toIndex + 1 : toIndex);
    m_VisibleApps.move(fromIndex, toIndex);
    endMoveRows();

    QStringList ids;
    for (int id : std::as_const(m_CustomOrder)) {
        ids.append(QString::number(id));
    }
    QSettings().setValue(customOrderKey(), ids);
}

void AppModel::setAppHidden(int appIndex, bool hidden)
{
    Q_ASSERT(appIndex < m_VisibleApps.count());
    int appId = m_VisibleApps.at(appIndex).id;

    {
        QWriteLocker lock(&m_Computer->lock);

        for (NvApp& app : m_Computer->appList) {
            if (app.id == appId) {
                app.hidden = hidden;
                break;
            }
        }
    }

    m_ComputerManager->clientSideAttributeUpdated(m_Computer);
}

QString AppModel::dragAppToDock(int appIndex)
{
    Q_ASSERT(appIndex < m_VisibleApps.count());

    NvApp app = m_VisibleApps.at(appIndex);
    QString uuid, name;

    {
        QReadLocker lock(&m_Computer->lock);
        uuid = m_Computer->uuid;
        name = m_Computer->name;
    }

    QString bundlePath;
    QString error = DockShortcut::create(uuid, name, app.name, m_BoxArtManager.loadBoxArt(m_Computer, app), &bundlePath);
    if (!error.isEmpty()) {
        return error;
    }

    // Drag the shortcut's file URL, which the Dock accepts like an app dragged from Finder
    QMimeData* mimeData = new QMimeData();
    mimeData->setUrls({ QUrl::fromLocalFile(bundlePath) });

    // Lets the launcher recognize its own drags, so tiles can be rearranged by dropping them in the grid
    mimeData->setData(QStringLiteral("application/x-moonlight-app"), QByteArray::number(app.id));

    QDrag* drag = new QDrag(this);
    drag->setMimeData(mimeData);

    QPixmap icon(bundlePath + "/Contents/Resources/icon.png");
    if (!icon.isNull()) {
        // Show it at Dock icon size, and keep it sharp on Retina displays
        icon = icon.scaled(128, 128, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        icon.setDevicePixelRatio(2.0);
        drag->setPixmap(icon);
        drag->setHotSpot(QPoint(32, 32));
    }

    // Copy and link only, so dropping into a Finder window can't move the shortcut away
    drag->exec(Qt::CopyAction | Qt::LinkAction, Qt::LinkAction);
    return QString();
}

void AppModel::setAppDirectLaunch(int appIndex, bool directLaunch)
{
    Q_ASSERT(appIndex < m_VisibleApps.count());
    int appId = m_VisibleApps.at(appIndex).id;

    {
        QWriteLocker lock(&m_Computer->lock);

        for (NvApp& app : m_Computer->appList) {
            if (directLaunch) {
                // We must clear direct launch from all other apps
                // to set it on the new app.
                app.directLaunch = app.id == appId;
            }
            else if (app.id == appId) {
                // If we're clearing direct launch, we're done once we
                // find our matching app ID.
                app.directLaunch = false;
                break;
            }
        }
    }

    m_ComputerManager->clientSideAttributeUpdated(m_Computer);
}

void AppModel::handleComputerStateChanged(NvComputer* computer)
{
    // Ignore updates for computers that aren't ours
    if (computer != m_Computer) {
        return;
    }

    // If the computer has gone offline or we've been unpaired,
    // signal the UI so we can go back to the PC view.
    if (m_Computer->state == NvComputer::CS_OFFLINE ||
            m_Computer->pairState == NvComputer::PS_NOT_PAIRED) {
        emit computerLost();
        return;
    }

    // First, process additions/removals from the app list. This
    // is required because the new game may now be running, so
    // we can't check that first.
    if (computer->appList != m_AllApps) {
        updateAppList(computer->appList);
    }

    // Finally, process changes to the active app
    if (computer->currentGameId != m_CurrentGameId) {
        // First, invalidate the running state of newly running game
        for (int i = 0; i < m_VisibleApps.count(); i++) {
            if (m_VisibleApps[i].id == computer->currentGameId) {
                emit dataChanged(createIndex(i, 0),
                                 createIndex(i, 0),
                                 QVector<int>() << RunningRole);
                break;
            }
        }

        // Next, invalidate the running state of the old game (if it exists)
        if (m_CurrentGameId != 0) {
            for (int i = 0; i < m_VisibleApps.count(); i++) {
                if (m_VisibleApps[i].id == m_CurrentGameId) {
                    emit dataChanged(createIndex(i, 0),
                                     createIndex(i, 0),
                                     QVector<int>() << RunningRole);
                    break;
                }
            }
        }

        // Now update our internal state
        m_CurrentGameId = m_Computer->currentGameId;
    }
}

void AppModel::handleBoxArtLoaded(NvComputer* computer, NvApp app, QUrl /* image */)
{
    Q_ASSERT(computer == m_Computer);

    int index = m_VisibleApps.indexOf(app);

    // Make sure we're not delivering a callback to an app that's already been removed
    if (index >= 0) {
        // Let our view know the box art data has changed for this app
        emit dataChanged(createIndex(index, 0),
                         createIndex(index, 0),
                         QVector<int>() << BoxArtRole);
    }
    else {
        qWarning() << "App not found for box art callback:" << app.name;
    }
}
