#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/kiki-reader-test.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
swiftc Sources/Kiki/TranscriptReaderView.swift Tests/TranscriptReaderTests.swift -o "$test_dir/reader-test"
"$test_dir/reader-test"
