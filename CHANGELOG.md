# Changelog

All notable changes to iWheel are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.0] - 2026-09-03

### Added
- Configurable open shortcut: record any combination including cmd,
  option or control from Settings (default ctrl+option+cmd+W)
- Help window in the menu, explaining the whole flow in plain language
- Global keyboard shortcut ctrl+option+cmd+W: opens the switcher in
  latched mode - it stays open with no fingers down. Point with 2
  fingers or step with Tab, then release or press Return to switch,
  Esc to close. Registered via Carbon RegisterEventHotKey, so no
  keyboard event tap exists while the wheel is closed
- Card size setting: the base size of desktop cards is now configurable
- Dock layout: card spacing setting; the panel width adapts to it
- `scripts/install.sh`: one-shot local install (signing identity, build,
  replace /Applications copy, permission reset only on signature change,
  relaunch)
- Dock layout option in Settings: desktops in a horizontal row with
  dock-style magnification, same gesture (hold 3, point with 2, release)
- Esc closes the wheel without switching
- The current desktop's preview refreshes the moment the wheel opens
  (iWheel's own windows are excluded from the capture)

### Changed
- New app icon: three space cards in a cascade; the menu bar icon now
  mirrors it
- README narrative reworked around one-continuous-motion switching; the
  iPod click wheel stays as the origin of the name
- Dock: new Elasticity setting replaces the movement threshold - it sets
  how much trackpad travel slides through all spaces, and the default is
  half the previous travel (much snappier)
- All UI copy now says "space" instead of "desktop", "slide" instead of
  "point"; Help mentions only Tab and clarifies when Return is needed
- Help menu item shows a question mark icon
- Dock: neighbors slide outward as the highlight zooms, keeping the gap
  between cards constant
- New defaults and ranges: card size 100pt (60-140), card spacing
  100-220pt (default 120), highlight zoom up to 2.5x
- The movement threshold now applies to the dock layout too (converted
  to card units); the center dead zone is wheel-only and hidden in dock
- Settings reorganized: Navigation moved below Appearance
- Settings adapt to the selected layout (Ring size for wheel, Card
  spacing for dock); dock cards are uniform in size and centered on one
  line, with only the highlight enlarging
- The highlighted card always renders above its neighbors, and unfocused
  cards are desaturated and dimmed, so high zoom with many desktops no
  longer reads as overlapping clutter

### Fixed
- Signing cert creation failed with Homebrew OpenSSL 3 in PATH (PKCS12
  rejected by the keychain); the script now uses the system LibreSSL and
  is idempotent across interrupted runs
- Stale comments left over from earlier interaction models

## [1.0.0] - 2026-09-03

First public release.

### Added
- Wheel of desktop cards on a 3-finger stationary hold, pointing with
  2 fingers, release to switch; native macOS gestures untouched
- Hand-relative pointing center (the wheel centers where your fingers are)
- Mission Control style cached previews, wallpaper placeholders for
  unvisited desktops, purged on screen lock and sleep
- Haptic detents, Tab / Shift+Tab navigation with post-Tab position lock
- Automatic repair of disabled "Switch to Desktop N" shortcuts
- Menu bar Settings: activation hold, movement threshold, dead zone,
  haptics, ring size, highlight zoom, open at login (SMAppService)
- Release tooling: .app bundle build, stable local signing identity so
  TCC permissions survive rebuilds
