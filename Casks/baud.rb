cask "baud" do
  version "0.1.0"
  sha256 "REPLACE_WITH_RELEASE_ZIP_SHA256"

  url "https://github.com/KhaledSaeed18/baud/releases/download/v#{version}/Baud.zip"
  name "Baud"
  desc "Menu bar character that reminds you to move, drink water, and rest your eyes"
  homepage "https://github.com/KhaledSaeed18/baud"

  depends_on macos: ">= :sonoma"

  app "Baud.app"

  zap trash: [
    "~/Library/Application Support/Baud",
  ]
end
