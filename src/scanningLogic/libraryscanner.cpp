#include "libraryscanner.h"
#include "metadatareader.h"
#include <QDir>
#include <QFileInfo>
#include <QCoreApplication>
#include <algorithm>

static QFileInfoList collectFiles(const QString &dirPath)
{
    static const QStringList filters = {
        "*.mp3", "*.flac", "*.wav", "*.m4a", "*.aac", "*.ogg"
    };

    QFileInfoList result;
    QDir dir(dirPath);

    result += dir.entryInfoList(filters, QDir::Files);

    const QFileInfoList subdirs = dir.entryInfoList(
        QDir::Dirs | QDir::NoDotAndDotDot | QDir::NoSymLinks //No sym links avoids infinite loops in case of circular links
    );
    for (const QFileInfo &sub : subdirs)
        result += collectFiles(sub.absoluteFilePath());

    return result;
}

LibraryScanner::LibraryScanner(QObject *parent) : QObject(parent) {}

void LibraryScanner::setCacheDir(const QString &cacheDirectory)
{
    cacheDir = cacheDirectory;
}

void LibraryScanner::setFolderPath(const QString &m_folderPath)
{
    folderPath = m_folderPath;
}

void LibraryScanner::start()
{
    const QFileInfoList files = collectFiles(folderPath);

    QVector<SongData> library;
    library.reserve(files.size());

    const int total = files.size();
    for (int i = 0; i < total; ++i) {
        const QFileInfo &fileInfo = files.at(i);
        SongData song = MetadataReader::readSong(fileInfo.absoluteFilePath());
        song.coverPath = MetadataReader::cacheCoverArt(
            song.filePath, cacheDir, fileInfo.baseName()
        );
        library.append(song);
        emit progress(i + 1, total);

        QCoreApplication::processEvents(QEventLoop::AllEvents, 100);
    }

    std::sort(library.begin(), library.end(),
              [](const SongData &a, const SongData &b) {
                  return QString::compare(a.title, b.title, Qt::CaseInsensitive) < 0;
              });

    emit finished(library, folderPath);
}