#!/bin/sh
# Compiles Examples/screens/TodoScreen.swift on every save and serves it at http://localhost:8000.
set -e
cd "$(dirname "$0")/.."
swift build -c release --product swift-injection
CLI="$(swift build -c release --product swift-injection --show-bin-path)/swift-injection"
cd Examples/screens
"$CLI" compile TodoScreen.swift --watch &
WATCH=$!
trap 'kill $WATCH' EXIT
echo "Serving http://localhost:8000/TodoScreen.json (Ctrl-C to stop)"
python3 -m http.server 8000
