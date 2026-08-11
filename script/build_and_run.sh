#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Kiki"
BUNDLE_ID="com.tonyricciardi.kiki"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$PROJECT_ROOT/build/Kiki.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/Kiki"

cd "$PROJECT_ROOT"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

KIKI_VERSION="${KIKI_VERSION:-0.6.8}" \
KIKI_BUILD_NUMBER="${KIKI_BUILD_NUMBER:-41}" \
    ./scripts/make-app.sh

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
    run)
        open_app
        ;;
    --debug|debug)
        lldb -- "$APP_BINARY"
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify|verify)
        /usr/bin/open -n "$APP_BUNDLE" --args --preview-workbench
        for _ in {1..20}; do
            if pgrep -x "$APP_NAME" >/dev/null; then
                exit 0
            fi
            sleep 0.25
        done
        echo "Kiki did not remain running after launch." >&2
        exit 1
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
