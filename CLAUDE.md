# CLAUDE.md

Context for continuing work on this repo in a fresh session. Read this first.

## What this is

A macOS **input method** that combines two features:

1. **Nepali typing**: type romanized words ("namaste") and pick Devanagari suggestions ("नमस्ते"), powered by Google Input Tools' free transliteration endpoint. This is the original project in this repo.
2. **Voice dictation**: hold **Right Option**, speak, release, and the text is typed at the cursor. It's powered by Google's speech engine, the same one Chrome's Web Speech API uses, for free. This was prototyped separately as "Dictate" in `~/labs/stt` and merged in here. That folder is now obsolete.

## Product decisions (from the user)

- **One input method**, not an app plus a separate keyboard. Adding the keyboard in Input Sources gets you both features.
- **Same GitHub repo** (`Parajulibkrm/macos-nepali-input-tool`), to keep stars and history. The repo, app name and bundle name will all be renamed later.
- **Name is a placeholder**: "Nepali Input" / `io.veez.inputmethod.NepaliInput` / executable `NepaliInput`. These live only in `scripts/config.sh` (plus the module name `NepaliInput` in `Package.swift` and `Sources/NepaliInput`). Ideas floated: Bolo (बोलो, "speak"), Lekh (लेख, "write"), Akshar (अक्षर). The user said "use any, we'll come back to this later".
- **Distributed publicly** via a `.pkg` installer and the Homebrew cask in `Casks/`. It will be **signed and notarized with the Veez Developer ID** (team `T2SGYX37P4`).
- **Speech must be free and must use Google's engine.** Local models (Whisper etc.) were explicitly rejected, even as a fallback. Don't propose them.
- **Hotkey:** hold-to-talk on **Right Option**. Pressing any other key while holding cancels, so ⌥ shortcuts keep working.
- **Default dictation language: Nepali** (`ne-NP`). English and Hindi are also in the menu.
- **UX target is Wispr Flow-like:** invisible, with a small floating overlay. The overlay is a compact dark rounded card with a neon gradient glow: live text on top (Streaming mode), level bars below. It's 240 pt wide with no text, 360 pt with text.
- **UI scope:** menu bar plus the input menu, and a native SwiftUI window (`Sources/NepaliInput/Setup/`) with two tabs: **Setup** (live checklist: keyboard added, switched to it, microphone, optional Accessibility, "Try it" box; opens on first run) and **Settings** (language, mode, menu-bar icon, start at login). Language, mode, icon and login also stay in both menus; changes sync both ways.
- The user likes to **plan before big changes**. Propose a plan for anything structural, and confirm before outward-facing actions (pushing, renaming the repo, releases).

## Layout

```
Package.swift                      SwiftPM, macOS 13+, one executable target
Sources/NepaliInput/
  main.swift                       debug commands → IMKServer → DictationController.start() → app.run()
  Typing/                          original transliteration input method
    InputController.swift          IMKInputController (@objc name "InputController"); feeds key events
                                   to the hotkey, tracks `InputController.active`, IMK menu, insertDictation()
    CloudInputEngine.swift         inputtools.google.com client (hardened: no force-unwraps, URL-encoded)
    InputContext, Candidates*, UISettings
  Dictation/
    DictationController.swift      state machine (idle/listening/working), mic permission, delivery,
                                   menu shared by the status item and the IMK input menu
    Hotkey.swift                   Right Option hold detection; global monitors + IMK feed, deduped by timestamp
    Recorder.swift                 AVAudioEngine → 16 kHz mono Int16, level + sample callbacks
    Transcriber.swift              protocol + `Mode` (.atOnce default, .streaming)
    LiveTranscriber.swift          "At Once": cuts at pauses while you talk and sends pieces in parallel
    StreamingSpeech.swift          "Streaming": Chrome's full-duplex endpoint, live interim text
    GoogleSpeech.swift             one-shot v2 recognize + Chunker (quietest-200 ms splitting)
    Overlay.swift                  floating NSPanel card (SwiftUI), never takes focus
    Paster.swift                   clipboard + synthetic ⌘V, restores clipboard, marks it transient
    DebugCommands.swift            --transcribe / --live / --stream / --render-overlay
Resources/Info.plist               template (__BUNDLE_ID__ etc. filled by make-bundle.sh)
Resources/NepaliInput.entitlements audio-input (required under hardened runtime)
scripts/config.sh                  name, bundle ID, version, legacy identifiers
scripts/make-bundle.sh <dir> [--universal]
scripts/dev-install.sh             build, sign (Apple Development) and install to ~/Library/Input Methods
scripts/release.sh                 universal build → Developer ID sign → pkg → notarize → staple (dist/)
packaging/pkg/, Casks/nepali-input.rb, .github/workflows/build.yml   updated for the new name, one universal pkg
```

