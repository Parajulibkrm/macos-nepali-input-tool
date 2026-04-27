cask "google-input-tools" do
  arch arm: "arm64", intel: "x86_64"

  version :latest
  sha256 :no_check

  url "https://github.com/ParajuliBkrm/macos-nepali-input-tool/releases/latest/download/GoogleInputTools-#{arch}.pkg"
  name "Google Input Tools"
  desc "English-to-Nepali transliteration cloud input method"
  homepage "https://github.com/ParajuliBkrm/macos-nepali-input-tool"

  pkg "GoogleInputTools-#{arch}.pkg"

  uninstall quit:    "com.lennylxx.inputmethod.GoogleInputTools",
            pkgutil: "com.lennylxx.inputmethod.GoogleInputTools",
            delete:  [
              "/Library/Input Methods/GoogleInputTools.app",
              "/Library/Input Methods/SwiftSupport",
            ]

  zap trash: [
    "~/Library/Containers/com.lennylxx.inputmethod.GoogleInputTools",
    "~/Library/Input Methods/GoogleInputTools.app",
    "~/Library/Input Methods/GoogleInputTools.swiftmodule",
    "~/Library/Input Methods/SwiftSupport",
  ]

  caveats <<~EOS
    After installation, enable the input method:
      System Settings → Keyboard → Input Sources → + → English → Google Input Tools

    If it doesn't appear, log out and log back in.

    The build is unsigned. If macOS blocks the installer, allow it from
    System Settings → Privacy & Security and try again.
  EOS
end
