#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
report_dir=$(mktemp -d /tmp/kiki-capture-reader.XXXXXX)
app="${1:-build/Kiki.app}"
[[ -d "$app" ]] || { echo "Missing app bundle: $app" >&2; exit 1; }
trap 'rm -f "$report_dir/result.txt" "$report_dir/result.txt.png"; rmdir "$report_dir"' EXIT
open -n "$app" --args --verify-capture-reader "$report_dir/result.txt"
for _ in {1..100}; do
    if [[ -f "$report_dir/result.txt" ]]; then
        cat "$report_dir/result.txt"
        grep -q '^PASS ' "$report_dir/result.txt"
        exit $?
    fi
    sleep 0.1
done
echo "FAIL: capture reader diagnostic did not complete" >&2
exit 1
