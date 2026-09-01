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

#ifndef SCROBBLERCACHE_H
#define SCROBBLERCACHE_H

#include <QObject>
#include <QList>
#include <QString>

#include "scrobblercacheitem.h"

class QTimer;

// Persists pending scrobbles to a JSON file so they survive app restarts.
// A flush timer batches writes (10 min idle) rather than hitting disk on
// every scrobble; an immediate write happens on destruction so nothing is lost.
class ScrobblerCache : public QObject {
    Q_OBJECT

public:
    explicit ScrobblerCache(const QString &filename, QObject *parent = nullptr);
    ~ScrobblerCache() override;

    ScrobblerCacheItemPtr Add(const ScrobbleMetadata &metadata, quint64 timestamp);
    void Remove(ScrobblerCacheItemPtr item);
    void ClearSent(ScrobblerCacheItemPtrList items);
    void Flush(ScrobblerCacheItemPtrList items);  // removes + schedules write

    int Count() const { return scrobbler_cache_.size(); }
    ScrobblerCacheItemPtrList List() const { return scrobbler_cache_; }

public slots:
    void WriteCache();

private:
    void ReadCache();
    QTimer *timer_flush_;
    QString filename_;
    bool loaded_ = false;
    ScrobblerCacheItemPtrList scrobbler_cache_;
};

#endif // SCROBBLERCACHE_H
