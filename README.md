# TopNotchCompat

A native macOS menu-bar utility for making the menu bar black on modern macOS without covering Apple's menu text or status items.

TopNotchCompat is inspired by the behavior of [TopNotch](https://topnotch.app), but it is an independent implementation and does not copy TopNotch's copyrighted resources, EULA, promotional content, or update service.

## What it does

- Creates a screen-sized copy of the current wallpaper and paints the menu-bar region black.
- Keeps Apple's menu text, menu extra icons, and mouse handling untouched.
- Bakes a smooth arc into the wallpaper beside full-screen app corners, avoiding an overlay-window flicker when switching Spaces.
- Supports static images and multi-frame HEIC dynamic wallpapers.
- Restores the active Space's original wallpaper when disabled or on quit.
- Provides a TopNotch-style menu-bar popover and gear menu.

## Requirements

- macOS 13 or newer
- An Xcode toolchain capable of building Swift 5.9 packages
- A notched built-in display for the default MacBook-screen-only mode

## Install and run

1. Download and unpack `TopNotchCompat-v1.0-macOS.zip` from the release.
2. Move `TopNotchCompat.app` to `/Applications`.
3. Quit the original TopNotch if it is running.
4. Open TopNotchCompat and accept the startup notice.

The app runs as a menu-bar-only application. Its derived wallpapers are stored under:

```text
~/Library/Application Support/TopNotchCompat/
```

Original wallpaper files are never modified. Quitting restores the wallpaper on the currently active desktop. macOS exposes wallpaper state only for the active Space, so visit a desktop once so TopNotchCompat can prepare its wallpaper; subsequent switches use the generated image.

## Build from source

Accept the Xcode license once if `swift` reports it:

```sh
sudo xcodebuild -license
```

Build the app:

```sh
Scripts/build-app.sh
open build/TopNotchCompat.app
```

Run tests:

```sh
swift test
```

## Create a release archive

```sh
Scripts/package-release.sh
```

The script rebuilds the app and writes:

```text
dist/TopNotchCompat-v1.0-macOS.zip
```

## Troubleshooting

- **The original wallpaper returns after switching Space:** switch to that Space and wait for TopNotchCompat to process it once.
- **The wallpaper is not restored:** disable the main switch, wait for restoration, then quit. The original file remains unchanged on disk.
- **The menu icon is hidden:** launch the app again from `/Applications`; the icon appears for ten seconds.
- **Another wallpaper utility is enabled:** quit utilities such as the original TopNotch before enabling TopNotchCompat.

## Build

See [Build from source](#build-from-source).
