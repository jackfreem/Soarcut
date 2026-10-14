# Changelog

## 0.1.0 (unreleased)

First release of Soarcut, a fork of [Flycut](https://github.com/TermiT/Flycut) 1.9.7
continuing the Jumpcut → Flycut lineage.

- Fixed the bezel getting stuck on screen when a system prompt or another app takes
  focus while it's open. (TermiT/Flycut#201, #337)
- Added an optional **Pop Paste** hotkey that pastes and then steps to the next older
  clipping on each press. (TermiT/Flycut#335, by @jvsteiner)
- Added **Type as Keystrokes** (T in the bezel, or Option in the menu) for fields that
  block paste. (TermiT/Flycut#332, by @MahdiHedhli)
- Lower idle CPU from clipboard polling, and less bezel redraw work.
  (TermiT/Flycut#329 and #327, by @emanuelst)
- An alert now explains when paste fails because Accessibility access is missing.
- Launch at login uses the modern SMAppService API on macOS 13 and later.
- The black and crossed-out menu bar icons now stay visible in dark mode.
- New name, icon and bundle ID (`com.jackfreem.soarcut`). Settings and history
  start fresh; Flycut's are untouched.
- Removed: the iOS app, iCloud sync, the App Store sandbox build and its login-item
  helper. Soarcut is a macOS-only, direct-download app.

The Flycut history below is kept for reference.

## 1.9.7 (2026-08-04)

First release since 1.9.6 (2020). Focused on crash fixes and modern-macOS
compatibility.

- Fixed a crash on macOS 26 when copying large content from Microsoft Remote
  Desktop Connection (the menu-bar icon update ran off the main thread). (#262, #279)
- Fixed an intermittent crash when a copy was quickly followed by a paste — the
  clipboard store was being modified from a background thread while the UI read
  it. Clipboard capture is now serialized on the main thread.
- Fixed pasting on non-QWERTY keyboard layouts (Russian, Dvorak, and others),
  where the synthesized ⌘V could fail or trigger the wrong action. (#264)
- Fixed a guaranteed crash when lowering the "Save" preference below "After each
  clip" while iCloud Clippings Sync was enabled.
- Fixed the menu search field returning wrong or stale results. (#290)
- Fixed a crash when enabling iCloud sync in unsigned/local builds that lack
  iCloud entitlements; sync now degrades gracefully instead. (#321)
- The project again builds cleanly on current Xcode.

Credits: menu-search fix by @chzhc; several fixes adapted from the
actively-maintained community fork (haad/Flycut) and from contributor pull
requests (#314, #322, #323).
