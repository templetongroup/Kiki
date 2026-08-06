#!/bin/bash
# Downloads a Whisper ggml model into Kiki's models folder.
# Usage: scripts/download-model.sh [model]
#   model: large-v3-turbo (default, ~1.6 GB), small.en (~466 MB),
#          base.en (~142 MB), medium.en, large-v3-turbo-q5_0 (~547 MB), ...
# Source: https://huggingface.co/ggerganov/whisper.cpp (official whisper.cpp models)
set -euo pipefail

MODEL="${1:-large-v3-turbo}"
DEST_DIR="$HOME/Library/Application Support/Kiki/models"
DEST="$DEST_DIR/ggml-$MODEL.bin"
URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$MODEL.bin"

mkdir -p "$DEST_DIR"
if [ -f "$DEST" ]; then
    echo "Already installed: $DEST"
    exit 0
fi

echo "Downloading ggml-$MODEL.bin ..."
curl -L --fail --progress-bar -o "$DEST.partial" "$URL"
mv "$DEST.partial" "$DEST"
echo "Installed: $DEST"
