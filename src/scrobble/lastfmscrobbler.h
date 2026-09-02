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

#ifndef LASTFMSCROBBLER_H
#define LASTFMSCROBBLER_H

#include <QObject>
#include <QString>
#include <QList>
#include <QPair>
#include <QByteArray>

#include "scrobblercache.h"
#include "scrobblercacheitem.h"

class QTimer;
class QNetworkAccessManager;
class QNetworkReply;

class LastFmScrobbler : public QObject {
    Q_OBJECT

public:
    explicit LastFmScrobbler(const QString &apiKey,
                             const QString &apiSecret,
                             QObject *parent = nullptr);
    ~LastFmScrobbler() override;

    // ---------- Auth ----------
    bool isAuthenticated() const { return !username_.isEmpty() && !sessionKey_.isEmpty(); }
    QString username() const { return username_; }

    void authenticate(); // opens browser, waits for redirect
    void logout();

    // ---------- Playback events ----------
    // Call this from MainWindow::playSong().
    // durationSeconds: song length (used to decide when the scrobble threshold is reached).
    void notifySongStarted(const QString &title,
                           const QString &artist,
                           const QString &album,
                           int durationSeconds);

    void startScrobbleFromBoot(const QString &title,
                               const QString &artist,
                               const QString &album,
                               int durationSeconds);

    // Call when the user stops / the app closes.
    void notifyStopped();
    
    //Pause or resume timer. Instead of going off of the position of the progress
    //bar, to scrobble we need to know how long the song has been playing, hence the timer
    void notifyPaused();
    void notifyResumed();

    void saveSession();

    void love(); // loves the currently-playing song (may add later)

signals:
    void authenticationComplete(bool success, const QString &error = {});
    void errorOccurred(const QString &message);

private slots:
    void onRedirectArrived();
    void onSessionReplyFinished(QNetworkReply *reply);
    void onNowPlayingReplyFinished(QNetworkReply *reply);
    void onScrobbleReplyFinished(QNetworkReply *reply, ScrobblerCacheItemPtrList sent);
    void onLoveReplyFinished(QNetworkReply *reply);
    void submitCache();

private:
    // ---------- Networking ----------
    using Param        = QPair<QString, QString>;
    using ParamList    = QList<Param>;

    QNetworkReply *postRequest(const ParamList &params);
    QNetworkReply *getRequest(const QUrl &url);

    QString buildSignature(const ParamList &params) const;

    // ---------- Session ----------
    void loadSession();
    void requestSession(const QString &token);

    // ---------- Scrobbling ----------
    void updateNowPlaying();
    void scheduleScrobble();    // sets the scrobble timer based on song duration
    void scrobbleCurrentSong(); // adds to cache, triggers submit
    void startSubmit(bool initial = false);

    // ---------- Helpers ----------
    static QByteArray md5(const QString &data);
    void emitError(const QString &msg);

    // ---------- Members ----------
    QNetworkAccessManager *network_;
    ScrobblerCache        *cache_;

    QString apiKey_;
    QString apiSecret_;

    QString username_;
    QString sessionKey_;

    // Current song
    QString currentTitle_;
    QString currentArtist_;
    QString currentAlbum_;
    int currentDurationSec_ = 0;
    qint64 playStartTimestamp_ = 0;  // unix seconds when song started
    bool scrobbled_ = false;

    // Local redirect server for OAuth token receipt
    class LocalServer;
    LocalServer *localServer_ = nullptr;

    QTimer *scrobbleTimer_; // fires when scrobble threshold reached
    QTimer *submitTimer_; // delayed submit after transient error
    bool submitPending_ = false;
    bool submitError_ = false;

    bool paused_ = false;
    int scrobbleTimerRemainingMs_ = 0; // ms remaining when paused
    qint64 pauseStartTimestamp_ = 0;

    QList<QNetworkReply *> pendingReplies_;

    static constexpr int kScrobblesPerRequest = 50;
    static constexpr const char *kApiUrl = "https://ws.audioscrobbler.com/2.0/";
    static constexpr const char *kAuthUrl = "https://www.last.fm/api/auth/";
    static constexpr const char *kCacheFile = "lastfm_scrobbler.cache";
};

#endif // LASTFMSCROBBLER_H
