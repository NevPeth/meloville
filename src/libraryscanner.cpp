#include "libraryscanner.h"
#include "metadatareader.h"
#include <QDir>
#include <QFileInfo>
#include <QCoreApplication>
#include <algorithm>

LibraryScanner::LibraryScanner(QObject *parent) : QObject(parent) {}

void LibraryScanner::setCacheDir(const QString &cacheDir)
{
    m_cacheDir = cacheDir;
}

void LibraryScanner::setFolderPath(const QString &folderPath)
{
    m_folderPath = folderPath;
}

void LibraryScanner::start()
{
    QDir dir(m_folderPath);
    QStringList filters = {"*.mp3", "*.flac", "*.wav", "*.m4a", "*.aac", "*.ogg"};
    QFileInfoList files = dir.entryInfoList(filters, QDir::Files);

    QVector<SongData> library;
    library.reserve(files.size());

    int total = files.size();
    for (int i = 0; i < total; ++i) {
        const QFileInfo &fileInfo = files.at(i);
        SongData song = MetadataReader::readSong(fileInfo.absoluteFilePath());
        song.coverPath = MetadataReader::cacheCoverArt(song.filePath, m_cacheDir, fileInfo.baseName());
        library.append(song);
        emit progress(i + 1, total);

        // Keep the UI responsive
        QCoreApplication::processEvents(QEventLoop::AllEvents, 100);
    }

    std::sort(library.begin(), library.end(),
              [](const SongData &a, const SongData &b) {
                  return QString::compare(a.title, b.title, Qt::CaseInsensitive) < 0;
              });

    emit finished(library, m_folderPath);
}