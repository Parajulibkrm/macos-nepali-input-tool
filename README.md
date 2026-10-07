# Nepali Input for macOS

A macOS input method for Nepali with two features:

1. **Typing**: type romanized words ("namaste") and pick Devanagari suggestions, powered by [Google Input Tools](https://www.google.com/inputtools/).
2. **Dictation**: hold **Right Option**, speak, release, and the text is typed at the cursor. It uses Google's speech engine (the one behind Chrome's voice input), free. The default language is Nepali; English and Hindi are in the menu.

> "Nepali Input" is a placeholder name. Both features use unofficial Google endpoints that can change or rate-limit at any time.

## Install

### Option 1: Installer package (recommended)

1. Download `NepaliInput.pkg` from the [Releases page](https://github.com/ParajuliBkrm/macos-nepali-input-tool/releases/latest). It is universal (Apple Silicon and Intel).
2. Double-click it and follow the prompts. It installs into `/Library/Input Methods/`.
3. Open `System Settings` → `Keyboard` → `Input Sources`, click `+`, choose `Nepali` → `Nepali Input`.

If the input method does not show up, log out and log back in.

### Option 2: Homebrew

```sh
brew tap parajulibkrm/macos-nepali-input-tool https://github.com/ParajuliBkrm/macos-nepali-input-tool
brew install --cask parajulibkrm/macos-nepali-input-tool/nepali-input
```

Upgrade with `brew upgrade --cask parajulibkrm/macos-nepali-input-tool/nepali-input`, then add the keyboard as above.

### Option 3: Build from source

Needs Xcode command line tools and an Apple Development certificate (a stable signature keeps the Microphone and Accessibility permissions across rebuilds).

```sh
git clone https://github.com/ParajuliBkrm/macos-nepali-input-tool.git
cd macos-nepali-input-tool
scripts/dev-install.sh   # installs into ~/Library/Input Methods
```

Maintainers: `scripts/release.sh` builds the universal, signed and notarized pkg into `dist/` (see the header of the script for the environment it reads).

## Dictation

Hold **Right Option**, speak, release. Press any other key while holding to cancel. The first use asks for the microphone. If another keyboard is active, the text is pasted instead, which needs Accessibility permission.

## Uninstall

```sh
brew uninstall --cask nepali-input                       # Homebrew users only
sudo rm -rf "/Library/Input Methods/Nepali Input.app"    # pkg installs
sudo pkgutil --forget io.veez.inputmethod.NepaliInput
rm -rf ~/Library/Input\ Methods/Nepali\ Input.app        # dev-install
```

## Screenshot

<img width="555" alt="screenshot" src="https://github.com/Parajulibkrm/macos-nepali-input-tool/blob/main/screenshots/demo.gif?raw=true">

## Progress

- [x] Basic input handling logic
  - [x] `Space` key to commit current highlighted candidate and add a space.
  - [x] `Return` key to commit current highlighted candidate.
  - [x] Number keys (`1`-`9`) to select candidate and commit
  - [x] Continue to show new candidates after partial matched candidate is selected and committed
  - [x] `Backspace` key to remove last composing letter
  - [x] `Esc` key to cancel composing
  - [x] Bypass modifier keys (`Shift`, `Option`, `Command`, `Control`)
  - [x] `-` and `=` keys to page up and page down candidate list respectively
  - [x] Handle Purnabiram (`/` key inserts `।`) and Devnagari Numbers `०`-`९`
- [x] System UI
- [x] Basic custom UI
  - [x] Numbered candidates
  - [x] Highlight current selected candidate
  - [x] Arrow keys to switch between highlighted candidate
  - [x] Group candidates into multiple pages, each page with at most `10` candidates
  - [x] Page up and page down button
  - [x] Draggable candidate window
- [x] Cloud engine
  - [x] Cancel previous unnecessary web requests to speed up
