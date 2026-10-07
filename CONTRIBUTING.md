# Contributing

## Layout

```
Package.swift                  SwiftPM, macOS 13+, one executable target
Sources/NepaliInput/
  main.swift                   debug commands → IMKServer → DictationController.start() → app.run()
  Typing/                      transliteration input method (IMKInputController, Google Input Tools client, candidate window)
  Dictation/                   hold-to-talk: hotkey, recorder, Google speech clients, overlay, delivery
  Setup/                       SwiftUI window: setup guide and settings
Resources/                     Info.plist template, entitlements
scripts/                       config.sh (name, bundle ID, version), dev-install.sh, make-bundle.sh, release.sh
packaging/pkg/                 installer build and postinstall
Casks/                         Homebrew cask
```

The product name, bundle ID and executable name live in `scripts/config.sh` (plus the module name in `Package.swift`).

## Build and run

```sh
scripts/dev-install.sh     # build, sign with your Apple Development identity, install to ~/Library/Input Methods
```

Add the keyboard under System Settings → Keyboard → Input Sources the first time. Sign with a real identity, not ad hoc: macOS ties permissions to the signature, so ad-hoc builds lose Microphone and Accessibility every rebuild.

Debug commands run without the keyboard:

```sh
swift build -c release
.build/release/NepaliInput --live sample.raw ne-NP        # "At Once" on a 16 kHz mono Int16 file
.build/release/NepaliInput --stream sample.raw en-US      # "Streaming"
.build/release/NepaliInput --render-overlay out.png "text"
```

Test audio: `say -v Samantha -f text.txt -o x.aiff && ffmpeg -i x.aiff -ar 16000 -ac 1 -f s16le x.raw` (for Nepali, the Hindi voice `Lekha` reading Devanagari works).

## How dictation works

1. Right Option down → `DictationController.begin()` checks the microphone, starts `Recorder`, creates a transcriber and shows the overlay.
2. *At Once* (`LiveTranscriber`): cut a piece at each pause (≥ 2 s) or at the quietest spot at 10 s, and send each piece to Google's v2 recognize endpoint in parallel. *Streaming* (`StreamingSpeech`): push audio up a chunked POST and read interim results from a paired GET.
3. Release → wait for the transcriber, then `deliver()`: insert through the active input controller, or paste (`Paster`, needs Accessibility).

The hotkey has two sources: global monitors (need Accessibility) and the input method's own key events. The same press can arrive from both, so `Hotkey.feed` dedupes by timestamp and ignores the copy without the right-key device bit.

## Things that bite

- A third-party input method can't be enabled from code; the user adds it in Input Sources.
- IMK keeps an unretained reference to every `IMKCandidates` panel, so create one per process, not per controller (otherwise `deactivateServer` crashes).
- ⌘/⌃ shortcuts never reach `handle(_:client:)` as key events; use the modifier going down to end a composition.
- Never log typed text, candidates or transcripts.
- Swift 5 language mode is intentional; shared state is confined to serial queues.
- v2 recognize drops sentences when one request has a pause or runs past ~10 s; that's why At Once cuts at pauses. Streaming loses words server-side.
- The Google endpoints are unofficial and can break at any time.

## Releases

`scripts/release.sh` builds a universal app, signs it (Developer ID Application), builds the pkg (Developer ID Installer), notarizes and staples it. It reads `APP_IDENTITY`, `INSTALLER_IDENTITY` and `NOTARY_PROFILE` from the environment and falls back to unsigned output when they're missing. The manual GitHub workflow does the same on a runner using repository secrets (`APP_CERT_P12`, `APP_CERT_PASSWORD`, `INSTALLER_CERT_P12`, `INSTALLER_CERT_PASSWORD`, `NOTARY_APPLE_ID`, `NOTARY_PASSWORD`, `NOTARY_TEAM_ID`). Delete `dist/` after a local release build: the bundle inside shares the app's bundle ID and macOS may launch it as a second instance.
