cask "nepali-input" do
  version :latest
  sha256 :no_check

  url "https://github.com/ParajuliBkrm/macos-nepali-input-tool/releases/latest/download/NepaliInput.pkg"
  name "Nepali Input"
  desc "Nepali typing and voice dictation input method"
  homepage "https://github.com/ParajuliBkrm/macos-nepali-input-tool"

  pkg "NepaliInput.pkg"

  uninstall quit:    "io.veez.inputmethod.NepaliInput",
            pkgutil: "io.veez.inputmethod.NepaliInput",
            delete:  "/Library/Input Methods/Nepali Input.app"

  zap trash: "~/Library/Input Methods/Nepali Input.app"

  caveats <<~EOS
    After installation, add the keyboard:
      System Settings → Keyboard → Input Sources → + → Nepali → Nepali Input

    If it doesn't appear, log out and log back in.

    Dictation: hold Right Option and speak. Allow the microphone when asked.
  EOS
end
