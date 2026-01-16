version_value = File.read(File.expand_path("../VERSION", __dir__)).lines.map(&:strip).find do |line|
  line.match?(/^\d+\.\d+\.\d+$/)
end
raise "VERSION file missing or invalid" unless version_value

cask "oneshot" do
  version version_value
  sha256 "b13f40d019d80d320f2e58f07adc616f9a5dedfc9ff0bef3fd7f6fbfdfb8b3c8"

  url "https://github.com/grantbirki/oneshot/releases/download/v#{version}/OneShot.zip"
  name "OneShot"
  desc "Open source screenshot utility for macOS"
  homepage "https://github.com/grantbirki/oneshot"

  app "OneShot.app"
end
