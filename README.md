# OneShot 📸

[![build](https://github.com/GrantBirki/oneshot/actions/workflows/build.yml/badge.svg)](https://github.com/GrantBirki/oneshot/actions/workflows/build.yml)
[![test](https://github.com/GrantBirki/oneshot/actions/workflows/test.yml/badge.svg)](https://github.com/GrantBirki/oneshot/actions/workflows/test.yml)
[![lint](https://github.com/GrantBirki/oneshot/actions/workflows/lint.yml/badge.svg)](https://github.com/GrantBirki/oneshot/actions/workflows/lint.yml)

Open source screenshot utility for MacOS with QoL improvements over the native Apple screenshot utility.

## Installation

Homebrew (recommended):

```bash
brew install --cask grantbirki/tap/oneshot
```

## Verify Releases

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
