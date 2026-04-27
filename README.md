# Google Input Tools for macOS

[![Build Status](https://github.com/ParajuliBkrm/macos-nepali-input-tool/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/ParajuliBkrm/macos-nepali-input-tool/actions/workflows/build.yml?query=branch%3Amain)

A english-nepali transliteration *cloud* input method that uses [Google Input Tools](https://www.google.com/inputtools/) as engine for macOS.


## Install

### Option 1: Download from Releases (recommended)

1. Download the latest DMG for your Mac from the [Releases page](https://github.com/ParajuliBkrm/macos-nepali-input-tool/releases/latest):
   - Apple Silicon (M1/M2/M3/M4): `GoogleInputTools-arm64.dmg`
   - Intel: `GoogleInputTools-x86_64.dmg`

2. Open the DMG and copy both `GoogleInputTools.app` and the `SwiftSupport` directory into `~/Library/Input Methods/`.

  ```
  cp -R /Volumes/GoogleInputTools-*/GoogleInputTools.app ~/Library/Input\ Methods/
  cp -R /Volumes/GoogleInputTools-*/SwiftSupport ~/Library/Input\ Methods/
  ```

3. Log out and log back in.

4. Open `System Settings` → `Keyboard` → `Input Sources`, click `+`, choose `English` → `Google Input Tools`.

> The build is unsigned, so the first launch may be blocked by Gatekeeper. Right-click the app → `Open`, or allow it from `System Settings` → `Privacy & Security`.

### Option 2: Build from source

1. Install Xcode 12.5.0+.

2. Clone and build the project.

  ```
  git clone https://github.com/ParajuliBkrm/macos-nepali-input-tool.git
  cd macos-nepali-input-tool
  ./build.sh
  ```

  If you get this error:

  ```
   xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
  ```

  then run:

  ```
  sudo xcode-select -r
  ```

> The output will be `~/Library/Input Methods/GoogleInputTools.app`.

3. Open `System Settings` → `Keyboard` → `Input Sources`, click `+`, choose `English` → `Google Input Tools`.

## Uninstall

  ```
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.app
  rm -rf ~/Library/Input\ Methods/SwiftSupport
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.swiftmodule
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
