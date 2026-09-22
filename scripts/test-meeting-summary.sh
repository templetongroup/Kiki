#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/kiki-summary-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library Sources/Kiki/MeetingTranscript.swift Sources/Kiki/MeetingSummaryGenerator.swift tests/MeetingSummaryTests.swift -o "$test_dir/tests"
"$test_dir/tests" "$@"
