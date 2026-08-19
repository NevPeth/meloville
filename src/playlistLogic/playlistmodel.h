#ifndef PLAYLISTMODEL_H
#define PLAYLISTMODEL_H

#include <QAbstractListModel>
#include <QVector>
#include <QString>

class PlaylistManager;

class PlaylistModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        ImagePathRole
    };

    explicit PlaylistModel(PlaylistManager *manager, QObject *parent = nullptr);

    // QAbstractListModel overrides
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

public slots:
    void refresh(); // called whenever the playlist list changes

private:
    PlaylistManager *m_manager;
    QStringList m_playlistNames;
};

#endif // PLAYLISTMODEL_H