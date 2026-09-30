#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-build/Kiki.app}"
[[ -d "$app" ]] || { echo "Missing app bundle: $app" >&2; exit 1; }
test_dir=$(mktemp -d /tmp/kiki-summary-cancellation.XXXXXX)
trap 'rm -f "$test_dir/result.txt"; rmdir "$test_dir"' EXIT
extra_args=()
if [[ -n "${2:-}" ]]; then extra_args+=("$2"); fi
open -n "$app" --args --verify-summary-cancellation "$test_dir/result.txt" "${extra_args[@]}"
for ((attempt = 0; attempt < 800; attempt++)); do
    if [[ -f "$test_dir/result.txt" ]]; then
        cat "$test_dir/result.txt"
        echo
        [[ "$(head -c 5 "$test_dir/result.txt")" == "PASS:" ]]
        exit $?
    fi
    sleep 0.1
done
echo "Summary cancellation diagnostic did not return a result." >&2
exit 1