## How dictation flows

1. Right Option goes down. `Hotkey` → `DictationController.begin()` checks the microphone permission, starts `Recorder`, creates the transcriber for the current mode, and shows the overlay.
2. While held, audio chunks go to `transcriber.append()`.
   - **At Once:** `LiveTranscriber` cuts a piece whenever there's a ~240 ms pause and the piece is ≥2 s, or forces a cut at the quietest spot at 10 s. Each piece goes to the v2 endpoint immediately and in parallel.
   - **Streaming:** audio is pushed up a chunked POST, and interim results come down a paired GET into the overlay.
3. Release → `finish()` waits for the transcriber.
   - Holds under 0.3 s are ignored.
   - If Streaming comes back empty, the whole recording is retried through `GoogleSpeech.transcribe`.
4. `deliver()`:
   - If `InputController.active` exists (this keyboard is active), the text goes in via `client.insertText`, committing any composing word first. No Accessibility needed.
   - Otherwise it's pasted with `Paster`, which needs Accessibility.
   - A trailing space is added.

The hotkey has two sources. Global `NSEvent` monitors need Accessibility and are installed once it's trusted (polled every 2 s). `InputController.handle` calls `hotkey.feed(event)` for every event while active. Both can see the same event, so `feed` dedupes by `event.timestamp`.

## Google endpoints (unofficial; can break or rate-limit at any time)

