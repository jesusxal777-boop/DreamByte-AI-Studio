# DreamByte AI Studio

**An iOS-first AI-assisted video editor by DreamByte Studios.**

DreamByte AI Studio aims to make video editing approachable through a native iOS/iPadOS experience, local editing tools, and optional AI-assisted workflows.

## Planned features

- Native SwiftUI interface designed for iPhone and iPad.
- Import and preview media using Apple's media frameworks.
- Non-destructive timeline editing, splitting, trimming, and reversible cuts.
- On-device silence detection with adjustable sensitivity and reviewable suggestions.
- MP4 export through supported Apple media APIs.
- Optional OpenRouter integration for edit suggestions, cuts, and effects.
- Optional Google Gemini integration for motion graphics and animated titles.
- A versioned `.dbedit` project format.
- Future Android and desktop support may be considered after the iOS foundation.

## Project status

Early-stage project. Features are planned, not promised to exist yet. The repository will document implemented features and known limitations as development progresses.

## API keys and privacy

AI integrations are optional. Never commit API keys, tokens, signing certificates, provisioning profiles, or other secrets. API keys should be stored securely on-device during local development. A public app that ships a shared provider key would require a secure backend proxy; a key embedded in an app can be extracted. Review each provider's current pricing, quotas, privacy terms, and model availability before use.

## Build target

The first target is iOS/iPadOS using Swift and SwiftUI, with Xcode and the Apple SDKs. Building and signing iOS apps requires a compatible macOS/Xcode environment. Installation and signing are handled separately by the user.

## License

This repository uses the **DreamByte Studios Non-Commercial License** in [`LICENSE`](LICENSE). You may study, modify, and share the project for non-commercial purposes under its conditions, but you may not sell it or use it commercially without prior written permission from DreamByte Studios. This is a source-available, non-commercial license; it is **not an OSI-approved open-source license**.

## Ownership and third-party components

Unless a file states otherwise, original project code and branding are © DreamByte Studios. Third-party libraries, SDKs, models, and services remain subject to their own licenses and terms. Do not assume this license grants rights to third-party assets or services.

## Contributions

By submitting a contribution, you confirm you have the right to submit it and agree that it will be distributed under this repository's license, unless a separate written agreement says otherwise.

## Disclaimer

This project is provided as-is, without warranty. It is not affiliated with or endorsed by OpenAI, OpenRouter, Google, Apple, or other third-party providers.