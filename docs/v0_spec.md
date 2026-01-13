# v0 Specification

This document outlines the specifications for version 0 (v0) of the OpenShot macOS screenshot utility.

## Goals

- Keep the app simple, reliable, and installable via Homebrew (open source, unsigned is acceptable for MVP).
- Minimum macOS: 11 (Big Sur) to cover Apple Silicon devices broadly.
- Build as a macOS app bundle, unsigned for MVP.
- Distribute via Homebrew cask.
- Users will need to approve the app on first run (Gatekeeper).

## Non-Goals (MVP)

- No custom installer; Homebrew cask only.
