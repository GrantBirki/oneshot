# OneShot 📸

[![build](https://github.com/GrantBirki/oneshot/actions/workflows/build.yml/badge.svg)](https://github.com/GrantBirki/oneshot/actions/workflows/build.yml)
[![test](https://github.com/GrantBirki/oneshot/actions/workflows/test.yml/badge.svg)](https://github.com/GrantBirki/oneshot/actions/workflows/test.yml)
[![lint](https://github.com/GrantBirki/oneshot/actions/workflows/lint.yml/badge.svg)](https://github.com/GrantBirki/oneshot/actions/workflows/lint.yml)
[![release](https://github.com/GrantBirki/oneshot/actions/workflows/release.yml/badge.svg)](https://github.com/GrantBirki/oneshot/actions/workflows/release.yml)

Open source screenshot utility for macOS with QoL improvements over the native Apple screenshot utility.

![oneshot](docs/assets/oneshot.png)

## 🎯 Goals

- Keep the capture flow simple and familiar.
- Add control over preview behavior, save timing, location, clipboard operations, and naming.
- Stay lightweight and focused.

## ✨ Features

- Selection, window, and full-screen capture.
- Floating preview with save/discard actions and drag-and-drop.
- Optional clipboard copy + configurable save location and filename prefix.
- Customizable hotkeys.
- Optional auto-dismiss preview with save delay control.
- Optional menu bar icon hiding (restore via Spotlight).

## 🚀 Installation

Homebrew (recommended):

```bash
brew install --cask grantbirki/tap/oneshot
```

## 📖 Usage

- End-user guide: [docs/usage.md](docs/usage.md)
- Settings reference: [docs/settings.md](docs/settings.md)

## 🔐 Verify Releases

Release artifacts are published with SLSA provenance. After downloading `OneShot.zip`:

```bash
gh attestation verify OneShot.zip \
  --repo grantbirki/oneshot \
  --signer-workflow grantbirki/oneshot/.github/workflows/release.yml \
  --source-ref refs/heads/main \
  --deny-self-hosted-runners
```

Minimal verification by owner:

```bash
gh attestation verify OneShot.zip --owner grantbirki
```

You can also verify the checksum:

```bash
shasum -a 256 OneShot.zip
```

## Unsigned Builds

OneShot releases are currently unsigned. macOS Gatekeeper may block the first launch.

To open it:

1) Right-click `OneShot.app` and choose Open.
2) Or go to System Settings → Privacy & Security and click Open Anyway.

> Why? Apple Developer ID certs cost $99/year, and I don't want to pay Apple.

## 👩‍💻 Contributing

See the [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this project.
