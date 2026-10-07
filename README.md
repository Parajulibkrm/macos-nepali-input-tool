# Nepali Input for macOS

[![Release](https://github.com/Parajulibkrm/macos-nepali-input-tool/actions/workflows/build.yml/badge.svg)](https://github.com/Parajulibkrm/macos-nepali-input-tool/actions/workflows/build.yml)

Type Nepali by typing English, or just say it. One keyboard, two ways to write:

- **Type** romanized words (`namaste`) and pick the Devanagari suggestion (`नमस्ते`).
- **Dictate**: hold **Right Option**, speak, release, and the text appears at your cursor. Works in any app.

Both run on Google's free services, so there is nothing to sign up for and nothing to pay.

<img width="555" alt="Typing demo" src="https://github.com/Parajulibkrm/macos-nepali-input-tool/blob/main/screenshots/demo.gif?raw=true">

## Install

Requires macOS 13 or later (Apple Silicon and Intel).

### Installer (recommended)

1. Download `NepaliInput.pkg` from the [latest release](https://github.com/Parajulibkrm/macos-nepali-input-tool/releases/latest). It is signed and notarized.
2. Double-click it and follow the prompts.
3. Open **System Settings → Keyboard → Input Sources → Edit… → +**, choose **Nepali → Nepali Input**, and click **Add**.
4. Pick **Nepali Input** from the input menu in the menu bar. The setup guide opens the first time and checks off each step as you finish it.

If the keyboard isn't listed, log out and back in.

### Homebrew

```sh
brew tap parajulibkrm/macos-nepali-input-tool https://github.com/Parajulibkrm/macos-nepali-input-tool
brew install --cask parajulibkrm/macos-nepali-input-tool/nepali-input
```

### From source

Needs the Xcode command line tools and a code-signing identity (a stable signature lets macOS remember the permissions you grant).

```sh
git clone https://github.com/Parajulibkrm/macos-nepali-input-tool.git
cd macos-nepali-input-tool
scripts/dev-install.sh   # builds, signs and installs into ~/Library/Input Methods
```

## Using it

### Typing

| Key | Action |
|---|---|
| letters | build a word; suggestions appear |
| `1`–`9` | choose a suggestion |
| `Space` | commit the highlighted suggestion and add a space |
| `Return` | commit the highlighted suggestion |
| `←` `→` | move between suggestions |
| `-` `=` | previous / next page of suggestions |
| `Backspace` | remove the last letter |
| `Esc` | cancel the word |
| `/` | `।` (purna biram) |

Shortcuts such as ⌘A or ⌃-keys work as usual and end the word you were typing.

### Dictation

Hold **Right Option**, speak, release. Press any other key while holding to cancel, so Option shortcuts keep working. Taps shorter than a third of a second are ignored.

- **Key:** Right Option (default), Left Option, Right Command or Right Control.
- **Behavior:** *Hold* (talk while you hold the key) or *Toggle* (press to start, press again to type; Esc cancels).

- **Language:** Nepali (default), English or Hindi.
- **Mode:** *At Once* (default) sends your speech to Google in pieces while you talk and gives the most reliable text after you let go. *Streaming* shows words as you speak but Google sometimes drops some.
- With Nepali Input as your active keyboard, text is typed straight in. With another keyboard active, it is pasted, which needs Accessibility permission.

Change these in the menu-bar mic icon, the input menu, or the **Settings** window.

### Permissions

| Permission | Needed for |
|---|---|
| Microphone | dictation (asked the first time) |
| Accessibility | optional: use Right Option and dictate while another keyboard is active |

## Privacy

- **Typing:** each word you are composing is sent to `inputtools.google.com` to get suggestions.
- **Dictation:** your voice is recorded only while you dictate and is sent to Google's speech service for transcription.
- Nothing else leaves your Mac, and the app does not log what you type or say.

Both features use unofficial Google endpoints (the same ones Google Input Tools and Chrome's voice input use). They are free but can change or be rate-limited at any time.

## Troubleshooting

- **Not in the keyboard list / does nothing:** log out and back in. The app lives in `/Library/Input Methods/` (installer) or `~/Library/Input Methods/` (source install). Make sure the file `Nepali Input.app/Contents/MacOS/NepaliInput` is executable.
- **Dictation doesn't start with another keyboard:** grant Accessibility in System Settings → Privacy & Security.
- **"Microphone is off":** System Settings → Privacy & Security → Microphone.
- **Reopen the guide:** menu-bar mic icon → **Setup Guide…**

## Uninstall

```sh
brew uninstall --cask nepali-input                       # Homebrew installs
sudo rm -rf "/Library/Input Methods/Nepali Input.app"    # installer
sudo pkgutil --forget io.veez.inputmethod.NepaliInput
rm -rf ~/Library/Input\ Methods/Nepali\ Input.app        # source install
```

Then remove the keyboard under System Settings → Keyboard → Input Sources.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for the layout, how to test and how releases are built.

## Credits and license

Started from [lennylxx/GoogleInputTools](https://github.com/lennylxx/GoogleInputTools). Licensed under [GPL-3.0](LICENSE).
