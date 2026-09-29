#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
app_binary="${1:-build/Kiki.app/Contents/MacOS/Kiki}"
for dependency in say ffmpeg node; do
    command -v "$dependency" >/dev/null || { echo "Missing integration-test dependency: $dependency" >&2; exit 2; }
done
test_dir=$(mktemp -d /tmp/kiki-boundary-integration.XXXXXX)
trap 'rm -f "$test_dir/source.aiff" "$test_dir/mixed.wav" "$test_dir/result.json"; rmdir "$test_dir"' EXIT
say -v Samantha -r 170 -f tests/fixtures/meeting-boundary.txt -o "$test_dir/source.aiff"
# Fixed noise prevents the pause picker from avoiding the hard boundary. The
# fixed lead-in puts the price sentence across 30s; no private audio is used.
ffmpeg -hide_banner -loglevel error -i "$test_dir/source.aiff" \
    -f lavfi -i 'anoisesrc=color=pink:amplitude=0.008:sample_rate=16000:duration=62:seed=7' \
    -filter_complex '[0:a]adelay=22000:all=1[a];[a][1:a]amix=inputs=2:duration=longest:normalize=0[out]' \
    -map '[out]' -ar 16000 -ac 1 -c:a pcm_s16le "$test_dir/mixed.wav"
"$app_binary" --transcribe-meeting-json "$test_dir/mixed.wav" > "$test_dir/result.json"
node - "$test_dir/result.json" <<'JS'
const fs = require('fs');
const entries = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
for (const expected of [
  'The archive license costs $4 to $5, not $45.',
  'Do not assign a date that nobody mentioned.'
]) {
  if (entries.filter(x => x.text === expected).length !== 1) {
    throw new Error('Boundary sentence must occur once, intact: ' + expected);
  }
}
if (entries.some(x => !Number.isFinite(x.startTime) || x.endTime < x.startTime)) {
  throw new Error('Invalid acoustic time range');
}
console.log('PASS: actual Parakeet meeting path preserves complete boundary sentences, amounts and negation');
JS
