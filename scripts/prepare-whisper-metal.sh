#!/usr/bin/env bash
# Metal's runtime source compiler does not resolve local #includes. Package
# ggml's matching common header inline, retaining its Metal preprocessor guards.
set -euo pipefail
cd "$(dirname "$0")/.."
output="${1:?Pass output ggml-metal.metal path}"
awk -v header="Vendor/whisper.cpp/ggml/src/ggml-common.h" '
    /^#include "ggml-common.h"$/ {
        while ((getline line < header) > 0) print line
        close(header)
        next
    }
    { print }
' Vendor/whisper.cpp/ggml/src/ggml-metal.metal > "$output"
