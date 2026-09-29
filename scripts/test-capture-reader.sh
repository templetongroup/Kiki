#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
report_dir=$(mktemp -d /tmp/kiki-capture-reader.XXXXXX)
open -n build/Kiki.app --args --verify-capture-reader "$report_dir/result.txt"
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
