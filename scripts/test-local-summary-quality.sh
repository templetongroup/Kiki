#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/kiki-local-quality.XXXXXX)
trap 'rm -f "$test_dir/draft.json" "$test_dir/notes.md" "$test_dir/access.json" "$test_dir/access.md"; rmdir "$test_dir"' EXIT
KIKI_LOCAL_SUMMARY_MODEL="${KIKI_LOCAL_SUMMARY_MODEL:-qwen3.5:9b}" \
KIKI_EVALUATION_DRAFT_PATH="$test_dir/draft.json" \
  bash scripts/test-meeting-summary.sh --evaluate tests/fixtures/meeting-summary-corrections.md > "$test_dir/notes.md"
node - "$test_dir/draft.json" "$test_dir/notes.md" <<'JS'
const fs = require('fs');
const notes = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const output = fs.readFileSync(process.argv[3], 'utf8');
const tasks = notes.actions.map(x => x.task.toLowerCase());
function check(condition, label) {
  if (!condition) {
    console.error(JSON.stringify(notes, null, 2));
    throw new Error(label);
  }
}
check(tasks.length >= 2 && tasks.length <= 3, 'Retain both commitments; only the explicitly unassigned driver decision may be an additional task');
check(tasks.every(x => /volume|floor plan|driv.*van|van.*driv/.test(x)), 'No unsupported extra tasks');
check(tasks.some(x => /volume/.test(x) && /priya/.test(x)), 'Retain the overall box-volume follow-up and recipient');
check(tasks.some(x => /floor plan/.test(x) && /morgan/.test(x) && /tomorrow/.test(x)), 'Retain the late floor-plan commitment, recipient and spoken deadline');
check(!tasks.some(x => /courier|printer|locker/.test(x)), 'Do not promote cancelled or hypothetical work into tasks');
check(!notes.openQuestions.some(x => /contract|offsite/.test(x.toLowerCase())), 'Later answer must resolve the earlier contract question');
check(!notes.points.some(x => /storage/i.test(x.text) && /requires verification|needs? (?:to be )?confirm/i.test(x.text)), 'Do not retain superseded contract uncertainty as a current key point');
check(/exclud|not includ|only.*main warehouse/i.test(notes.points.map(x => x.text).join(' ')), 'Preserve the corrected contract scope');
check(!output.includes('Incomplete draft'), 'All expected evidence must survive rendering');
check(/volume/i.test(output.split('## Next steps')[1] || ''), 'Do not silently filter the volume action');
check(/floor plan/i.test(output.split('## Next steps')[1] || ''), 'Do not silently filter the late action');
console.log('PASS: local model retains both commitments, resolves late correction, omits cancelled work, and renders grounded notes');
JS
KIKI_LOCAL_SUMMARY_MODEL="${KIKI_LOCAL_SUMMARY_MODEL:-qwen3.5:9b}" \
KIKI_EVALUATION_DRAFT_PATH="$test_dir/access.json" \
  bash scripts/test-meeting-summary.sh --evaluate tests/fixtures/meeting-summary-access-order.md > "$test_dir/access.md"
node - "$test_dir/access.json" "$test_dir/access.md" <<'JS'
const fs = require('fs');
const notes = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const output = fs.readFileSync(process.argv[3], 'utf8');
const tasks = notes.actions.map(x => x.task.toLowerCase());
function check(condition, label) {
  if (!condition) throw new Error(label + '\n' + JSON.stringify(notes, null, 2));
}
check(tasks.length === 3, 'Retain three distinct commitments, without screen-navigation or hypothetical-purchase tasks');
check(tasks.some(x => /sam/.test(x) && /casey/.test(x) && /(?:price|cost)/.test(x) && /(?:service|backup)/.test(x)), 'Keep backup service/pricing deliverable, owner and recipient');
check(tasks.some(x => /casey/.test(x) && /riley/.test(x) && /inventory/.test(x) && /next few days/.test(x)), 'Keep late equipment inventory deliverable and timing');
const admin = tasks.find(x => /account/.test(x) && /admin/.test(x));
check(admin && /sam/.test(admin) && /password/.test(admin) && /mfa/.test(admin), 'Keep account creation and both prerequisites');
check(/(?:after|before|only|first)/.test(admin) && !/(?:admin(?:istrator)? access first|mfa later)/.test(admin), 'Do not reverse access/MFA order');
check(!tasks.some(x => /buy|purchase|order an? appliance/.test(x)), 'Do not turn a historical or hypothetical purchase into a commitment');
check(!notes.points.some(x => /already has an account|account exists/.test(x.text.toLowerCase()) && !/not|incorrect|guess/.test(x.text.toLowerCase())), 'Resolve the later account correction');
check(!output.includes('Incomplete draft'), 'All expected evidence must survive rendering');
console.log('PASS: independent handover case retains pricing, inventory and correct access prerequisites without inventing a purchase');
JS
