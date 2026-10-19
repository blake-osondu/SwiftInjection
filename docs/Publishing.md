# Publishing payloads

Your app loads a screen from a URL you control. Publishing a new version means uploading two files next to each other:

```
https://cdn.example.com/screens/home.json       ← the payload
https://cdn.example.com/screens/home.json.sig   ← its signature
```

The `swift-injection` command-line tool creates the signing key, signs payloads and validates them.

## Install the tool

From a checkout of this repository (macOS 13+):

```sh
swift build -c release --product swift-injection
cp "$(swift build -c release --product swift-injection --show-bin-path)/swift-injection" /usr/local/bin/
swift-injection --help
```

## 1. Create a signing key (once)

```sh
swift-injection keygen --out release.key
# Wrote private key to release.key. Public key:
# hlgSQnRBp9jO6Hfhgj+gIMowgLxiYqx0XERSBIe5DB4=
```

- Put the **public key** in your app:
  ```swift
  let loader = PayloadLoader(configuration: .init(
      url: URL(string: "https://cdn.example.com/screens/home.json")!,
      bundled: Bundle.main.url(forResource: "home", withExtension: "json"),
      verifier: try PayloadVerifier(base64PublicKeys: ["hlgSQnRBp9jO6Hfhgj+gIMowgLxiYqx0XERSBIe5DB4="])))
  ```
- Keep the **private key** secret, and never on the server that hosts payloads. The key file is created readable only by you, and `keygen` refuses to overwrite an existing key unless you pass `--force`.

## 2. Validate

```sh
swift-injection validate home.json
# warning: Skipped unknown modifier 'sparkle' at .body.vStack.children[0].text.modifiers[0]
# ✓ valid (schema 1.0, version 3, signature not checked, 1 warning)
```

Validation runs the same checks as the app's loader: size limits, decoding (errors point to the exact location, e.g. `body.vStack.children[2].text: missing key "value"`) and schema version. Use `--schema 1.0` to check against an older app's runtime. Exits with status 1 when invalid.

## 3. Sign

```sh
swift-injection sign home.json --key release.key
# Signed home.json → home.json.sig
```

`sign` validates first and refuses to sign an invalid payload. `--no-validate` skips that check, which you shouldn't need.

## 4. Upload

Upload `home.json` and `home.json.sig` together, in that order or atomically. A payload whose signature doesn't match is rejected by the app, which keeps using its last good copy.

Before uploading, check the pair exactly as the app will:

```sh
swift-injection validate home.json --public-key hlgSQnRBp9jO6Hfhgj+gIMowgLxiYqx0XERSBIe5DB4=
# ✓ valid (schema 1.0, version 3, signature verified, 0 warnings)
```

## In CI

Store the contents of `release.key` as a secret, and sign from the environment so the key never touches disk:

```yaml
- name: Validate and sign payloads
  env:
    SWIFTINJECTION_SIGNING_KEY: ${{ secrets.SWIFTINJECTION_SIGNING_KEY }}
  run: |
    for payload in screens/*.json; do
      swift-injection validate "$payload"
      swift-injection sign "$payload" --key-env SWIFTINJECTION_SIGNING_KEY
    done
- name: Upload
  run: aws s3 sync screens/ s3://my-bucket/screens/   # or any static host
```

## Rotating keys

`PayloadVerifier` accepts several public keys:
1. Create a new key and ship an app update that trusts both the old and new public keys.
2. Once most users have updated, sign with the new key.
3. Remove the old public key in a later app update.
