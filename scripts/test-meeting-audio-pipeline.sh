#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/kiki-meeting-pipeline.XXXXXX)
swiftc -O -parse-as-library Sources/Kiki/MeetingAudioPipeline.swift \
    tests/MeetingAudioPipelineTests.swift -o "$test_dir/tests"
"$test_dir/tests"
