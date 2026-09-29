#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/kiki-meeting-processing.XXXXXX)
trap 'rm -f "$test_dir/tests"; rmdir "$test_dir"' EXIT
swiftc -parse-as-library Sources/Kiki/TranscriptPostProcessor.swift tests/MeetingPostProcessingTests.swift -o "$test_dir/tests"
"$test_dir/tests"
