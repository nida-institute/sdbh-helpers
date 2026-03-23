#!/usr/bin/env zsh
# verb-report.sh — Run the verb subject report pipeline for one or more Hebrew verbs.
#
# Usage:
#   ./verb-report.sh הָיָה
#   ./verb-report.sh "הָיָה הָלַךְ"       # space-delimited
#   ./verb-report.sh "הָיָה,הָלַךְ"       # comma-delimited
#   ./verb-report.sh הָיָה הָלַךְ         # positional args
#
# Each verb produces output/<verb>.md and output/<verb>-subject-data.json.

set -euo pipefail

PIPELINE="pipelines/verb-subject-report.yaml"

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <verb> [verb2 verb3 ...]" >&2
    echo "       $0 \"verb1,verb2,verb3\"" >&2
    exit 1
fi

# Collect all args, split on commas and spaces
raw_input="${(j: :)@}"                        # join positional args with spaces
raw_input="${raw_input//,/ }"                 # replace commas with spaces
verbs=(${(z)raw_input})                       # word-split into array

echo "Verbs to process: ${verbs[*]}"
mkdir -p output

for verb in "${verbs[@]}"; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "▶  Processing: ${verb}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    python3 -c "from llmflow.cli import main; main()" -- run \
        --pipeline "${PIPELINE}" \
        --var "lemma=${verb}"
done

echo ""
echo "Done. Reports written to output/"
