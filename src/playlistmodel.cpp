#include "playlistmodel.h"
#include "playlistmanager.h"

PlaylistModel::PlaylistModel(PlaylistManager *manager, QObject *parent)
    : QAbstractListModel(parent)
    , m_manager(manager)
{
    // Connect to all signals that affect the playlist list
    connect(m_manager, &PlaylistManager::playlistCreated, this, &PlaylistModel::refresh);
    connect(m_manager, &PlaylistManager::playlistDeleted, this, &PlaylistModel::refresh);
    connect(m_manager, &PlaylistManager::playlistChanged, this, &PlaylistModel::refresh);

    refresh(); // load initial data
}

int PlaylistModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_playlistNames.size();
}

QVariant PlaylistModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_playlistNames.size())
        return QVariant();

    const QString &name = m_playlistNames.at(index.row());

    switch (role) {
    case NameRole:
        return name;
    case ImagePathRole: {
        // Return a full file:// URL so QML can use it directly
        QString path = m_manager->fullImagePath(name);
        if (!path.isEmpty() && !path.startsWith("file://"))
            path = "file:///" + path;
        return path;
    }
    case TitleFontSizeRole:
        return m_manager->playlistTitleFontSize(name);
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> PlaylistModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {ImagePathRole, "imagePath"},
        {TitleFontSizeRole, "titleFontSize"}
    };
}

void PlaylistModel::refresh()
{
    beginResetModel();
    m_playlistNames = m_manager->playlistNames();
    endResetModel();
}