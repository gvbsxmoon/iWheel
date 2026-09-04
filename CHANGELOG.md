# Changelog

All notable changes to iWheel are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.4.0] - 2026-09-04

### Added
- Scroll direction setting (Settings > Gestures), natural by default:
  natural slides the row like the system gesture, so moving left
  reaches the space on the right; inverted moves the highlight with
  your fingers, which was the previous behavior
- Dock carousel: with many spaces the row is capped at 75% of the
  screen and shifts to keep the highlight centered, with a fade on the
  overflowing sides, instead of spilling past the display edges
- Diagnostics section in Settings: the three permissions with live
  status and a button that opens the exact System Settings pane
- Failure messages are now plain language a non-technical user can act
  on (including the 10-space ceiling of macOS keyboard shortcuts), and
  a failed switch silently repairs the Mission Control hotkey and
  retries once before showing anything

### Changed
- Space previews are captured only in quiet moments: one shot per
  switch taken when the slide animation is over (no more
  half-transition frames), never while the switcher is on screen, and
  never behind the lock screen. Fixes previews attributed to the wrong
  space when switching quickly, the switcher appearing in its own
  previews, and stutter from captures competing with the animation
- The space number below the dock derives its distance from the zoomed
  card height, so large zooms no longer crowd it

### Removed
- The ring layout, with its picker and settings (ring size, movement
  threshold, dead zone). Spaces are ordered and the dock matches how
  Mission Control presents them; one layout, one mental model. Stored
  keys from the ring era are cleaned up at launch

### Fixed
- The switcher no longer opens invisibly behind Mission Control
- Previews for deleted spaces are pruned from memory

## [1.3.0] - 2026-09-03

### Added
- Navigate with 3 fingers (new default): hold 3 fingers to open, then
  keep sliding with the same 3 fingers - no lifting. Possible because
  system gestures are suppressed while the switcher is open. A
  "Navigate with" picker in Settings > Gestures switches back to the
  2-finger style

### Changed
- New defaults: Dock layout, card spacing 150pt, card size 120pt,
  elasticity 25% (values saved under the previous defaults migrate
  automatically)
- Copy no longer hardcodes "2 fingers"; the Help window shows the
  configured finger count

## [1.2.0] - 2026-09-03

### Added
- While the switcher is open, the system's own trackpad swipe gestures
  (Spaces swipe, Mission Control) are suppressed, so they can no longer
  fire mid-interaction. The suppression lives and dies with the overlay's
  event tap: gestures are fully native the instant it closes, and a swipe
  already in progress when it opens still completes natively. Uses the
  DockControl event interception technique proven by joshuarli/iss and
  mmathys/noswoosh - no system settings are touched

### Changed
- 3 fingers resting or moving while the switcher is open are now simply
  ignored (previously a 3-finger drift closed it to let the system
  gesture win - no longer needed)

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
