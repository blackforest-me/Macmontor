# Macmontor

Macmontor is a lightweight macOS desktop widget for watching system performance while you work.

![Macmontor cover](Assets/macmontor-cover.svg)

## Features

- Real-time CPU usage
- Memory usage and memory pressure
- Network download and upload speed
- Reclaimable file cache
- Free disk space
- Top CPU processes
- Compact and detail layouts
- Frosted glass desktop widget style
- Draggable window with saved position

## Requirements

- macOS 14 or later
- Swift 6 toolchain

## Build

```bash
swift build -c release
scripts/package_app.sh
open dist/Macmontor.app
```

## Release Package

Create a local zip package for distribution:

```bash
scripts/release_zip.sh
```

The generated file is written to `dist/Macmontor-v<version>.zip`.

## Development

Run from source:

```bash
swift run
```

Regenerate the app icon after editing `scripts/generate_icon.swift`:

```bash
scripts/generate_app_icon.sh
```

## License

MIT
