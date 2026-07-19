#ifndef LIBRARYSCANNER_H
#define LIBRARYSCANNER_H

#include <QObject>
#include <QVector>
#include "songdata.h"

class LibraryScanner : public QObject
{
    Q_OBJECT
public:
    explicit LibraryScanner(QObject *parent = nullptr);

    void setCacheDir(const QString &cacheDir);
    void setFolderPath(const QString &folderPath);

public slots:
    void start();

signals:
    void progress(int current, int total);
    void finished(const QVector<SongData> &songs, const QString &folderPath);
    void error(const QString &message);

private:
    QString m_cacheDir;
    QString m_folderPath;
};

#endif // LIBRARYSCANNER_H