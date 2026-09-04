/*
 * Adapted from Strawberry Music Player
 * Copyright 2018-2023, Jonas Kvinge <jonas@jkvinge.net>
 * Original source: https://github.com/strawberrymusicplayer/strawberry
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#include "scrobblercache.h"

#include <chrono>
#include <memory>

#include <QTimer>
#include <QFile>
#include <QSaveFile>
#include <QIODevice>
#include <QTextStream>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QDebug>

using namespace std::chrono_literals;
using std::make_shared;

ScrobblerCache::ScrobblerCache(const QString &filename, QObject *parent)
    : QObject(parent)
    , timer_flush_(new QTimer(this))
{
    // Store alongside other app caches
    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    filename_ = cacheDir + QLatin1Char('/') + filename;

    ReadCache();
    loaded_ = true;

    timer_flush_->setSingleShot(true);
    timer_flush_->setInterval(10min);
    connect(timer_flush_, &QTimer::timeout, this, &ScrobblerCache::WriteCache);
}

ScrobblerCache::~ScrobblerCache()
{
    // Flush immediately so scrobbles queued since the last timer tick aren't lost.
    if (!scrobbler_cache_.isEmpty())
        WriteCache();
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

void ScrobblerCache::ReadCache()
{
    QFile file(filename_);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    QTextStream stream(&file);
    stream.setEncoding(QStringConverter::Utf8);
    const QString data = stream.readAll();
    file.close();

    if (data.isEmpty())
        return;

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(data.toUtf8(), &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        qWarning() << "ScrobblerCache: JSON parse error:" << parseError.errorString();
        return;
    }
    if (!doc.isObject()) return;

    const QJsonObject root = doc.object();
    if (!root.contains(QLatin1String("tracks"))) return;

    const QJsonValue tracksVal = root[QLatin1String("tracks")];
    if (!tracksVal.isArray()) return;

    for (const QJsonValue &val : tracksVal.toArray()) {
        if (!val.isObject()) continue;
        const QJsonObject obj = val.toObject();

        // All of these are required — skip malformed entries.
        if (!obj.contains(QLatin1String("timestamp"))   ||
            !obj.contains(QLatin1String("artist"))      ||
            !obj.contains(QLatin1String("title"))       ||
            !obj.contains(QLatin1String("length_nsec")))
        {
            qWarning() << "ScrobblerCache: skipping incomplete cache entry";
            continue;
        }

        ScrobbleMetadata meta;
        const quint64 timestamp = obj[QLatin1String("timestamp")].toVariant().toULongLong();
        meta.artist       = obj[QLatin1String("artist")].toString();
        meta.album        = obj[QLatin1String("album")].toString();
        meta.albumartist  = obj[QLatin1String("albumartist")].toString();
        meta.title        = obj[QLatin1String("title")].toString();
        meta.track        = obj[QLatin1String("track")].toInt();
        meta.length_nsec  = obj[QLatin1String("length_nsec")].toVariant().toLongLong();

        if (timestamp == 0 || meta.artist.isEmpty() || meta.title.isEmpty() || meta.length_nsec <= 0) {
            qWarning() << "ScrobblerCache: invalid entry for song" << meta.title;
            continue;
        }

        scrobbler_cache_ << make_shared<ScrobblerCacheItem>(meta, timestamp);
    }
}

// ---------------------------------------------------------------------------
// Public slots
// ---------------------------------------------------------------------------

void ScrobblerCache::WriteCache()
{
    if (!loaded_) return;

    if (scrobbler_cache_.isEmpty()) {
        QFile file(filename_);
        if (file.exists()) file.remove();
        return;
    }

    QJsonArray array;
    for (const ScrobblerCacheItemPtr &item : std::as_const(scrobbler_cache_)) {
        QJsonObject obj;
        obj.insert(QLatin1String("timestamp"),   QJsonValue::fromVariant(item->timestamp));
        obj.insert(QLatin1String("artist"),      item->metadata.artist);
        obj.insert(QLatin1String("album"),       item->metadata.album);
        obj.insert(QLatin1String("albumartist"), item->metadata.albumartist);
        obj.insert(QLatin1String("title"),       item->metadata.title);
        obj.insert(QLatin1String("track"),       item->metadata.track);
        obj.insert(QLatin1String("length_nsec"), QJsonValue::fromVariant(item->metadata.length_nsec));
        array.append(obj);
    }

    QJsonObject root;
    root.insert(QLatin1String("tracks"), array);

    // QSaveFile: atomic write — a crash mid-write can't corrupt the cache.
    QSaveFile file(filename_);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "ScrobblerCache: cannot open for writing:" << filename_;
        return;
    }
    QTextStream stream(&file);
    stream.setEncoding(QStringConverter::Utf8);
    stream << QJsonDocument(root).toJson();
    stream.flush();
    if (!file.commit())
        qWarning() << "ScrobblerCache: commit failed for" << filename_;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

ScrobblerCacheItemPtr ScrobblerCache::Add(const ScrobbleMetadata &metadata, quint64 timestamp)
{
    auto item = make_shared<ScrobblerCacheItem>(metadata, timestamp);
    scrobbler_cache_ << item;
    if (loaded_ && !timer_flush_->isActive())
        timer_flush_->start();
    return item;
}

void ScrobblerCache::Remove(ScrobblerCacheItemPtr item)
{
    scrobbler_cache_.removeAll(item);
}

void ScrobblerCache::ClearSent(ScrobblerCacheItemPtrList items)
{
    for (auto &item : items)
        item->sent = false;
}

void ScrobblerCache::Flush(ScrobblerCacheItemPtrList items)
{
    for (auto &item : items)
        scrobbler_cache_.removeAll(item);

    WriteCache();

    if (!timer_flush_->isActive())
        timer_flush_->start();
}
