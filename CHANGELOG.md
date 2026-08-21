# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-08-21

### Changed

- Removed the CPU history graph; CPU is shown as a single row with its current value and usage bar
- Refreshed the preview screenshot to show the current popup, including the alarming state on high temperature

## [1.2.1] - 2026-08-21

### Added

- Level indicators on graphs: dashed 50%/100% gridlines with live value labels that follow the auto-scaling peak, so a full-looking graph can be read against its actual scale (e.g. KB/s for network)

### Changed

- Preview image switched from an oversized PNG to an optimized JPEG (`preview.jpg`)

## [1.2.0] - 2026-08-21

### Added

- CPU history graph and persistent 60-second network/CPU history that survives popup close/open cycles without growing memory
- Uptime in the hero header ("Up 1h 30m")
- Per-widget settings read from the shell.json layout entry: `refreshMs`, `historySeconds`, `showDisks`, `showNetwork`
- Network speed now tracks the interface owning the default route, so VPN tunnels (Tailscale, WARP, ...) are no longer double-counted; falls back to summing non-virtual interfaces

### Fixed

- Excluded `/boot` and EFI mounts from the DISK section

## [1.1.0] - 2026-08-21

### Added

- Disk usage section: one labeled bar per real mounted filesystem (root first, capped at 5)
- Live network throughput (down/up) measured across the sampling window via `/proc/net/dev`
- Horizontal usage bars throughout the popup, following the Omarchy agents panel meter pattern
- Alarming states: rows and bars turn urgent at 90% usage / 80°C

## [1.0.0] - 2026-08-19

### Added

- Initial release: bar widget with hover/click popup showing live CPU, temperature, memory, and swap
- Left-click pin, middle-click refresh, right-click launch of `btop`
