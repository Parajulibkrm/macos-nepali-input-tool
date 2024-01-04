# Google Input Tools for macOS

[![Build Status](https://github.com/ParajuliBkrm/macos-nepali-input-tool/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/ParajuliBkrm/macos-nepali-input-tool/actions/workflows/build.yml?query=branch%3Amain)

A english-nepali transliteration *cloud* input method that uses [Google Input Tools](https://www.google.com/inputtools/) as engine for macOS.


## How to use

1. Install Xcode 12.5.0+.

2. Clone and build the project.

  ```
  git clone https://github.com/ParajuliBkrm/macos-nepali-input-tool.git
  cd macos-nepali-input-tool
  ./build.sh
  ``` 

> The output will be `Users/[username]/Library/Input\ Methods/GoogleInputTools.app`

3. Open `System Preferences` -> `Keyboard` -> `Input Sources`, click `+` to add a new input method, choose `English` -> `Google Input Tools`.

4. If you want to remove it, simply run below command.

  ```
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.app
  rm -rf ~/Library/Input\ Methods/GoogleInputTools.swiftmodule
  ```

## Screenshot
[![Screenshot](https://raw.githubusercontent.com/ParajuliBkrm/macos-nepali-input-tool/main/screenshots/demo.gif)](https://raw.githubusercontent.com/ParajuliBkrm/macos-nepali-input-tool/main/screenshots/demo.gif)

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
  - [ ] Handle Purnabiram `|` and Devnagari Numbers `०`-`९`
- [x] System UI
- [x] Basic custom UI
  - [x] Numbered candidates
  - [x] Highlight current selected candidate
  - [ ] Arrow keys to switch between highlighted candidate
  - [ ] Group candidates into multiple pages, each page with at most `10` candidates
  - [ ] Page up and page down button
  - [ ] Draggable candidate window
- [x] Cloud engine
  - [ ] Cancel previous unnecessary web requests to speed up (Not tested Properly)
