#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/kiki-metal-test.XXXXXX)
swiftc tests/WhisperMetalResourceTests.swift -o "$test_dir/test-metal"
"$test_dir/test-metal" "${1:?Pass the packaged ggml-metal.metal path}"
