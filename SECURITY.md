# Security

## Supported versions

The only verified configuration is the latest macOS major version on
Apple Silicon (currently macOS 26 / arm64); that is also the only one
that receives fixes. iWheel depends on two private Apple frameworks
(MultitouchSupport, SkyLight) and the `com.apple.symbolichotkeys`
preference schema: the public-API floor of macOS 14 means older systems
can build and launch it, but private-API behavior there is unverified.

## Threat model - what iWheel can do and what it does

**Session event tap (the sensitive one).** While the wheel overlay is
open, iWheel runs a `CGEventTap` that swallows pointer events, inspects
key codes to catch Tab, Return and Esc, and suppresses the system's own
trackpad swipe gestures (Spaces swipe, Mission Control) so they cannot
fire mid-interaction. This is technically a keyboard interception point,
so the guarantees are explicit:

- the tap exists only between wheel-open and wheel-close;
- key codes are compared against Tab, Return and Esc in memory and never
  stored, logged, or transmitted; all other keys pass through untouched;
- gesture suppression only swallows swipes that BEGIN while the wheel is
  open; one already in flight completes natively;
- if macOS disables the tap (timeout / user input), it is re-enabled or
  input simply flows normally - it can never eat input while closed;
- a crash kills the tap with the process (macOS removes taps of dead
  processes).

**Desktop snapshots.** ScreenCaptureKit previews are RAM-only, never
persisted, purged on screen lock and display sleep.

**Preference writes.** iWheel writes exactly one system domain:
`com.apple.symbolichotkeys`, to enable disabled "Switch to Desktop N"
entries. The write is additive (never deletes entries) and is skipped
entirely if the domain reads back empty, so a transient read failure
cannot wipe user shortcuts. Applying changes runs Apple's own
`activateSettings` binary with fixed arguments (no shell, no
user-controlled input).

**Synthetic input.** Desktop switching posts ctrl+digit key events via
`CGEvent` (Accessibility permission). No other synthetic input is ever
generated.

**Network.** None. The app links no networking framework and makes no
connections.

## Reporting a vulnerability

Open a GitHub security advisory (preferred) or an issue with the
`security` label. Include macOS version, iWheel commit, and steps to
reproduce. You should get a response within a week.