- **Speech key:** `AIzaSyBOti4mM-6x9WDnZIjIeyEU21OpBXqWBgw` (the shared Chromium key, as used by Python's `SpeechRecognition`).
- **One-shot:** `POST https://www.google.com/speech-api/v2/recognize?client=chromium&lang=ne-NP&key=…&pFilter=0&output=json`
  - Body: raw little-endian 16-bit PCM, `Content-Type: audio/l16; rate=16000`. FLAC also works.
  - Reply: newline-separated JSON; the first line is `{"result":[]}`.
  - The app pads 300 ms of silence on each side.
- **Streaming:** `https://www.google.com/speech-api/full-duplex/v1/up?key&pair=<rand>&lang&client=chromium&continuous&interim&output=json&pFilter=0` (chunked POST), paired with `.../down?key&pair&output=json` (GET).
- **Transliteration:** `GET https://inputtools.google.com/request?text=…&ime=transliteration_en_ne&num=11&cp=0&cs=1&ie=utf-8&oe=utf-8&app=demopage`.

### Measured findings (2026-10-07, using `say` TTS voices; real voices untested)

- v2 works for Nepali and English, with a response in about 1 s for short clips.
- **v2 drops whole sentences when one request contains a pause or spans more than ~10 s.** Cutting at every pause (≥2 s pieces, ≤10 s) fixed it: a 31 s clip came back complete, ready about 1.2–2 s after release whatever the length.
- **Full-duplex streaming is fast (about 0.2 s after release) but loses words server-side.** Hypotheses reset and drop earlier phrases with no final result: one voice stopped after about 5 s; others dropped the opening sentence. Adding background noise didn't help. That's why At Once is the default and Streaming is labelled "may drop words".
- Remaining recognition errors ("Sarah" → "serve") come from the TTS voices.
- Chrome-in-the-background (driving a real hidden Chrome running `webkitSpeechRecognition`) was discussed as a backup if these endpoints die. It was never built.

## Development

```sh
scripts/dev-install.sh                     # build + sign + install to ~/Library/Input Methods
swift build -c release && .build/release/NepaliInput --live sample.raw ne-NP      # At Once on a file
.build/release/NepaliInput --stream sample.raw en-US                               # Streaming on a file
.build/release/NepaliInput --render-overlay out.png "some text"                    # overlay screenshot
```

Test audio: `say -v Samantha -f text.txt -o x.aiff && ffmpeg -i x.aiff -ar 16000 -ac 1 -f s16le x.raw`. For Nepali, the Hindi voice `Lekha` reading Devanagari works.

### macOS gotchas learned the hard way

- **Sign with a real identity, not ad-hoc.** macOS ties permissions (TCC) to the code-signing requirement. Ad-hoc signatures change every build, so Accessibility resets each time. `dev-install.sh` uses "Apple Development: Bikram Parajuli (LUZQMV2776)". After changing identity, the old toggle looks on but doesn't count. Fix it with `tccutil reset Accessibility <bundle-id>` and grant again.
- **A third-party input method can't be enabled from code.** `TISEnableInputSource` returns noErr but stays disabled, so the user must add it in System Settings → Keyboard → Input Sources. Once added, `TISSelectInputSource` works, but the target app may need refocusing (activate another app, then come back) before IMK activates.
- **The risk spike confirmed** an unsandboxed, signed input method can request and use the microphone (persisting across relaunch), get Accessibility, run global monitors, receive `flagsChanged` through `recognizedEvents`/`handle`, and `insertText` directly.
- **Automated testing without a human:**
  - Synthesize Right Option with `CGEvent(keyboardEventSource:virtualKey:61…)` and flags `maskAlternate | 0x40`.
  - Play `say` audio through the speakers while "holding" the key.
  - Read TextEdit's contents with `osascript`.
- **Never log typed text, candidates or transcripts.** The original code logged every keystroke to the system log; that was removed.
- **Swift 5 language mode is intentional.** Shared state is confined to serial queues, and Swift 6 strict-concurrency warnings about it are expected.

## Status (end of first session, 2026-10-07)

**Done:** the repo is restructured to SwiftPM; dictation is merged in; it builds; it's installed at `~/Library/Input Methods/Nepali Input.app` and registered. All of this is uncommitted on local branch `dictation`; nothing is pushed.

**Not verified yet (needs the user to add "Nepali Input" in Input Sources first):**
- Transliteration typing still works after the refactor.
- Dictation through IMK `insertText` and through paste.
- IMK input-menu actions reach `InputController.dictationMenuAction(_:)`. The dictionary/`kIMKCommandMenuItemName` handling is a best guess.
- `SMAppService.mainApp` "Start at Login" from an input-method bundle.
- Whether the process is running at login when the user's keyboard isn't this one. If it isn't, the global hotkey is dead until the keyboard is first used.

**Session 2 (2026-10-07):** packaging, cask, CI workflow and README updated for the new name; one universal `NepaliInput.pkg`; postinstall removes the legacy GoogleInputTools app/process/pkg receipt. `scripts/release.sh` verified end to end except signing the pkg and notarizing: the app is signed with Developer ID Application, the pkg came out unsigned because no *Developer ID Installer* certificate exists. The CI workflow (manual trigger) expects secrets `APP_CERT_P12`, `INSTALLER_CERT_P12`, `CERT_PASSWORD`, `NOTARY_APPLE_ID`, `NOTARY_PASSWORD`, `NOTARY_TEAM_ID`; it has never run. Nothing is committed or pushed.

**Session 3 (2026-10-07):** setup/settings window built. Fixed: Right Option hold cut short in this keyboard (a duplicate event without the right-key device bit was read as release, see `Hotkey.feed`); pending word swallowing keys after ⌘/⌃ shortcuts; the `deactivateServer` crash (issues #1/#2) by sharing one `IMKCandidates` per process. Crash was reproducible with a stress loop switching keyboards/apps; 42 rounds clean after the fix. Postinstall/pkg now `chmod +x` the binary (issue #3, untested). Memory footprint ~41 MB idle.

**TODO:**
1. Verify the remaining unverified items above (typing, IMK menu actions, Start at Login).
2. User: create the **Developer ID Installer** certificate and run `xcrun notarytool store-credentials`; then `NOTARY_PROFILE=<name> scripts/release.sh` should produce a notarized pkg. Add the CI secrets above.
3. Test the pkg install on a clean-ish machine (legacy cleanup in postinstall is untested).
4. Pick the final name, then rename the repo and the bundle (ask first).
5. Optional input-menu icon (`tsInputMethodIconFileKey`) and app icon.
