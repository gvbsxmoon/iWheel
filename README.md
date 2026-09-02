# iWheel

The natural way to switch desktops, inspired by the iPod click wheel.
Hold 3 fingers on the trackpad and your Spaces appear in a wheel.
Point with 2 fingers, release, you are there. One gesture, fingers
never leaving the trackpad.

Built for people who run many desktops and are tired of swiping
across half of them to reach the other half. Up to 10 Spaces.

![iWheel demo](assets/demo.gif)

## System requirements

- **Tested on**: macOS 26, Apple Silicon. That is the only verified
  combination.
- The public-API floor is macOS 14, so it *builds* for Sonoma and later,
  but iWheel depends on private frameworks whose behavior was only
  verified on macOS 26 - on older versions it may work, degrade, or not
  start. Reports welcome.
- Intel is untested: the app reads a private multitouch struct whose
  layout has only been validated on arm64 (out-of-range frames are
  dropped defensively, so worst case is a dead wheel, not a crash)
- A built-in trackpad or Magic Trackpad

## Install

**Download**: grab `iWheel-x.y.z.zip` from the Releases page, unzip,
move `iWheel.app` to `/Applications`, open it. The app is ad-hoc signed:
on first open, right-click > Open to get past Gatekeeper.

**Build from source**:

```sh
git clone https://github.com/gvbsxmoon/iWheel.git
cd iWheel
scripts/release.sh        # produces build/iWheel.app + release zip
open build/iWheel.app
```

On first launch macOS asks for three permissions (see
[Privacy & permissions](#privacy--permissions)). Grant them, then
restart the app. To start it at every login, flip "Open at login" in
Settings.

## How to use it

| Gesture | Action |
|---|---|
| Rest 3 fingers still (~0.15s) | Open the wheel |
| Point with 2 fingers | Highlight the desktop in that direction |
| Tab / Shift+Tab | Step the highlight one desktop at a time |
| Release | Switch to the highlighted desktop |
| Release without moving | Nothing happens (cancel) |
| Quick 3-finger swipe | Your normal macOS switch - iWheel steps aside |

Pointing is relative to where your fingers were when the wheel opened,
so small movements are enough. The pointer is hidden and clicks/scrolls
do not reach the apps underneath while the wheel is open.

Desktop previews are cached snapshots (like Mission Control's own
thumbnails): each desktop shows how it looked the last time you were
there. A desktop you have not visited yet shows a numbered placeholder.

## Settings

Click the menu bar icon (circle in a circle) > Settings. Every control
has a plain-language description: activation hold, movement threshold,
dead zone, haptic strength, ring size, highlight zoom.

Preferences are stored in `~/Library/Preferences/iWheel.plist`.

## Privacy & permissions

iWheel needs three permissions, each for one specific job:

- **Input Monitoring** - reads the raw trackpad stream (finger positions
  only). This is how the wheel knows where your fingers are.
- **Accessibility** - posts the synthetic ctrl+N keystroke that performs
  the actual desktop switch, and runs the event filter below.
- **Screen Recording** - takes the desktop snapshots used as previews.

**The keyboard filter, stated plainly:** while the wheel is open (and
only then), iWheel installs an event tap that swallows pointer events
and watches for the Tab key. Key codes are inspected in memory to catch
Tab; they are never stored, logged, or transmitted. The tap is torn
down when the wheel closes and dies with the process.

**Previews:** snapshots live in RAM only, are never written to disk,
never leave your machine, and are purged when the screen locks or
sleeps.

**System settings it touches:** if your "Switch to Desktop N" shortcuts
(System Settings > Keyboard > Shortcuts > Mission Control) are disabled
- the default on new Macs - iWheel enables them, because they are the
mechanism it switches with. It never deletes or modifies any other
shortcut, and never touches your trackpad gesture settings.

**No network, no analytics, no telemetry.** The app makes zero network
connections.

iWheel uses two private frameworks (MultitouchSupport for raw touches,
SkyLight for the Spaces list and cursor hiding). Consequences: it cannot
be sandboxed or distributed on the App Store, and each major macOS
release needs re-verification. See [SECURITY.md](SECURITY.md).

## Known limitations

- Max 10 desktops reachable (ctrl+1..9 and ctrl+0 have no defaults
  beyond that)
- Single display: with multiple monitors the wheel shows and switches
  the first display's Spaces
- Fullscreen-app Spaces are not shown (they have no ctrl+N shortcut)
- The binary is unsigned: macOS ties permissions to the code hash, so
  rebuilding may reset them - re-grant and relaunch

## Troubleshooting

1. **It keeps asking for permissions after every rebuild/reinstall**:
   macOS ties permissions to the code signature, and ad-hoc signatures
   change on every build - the toggles look on but no longer match.
   Fix for source builds: run `scripts/make-signing-cert.sh` once (it
   creates a stable local signing identity), rebuild, then reset the
   stale entries with `tccutil reset All dev.lucanatale.iWheel` and
   re-grant once. Permissions then persist across rebuilds.
2. **The wheel does not appear**: check Input Monitoring permission,
   then relaunch. Run from a terminal and watch the log lines.
3. **The wheel appears but release does not switch**: iWheel repairs the
   Mission Control shortcuts automatically on first use; if it still
   fails, check System Settings > Keyboard > Shortcuts > Mission Control
   and the Accessibility permission. The on-screen message tells you
   which one is missing.
4. **Permissions look granted but nothing works**: remove iWheel from
   each permission list (minus button), re-add it, relaunch.
5. **A system gesture stopped working after a crash of an old build**:
   check System Settings > Trackpad > More Gestures. Current versions
   never modify gesture settings.

## Uninstall

Quit iWheel, delete the binary/checkout, then remove:

```sh
defaults delete iWheel 2>/dev/null
```

and remove iWheel from Privacy & Security > Input Monitoring /
Accessibility / Screen Recording.

## License

[MIT](LICENSE) - Luca Natale
