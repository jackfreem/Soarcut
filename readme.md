# Soarcut

<img src="Design/Soarcut-1024.png" width="128" alt="Soarcut icon" />

Soarcut is a clean, simple clipboard manager for macOS developers. Every time you copy something, Soarcut keeps it in history. Press **Shift-Command-V** to bring up the bezel, keep holding the modifiers, tap **V** (or the arrow keys) to pick an older clipping, and release to paste it.

Soarcut continues a long lineage: [Jumpcut](http://jumpcut.sourceforge.net) by Steve Cook (2002) → [Flycut](https://github.com/TermiT/Flycut) by General Arcade (2011) → Soarcut (2026). Jump, fly, soar.

**Soarcut is an actively maintained fork.** It's used every day by its maintainer, bugs get fixed, good pull requests get reviewed and merged, and fixes from Flycut and its other forks are pulled in as they land. The goal is a clipboard manager developers can rely on for years, maintained in the open by more than one person.

## Why switch now

Soarcut 0.1.0 starts from Flycut 1.9.7 and adds fixes and features that were waiting in Flycut's issue tracker and pull request queue:

- **The bezel no longer gets stuck** when a system prompt or another window takes focus while it's open ([TermiT/Flycut#201](https://github.com/TermiT/Flycut/issues/201), open since 2020).
- **Pop Paste hotkey** (optional): paste, then step to the next older clipping on each press.
- **Type as keystrokes**: press **T** in the bezel, or hold Option in the menu, for fields that block paste (VM consoles, remote desktops).
- **Lower idle CPU** and fewer redraws.
- A clear alert when paste fails because Accessibility access is missing, instead of silently doing nothing.
- Launch at login uses the modern macOS API, and the monochrome menu bar icons work in dark mode.
- macOS only, distributed outside the App Store: no iOS app, no iCloud sync, no sandbox.

That's the starting point, not the finish line. See the [changelog](CHANGELOG.md) for what's landed since, and [open issues](https://github.com/jackfreem/Soarcut/issues) for what's next.

## Install

Download the latest release from [Releases](https://github.com/jackfreem/Soarcut/releases), move **Soarcut.app** to Applications, and allow it in **System Settings → Privacy & Security → Accessibility** so it can paste for you.

## Privacy and security

- Soarcut **skips clipboard items that password managers mark as concealed or transient** (1Password, Bitwarden and other apps that follow the [nspasteboard.org](http://nspasteboard.org) convention). This is on by default under Preferences > General.
- Clipboard history is kept in memory and, by default, **saved unencrypted on quit** to `~/Library/Preferences/com.jackfreem.soarcut.plist`, readable by other apps running as you. To keep history in memory only, set **Preferences > General > Save** to **Never**.
- Soarcut sends nothing over the network. Accessibility access is used only to press Cmd-V (or type a clipping) for you.
- Releases list a SHA-256 checksum for the DMG. Until releases are Developer ID signed and notarized, macOS will warn on first launch; check the checksum before approving it.

Please report security issues privately through GitHub's **Report a vulnerability** button on the Security tab rather than in a public issue.

## Use

See the [help file](help.md) for all bezel keys and menu features.

## Build

Open `Flycut.xcodeproj` in Xcode 26.3 or later and build the **Flycut** scheme. The product is `Soarcut.app`. (Internal names still say Flycut, which keeps merging upstream fixes easy.)

## Contributing and maintenance

Issues and pull requests are welcome, from one-line fixes to new features.

- **Bugs:** open an issue with your macOS version, what you did, what you expected and what happened. A screen recording helps a lot for bezel and focus problems.
- **Pull requests:** keep them small and focused, link the issue they fix, and describe how you tested. For anything visible, include before/after screenshots or recordings; [KeyCastr](https://github.com/keycastr/keycastr) makes keyboard-driven behavior easy to show.
- **Upstream fixes:** if Flycut or another fork fixes something Soarcut still has, an issue or PR pointing to it is just as useful as new code.
- **Co-maintainers wanted:** if you use Soarcut daily and want to help review and release, open an issue or start a discussion. The aim is for the project not to depend on any one person.

## Credits and license

MIT. Soarcut builds on the work of Flycut's contributors and on Jumpcut. See [acknowledgements.txt](acknowledgements.txt) for the libraries used and their authors.
