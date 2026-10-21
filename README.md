# DreamByte AI Studio

DreamByte AI Studio is an iPad/iPhone-first video editing project by DreamByte Studios.

## Current development stage

The `feature/ios-foundation` branch includes an early native SwiftUI foundation:
- Project-library home screen with responsive grid, search, and filters.
- A prominent **Crear proyecto** action that becomes a compact floating plus button after scrolling.
- Local persistence for project metadata.
- An editor foundation with local video import, AVKit preview, and saved manual in/out range controls.
- User-managed OpenRouter and Gemini API-key settings stored in iOS Keychain.

**This is not a finished editor.** Multi-clip timeline editing, exported trimmed media, audio tools, and AI provider requests are not yet implemented. The trim sliders currently save an edit range; they do not create an exported file.

## Editing without AI

The core editor is designed to work independently of AI providers. Importing and previewing media and preparing manual edits should remain available without API keys. AI-assisted decisions and motion graphics will be optional tools.

## Build

The iOS project is generated with XcodeGen from `project.yml`. GitHub Actions can attempt an unsigned simulator build on macOS.

## API key safety

Do not add shared provider keys to source code, build settings, or commits. Users supply their own keys. Keychain reduces exposure but does not guarantee protection on a compromised or instrumented device. API usage may incur provider charges.

## License

See [LICENSE](LICENSE). This project currently uses a custom non-commercial license; it is not an OSI-approved open-source license.
