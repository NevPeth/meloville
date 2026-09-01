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

#ifndef SCROBBLERCACHEITEM_H
#define SCROBBLERCACHEITEM_H

#include <memory>
#include <QtGlobal>
#include <QString>

// Lightweight metadata struct holding only what Last.fm needs.
// Stripped down from Strawberry's ScrobbleMetadata — no MusicBrainz IDs,
// no streaming-service fields, since SongData doesn't carry those.
struct ScrobbleMetadata {
    QString title;
    QString album;
    QString artist;
    QString albumartist;
    int track = 0;
    qint64 length_nsec = 0;  // nanoseconds (duration_s * 1'000'000'000)

    QString effectiveAlbumArtist() const {
        return albumartist.isEmpty() ? artist : albumartist;
    }
};

struct ScrobblerCacheItem {
    explicit ScrobblerCacheItem(const ScrobbleMetadata &meta, quint64 ts)
        : metadata(meta), timestamp(ts) {}

    ScrobbleMetadata metadata;
    quint64 timestamp = 0;
    bool sent = false;
    bool error = false;
};

using ScrobblerCacheItemPtr      = std::shared_ptr<ScrobblerCacheItem>;
using ScrobblerCacheItemPtrList  = QList<ScrobblerCacheItemPtr>;

#endif // SCROBBLERCACHEITEM_H
