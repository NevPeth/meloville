/*
 * Adapted from Strawberry Music Player
 * Copyright 2018-2025, Jonas Kvinge <jonas@jkvinge.net>
 * Original source: https://github.com/strawberrymusicplayer/strawberry
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */
#ifndef LISTENBRAINZSCROBBLER_H
#define LISTENBRAINZSCROBBLER_H

#include "scrobblercache.h"
#include "scrobblercacheitem.h"
#include <QObject>
#include <QString>
#include <QTimer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>

// Scrobbles to ListenBrainz using a user-supplied API token (no OAuth).
// The token is stored in QSettings under "listenbrainz/userToken".
class ListenBrainzScrobbler : public QObject
{
    Q_OBJECT
public:
    explicit ListenBrainzScrobbler(QObject *parent = nullptr);
    ~ListenBrainzScrobbler() override;

    bool isAuthenticated() const;
    QString username() const { return username_; }

    // Call after the user pastes a new token in Settings.
    void setToken(const QString &token);
    void logout();

    void notifySongStarted(const QString &title,
                           const QString &artist,
                           const QString &album,
                           int durationSec);

    void startScrobbleFromBoot(const QString &title,
                               const QString &artist,
                               const QString &album,
                               int durationSeconds);
    
    void notifySongScrobble(); // call at the 50 % / 4-min threshold
    void notifySongStopped(); // call on skip / stop before threshold
    void notifySongPaused();
    void notifySongResumed();
    void saveSettings();

signals:
    void authChanged(); // token validated or cleared
    void errorOccurred(const QString &message);

private slots:
    void submitNowPlaying();
    void submitScrobbles();
    void onValidateFinished(QNetworkReply *reply);
    void onNowPlayingFinished(QNetworkReply *reply);
    void onScrobbleFinished(QNetworkReply *reply, ScrobblerCacheItemPtrList items);

private:
    QNetworkReply *post(const QString &endpoint, const QJsonDocument &doc);
    QJsonObject trackMetadata(const QString &title,
                              const QString &artist,
                              const QString &album,
                              qint64 durationNsec) const;
    void validateToken();
    void loadSettings();

    QNetworkAccessManager *nam_;
    ScrobblerCache *cache_;
    QTimer *submitTimer_;
    QTimer *scrobbleTimer_;

    bool paused_ = false;
    int scrobbleTimerRemainingMs_ = 0; // ms remaining when paused
    qint64 pauseStartTimestamp_ = 0;

    QString token_;
    QString username_;
    bool authenticated_ = false;

    // Currently-tracked song state
    QString currentTitle_;
    QString currentArtist_;
    QString currentAlbum_;
    qint64 currentDurationNsec_ = 0;
    quint64 currentTimestamp_ = 0;
    bool scrobbled_ = false;
};

#endif // LISTENBRAINZSCROBBLER_H