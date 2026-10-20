# Security

SwiftInjection runs screens and logic your app downloads. The SDK protects your users by default, but part of the job is yours.

## What the SDK does

- **Only signed payloads run.** `PayloadLoader` requires a `PayloadVerifier`. A payload (and its cached copy, re-checked every time it's read) must carry a valid Ed25519 signature from one of your keys. Unsigned loading needs an explicit `allowUnsigned: true`, which logs a warning.
- **HTTPS only.** Plain `http://` URLs are refused unless you set `allowInsecureHTTP: true`.
- **Bounded payloads.** Size, nesting depth, object count and script size are checked before decoding (`PayloadLimits`), so a broken or hostile payload can't exhaust memory.
- **Bad updates don't stick.** Only a payload that passes every check replaces the cache; otherwise the app falls back to the last good copy, then to the payload bundled in the app.
- **Payloads can only do what you expose.** Components and modifiers only render. Scripts run in JavaScriptCore with no network or file access and see only the screen's state. The only way a payload can cause effects outside the screen is a host function your app registers (`store.functions[...]`).

## What you're responsible for

- **Keep the private key off your payload server.** Signing protects your users when the server or CDN is compromised, but only if the key isn't stored there. Sign in CI or on a machine you control, and upload only `payload.json` and `payload.json.sig`.
- **Register only the host functions you need, and treat them like a public API.** Assume a payload can call them with any arguments. Validate inputs, and don't expose broad capabilities (arbitrary URLs, payments, file access) without checks.
- **Rotate keys when needed.** `PayloadVerifier` accepts several public keys: ship the new key in an app update, switch signing to it, then drop the old key in a later update.
- **Use `allowUnsigned` and `allowInsecureHTTP` only for local development.**
- **Stay within App Review guidelines.** Downloaded code may not change your app's primary purpose (App Store Review Guideline 2.5.2 and the Apple Developer Program License Agreement).

## Known limitation

JavaScriptCore has no public way to time-limit a script, so a script that never returns blocks the main thread. Signing is the mitigation: only scripts you published can run.

## Reporting a vulnerability

Please report vulnerabilities privately through [GitHub Security Advisories](https://github.com/blake-osondu/SwiftInjection/security/advisories/new) rather than in a public issue.
