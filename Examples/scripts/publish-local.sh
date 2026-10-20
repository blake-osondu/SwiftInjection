#!/bin/bash
# Compiles, validates and signs every showcase app's screens, the way a release pipeline would.
#
#   Examples/scripts/publish-local.sh            publish once
#   Examples/scripts/publish-local.sh --serve    publish, serve at http://localhost:8000, republish on save
#
# For each app in Examples/Simple/<App> and Examples/Enterprise/<App>:
#   screens/<Screen>.swift (+ <Screen>.scripts.js)  →  Examples/.payloads/<App>/<Screen>.json + .sig   (served)
#                                                    →  <App>.swiftpm/Resources/<Screen>.json            (bundled fallback)
# The first run creates a development signing key in Examples/scripts/.dev-signing.key (git-ignored, never
# committed) and copies its public key into each app as Resources/payload-signing.pub.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EXAMPLES="$ROOT/Examples"
OUT="$EXAMPLES/.payloads"
KEY="$EXAMPLES/scripts/.dev-signing.key"

swift build -c release --product swift-injection --package-path "$ROOT" >/dev/null
CLI="$(swift build -c release --product swift-injection --package-path "$ROOT" --show-bin-path)/swift-injection"

if [ ! -f "$KEY" ]; then
    "$CLI" keygen --out "$KEY" > "$KEY.pub"
    echo "Created a development signing key ($KEY). It's for local demos only."
fi
PUBLIC_KEY="$(cat "$KEY.pub")"

apps() {
    for dir in "$EXAMPLES"/Simple/* "$EXAMPLES"/Enterprise/*; do
        [ -d "$dir/screens" ] && echo "$dir"
    done
}

publish_app() {
    local dir="$1" app
    app="$(basename "$dir")"
    mkdir -p "$OUT/$app" "$dir/$app.swiftpm/Resources"
    for screen in "$dir"/screens/*.swift; do
        local name
        name="$(basename "$screen" .swift)"
        # The version is a hash of the sources: stable across runs, different whenever the screen changes.
        local version
        version="$(cat "$screen" "${screen%.swift}.scripts.js" 2>/dev/null | shasum -a 256 | cut -c1-12)"
        # Optional screens/components: the app's own views (one name per line) compiled as custom components.
        local components=""
        [ -f "$dir/screens/components" ] && components="$(grep -v '^#' "$dir/screens/components" | tr '\n' ',' | sed 's/,*$//')"
        "$CLI" compile "$screen" -o "$OUT/$app/$name.json" --payload-version "$version" --components "$components" >/dev/null
        "$CLI" validate "$OUT/$app/$name.json" >/dev/null
        "$CLI" sign "$OUT/$app/$name.json" --key "$KEY" >/dev/null
        cp "$OUT/$app/$name.json" "$dir/$app.swiftpm/Resources/$name.json"
        echo "  $app/$name.json (signed)"
    done
    echo "$PUBLIC_KEY" > "$dir/$app.swiftpm/Resources/payload-signing.pub"
}

publish_all() {
    echo "Publishing to $OUT"
    for dir in $(apps); do
        publish_app "$dir" || echo "  $(basename "$dir"): failed (see errors above)"
    done
}

publish_all
[ "${1:-}" = "--serve" ] || exit 0

python3 -m http.server 8000 --directory "$OUT" >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER' EXIT
echo "Serving http://localhost:8000/<App>/<Screen>.json (Ctrl-C to stop); republishing on save"

stamp="$(mktemp)"
while true; do
    sleep 1
    for dir in $(apps); do
        if [ -n "$(find "$dir/screens" -newer "$stamp" \( -name '*.swift' -o -name '*.js' \) 2>/dev/null)" ]; then
            touch "$stamp"
            publish_app "$dir" || true
        fi
    done
done
