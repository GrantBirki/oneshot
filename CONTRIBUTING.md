# Contributing to OneShot

Thanks for helping improve OneShot! This project uses the `script/` tools for all common tasks.

## Setup

```bash
script/bootstrap
```

This installs required tools (XcodeGen, SwiftLint, SwiftFormat) and generates the Xcode project.

## Development

- Build: `script/build`
- Test: `script/test`
- Lint/format checks: `script/lint`
- Run the app (Debug): `script/server`

If you change `project.yml`, run `script/update` to regenerate the Xcode project.

## Release Flow

Versioning is driven by the `VERSION` file. Bump it manually (X.Y.Z) in a commit to `main`.

Releases are created by GitHub Actions when `VERSION` changes on `main`. The workflow:

- Builds the release zip via `script/package`
- Creates the GitHub release + tag

Update the Homebrew cask manually in `grantbirki/homebrew-tap` after each release.

## Permissions (Dev Build)

If the Debug app doesn't appear in Screen Recording permissions after `script/server`, add it manually:

`/Users/$USER/code/oneshot/build/DerivedData/Build/Products/Debug/OneShot.app`

![permissions_dev](docs/assets/permissions_dev.png)

## Guidelines

- Use Swift best practices and keep changes focused.
- Add or update tests for new behavior.
- Update `docs/settings.md` when settings or behavior tied to settings change.
- Prefer the scripts under `script/` over direct tool invocations.
