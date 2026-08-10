# Meloville

**A music player built for people who just want to listen to their music.**

## Screenshots

### Big Picture Mode

<img src="screenshots/bigpicture.png" alt="Meloville Now Playing" width="800">

### Music Library

<img src="screenshots/library.png" alt="Meloville Music Library" width="800">

### Playlists

<img src="screenshots/playlist.png" alt="Meloville Playlists" width="800">


### Albums

<img src="screenshots/albums.png" alt="Meloville Playlists" width="800">


## Features

* Support for mp3, flac, and ogg files
* Bluetooth headphone playback support
* In-built metadata editor for songs
* Auto sorting of albums
* Drag and drop songs to switch songs in playlists (Suprisingly a lot of other local music players don't have this)
* A "Big Picture" mode to see song covers in fullscreen
* Native Linux support
* Svg based UI assets so it looks grear even on on high DPI monitors

## Features That I Am Currently Working On

* Add a "listen along" feature where you can open a mini server and stream your current playing song to friends
* Lyrics Support
* Packages for arch and maybe a flatpak
* Themes

## Getting Started

### Prerequisites

You'll need:

* **CMake 3.16+**
* **Qt 6**
* **TagLib**
* **PulseAudio**

### Clone the repository

```bash
git clone https://github.com/NevPeth/meloville
cd meloville
```

### Build

```bash
mkdir build
cd build
cmake ../src && cmake --build .
```

### Run

```bash
./Meloville
```

## Contributing

Contributions are welcome!
Just let me know what was changed in the commit.
AI assissted contributions are allowed but if it is blatantly vibe-coded then it's getting rejected.

## Issues & Suggestions

For now there is no format.
Any issues can be sent without worrying about me being condescending like some other projects.
Just write your issue and I will help you to the best of my ability.
I want this project to last a long, long time.

## License

Meloville is released under the **GNU General Public License v3.0**.
Basically as long as your making an open source project, use it as you wish.

## Support the Project

If you find Meloville useful, consider giving the project a star on GitHub.