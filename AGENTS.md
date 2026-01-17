# AGENTS.md

This is a Swift based repository that creates an open source screenshot utility that aims to act as a replacement for macOS's built-in screenshot tool. It works in a very similar way but adds several additional features and capabilities.

The mains goals of this project are:

- Provide an extemely simple and easy to use screenshot utility that works in a similar way to the built-in macOS screenshot tool.
- Extend the MacOS screenshot tool with additional features such as:
  - Custom delays or even disabling the post-capture overlay image preview/hover tile.
  - Custom save locations including the ability to automatically save to clipboard, desktop, documents, or a user specified folder.
  - Custom file naming conventions.
  - The ability to fully disable the floating thumbnail preview and just default to instantly saving the screenshot or copying to clipboard.

## Ease of installation

Once built, this project should be really easy to install. It should be installed via homebrew by doing something like:

```bash
brew install --cask grantbirki/tap/oneshot
```

## Code Standards

### Development Flow

- Test: `script/test`
- Lint: `script/lint`
- Build: `script/build`

You must ensure that all tests, linting, and build steps pass after making any changes to the codebase (except for documentation changes).

## Repository Structure

- `script/`: Scripts for building, testing, linting, etc. These are "scripts to rule them all" and should be used for all CI/CD and local development tasks.
- `.github/`: GitHub Actions workflows for CI/CD

## Key Guidelines

1. Follow Swift best practices and idiomatic patterns
2. Maintain existing code structure and organization
3. Use dependency injection patterns where appropriate
4. Write unit tests for new functionality.
5. When responding to code refactoring suggestions, function suggestions, or other code changes, please keep your responses as concise as possible. We are capable engineers and can understand the code changes without excessive explanation. If you feel that a more detailed explanation is necessary, you can provide it, but keep it concise.
6. When suggesting code changes, always opt for the most maintainable approach. Try your best to keep the code clean and follow DRY principles. Avoid unnecessary complexity and always consider the long-term maintainability of the code.
7. When writing unit tests, always strive for 100% code coverage where it makes sense. Try to consider edge cases as well.
8. Always strive to keep the codebase clean and maintainable. Avoid unnecessary complexity and always consider the long-term maintainability of the code.
9. Always strive for the highest level of code coverage with unit tests where possible.

## Documentation

Anytime you are making a change to a setting/preference or making a change to a feature that is strongly linked to a setting, make sure to update the `docs/settings.md` file to reflect the changes made. This is crucial for keeping the documentation accurate and up-to-date for users.
