# CLAUDE.md

A macOS input method ("Nepali Input") that combines romanized Nepali typing (Google Input Tools) with hold-to-talk dictation on Right Option (Google's speech engine). Read [CONTRIBUTING.md](CONTRIBUTING.md) for the layout, build steps and gotchas.

## Rules

- Speech must stay free and use Google's engine. Don't propose local models (Whisper etc.).
- Never log typed text, candidates or transcripts.
- Product name, bundle ID and executable name live only in `scripts/config.sh` (plus the module name in `Package.swift`).
- Sign dev builds with a real identity (`scripts/dev-install.sh`), never ad hoc, or macOS resets permissions every build.
- Delete `dist/` after running `scripts/release.sh`; its bundle shares the bundle ID with the installed app.
- Confirm before outward-facing actions: pushing, releases, renaming the repo.
- Swift 5 language mode is intentional; Swift 6 concurrency warnings are expected.

## Commands

```sh
scripts/dev-install.sh        # build, sign, install to ~/Library/Input Methods
swift build -c release        # compile only
scripts/release.sh            # universal signed pkg (notarized when NOTARY_PROFILE is set)
```
