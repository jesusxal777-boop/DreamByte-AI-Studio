# API Key and Privacy Design

## User-owned keys only

DreamByte AI Studio must never ship with a developer-owned OpenRouter, Gemini, or other provider API key. Each user chooses their provider and enters their own key in the app. Forks must preserve this design and must not introduce a shared key that can create charges for its owner.

## Storage

- Store provider secrets using the iOS Keychain with device-only accessibility.
- Never store API keys in `.dbedit` projects, exported videos, logs, analytics, crash reports, source code, GitHub Actions variables for client-side distribution, or backups intended to be portable.
- Never display a complete saved key after saving. Show only whether one is configured; allow replacement and deletion.
- Do not transmit a key until the user explicitly invokes a feature that requires that provider.
- Use HTTPS for provider requests and avoid logging request headers or bodies containing secrets.

## Important limits

Keychain storage reduces exposure but does not make a client-side API key impossible to extract from a compromised or instrumented device. Since users supply their own keys, the app must clearly identify which provider receives a request and should provide an opportunity to review AI-related actions. Provider usage may incur charges under the user's account. Never silently send requests or create a billing commitment on the user's behalf.

## Forks and custom providers

A fork must not silently substitute another person's API key, endpoint, or account. Future provider configuration should clearly display provider name, API base URL where applicable, selected model, and the account/key that the user configured. Do not support arbitrary base URLs without considering HTTPS enforcement, endpoint trust, and accidental disclosure of keys to untrusted hosts.

## Current implementation status

The initial settings screen saves and deletes user-provided OpenRouter and Gemini keys using Keychain. It does not make provider API requests yet. Provider request clients must be implemented separately with explicit user-triggered calls, safe error handling, no secret logging, and tests.
