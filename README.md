# DreamByte AI Studio

DreamByte AI Studio is an iPad/iPhone-first video editing project by DreamByte Studios.

## Current development stage

The `feature/ios-foundation` branch includes an early native SwiftUI foundation:
- Project-library home screen with responsive grid, search, and filters.
- A prominent **Crear proyecto** action that becomes a compact floating plus button after scrolling.
- Local persistence for project metadata.
- An editor foundation with local video import, AVKit preview, synchronized playback, timeline clip selection, and saved manual in/out range controls.
- AVFoundation export of the selected source range with added audio clips, volume automation, visual overlays, and orientation normalization.
- Safe media copying through security-scoped file URLs, microphone recording, and persisted audio/image/text timeline clips.
- User-managed OpenRouter and Gemini API-key settings stored in iOS Keychain.

**This is not a finished editor.** The current export pipeline supports one primary source video plus added audio and visual overlays; it does not yet perform full video-track compositing, frame-accurate drag editing, or provider API requests. Export and device behavior still require validation on macOS/Xcode and a physical iPad.

## Editing without AI

The core editor is designed to work independently of AI providers. Importing and previewing media and preparing manual edits should remain available without API keys. AI-assisted decisions and motion graphics will be optional tools.

## Build

The iOS project is generated with XcodeGen from `project.yml`. GitHub Actions builds an unsigned device app on macOS and packages it as an IPA artifact when the workflow succeeds.

## API key safety

Do not add shared provider keys to source code, build settings, or commits. Users supply their own keys. Keychain reduces exposure but does not guarantee protection on a compromised or instrumented device. API usage may incur provider charges.

## License

See [LICENSE](LICENSE). This project currently uses a custom non-commercial license; it is not an OSI-approved open-source license.
