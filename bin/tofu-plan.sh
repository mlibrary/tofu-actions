#!/bin/bash

set -uo pipefail

OUTPUT_FLAG="${STACK_PATH_TO_ROOT}/_TERRAMATE_OUTPUT_WRITTEN"
OUTPUT_FILE="${STACK_PATH_TO_ROOT}/_TERRAMATE_OUTPUT_${STACK_ID}.txt"

touch "$OUTPUT_FLAG"

(
  set -x
  exec tofu plan \
    ${NO_PLAN_REFRESH:+-refresh=false} \
    ${PARALLELISM:+-parallelism=$PARALLELISM} \
    -detailed-exitcode \
    -out tfplan
); ret=$?

# it's expected that `tofu plan` may return non-zero
# any other non-zero returns are unexpected failures
set -e

echo "#### ${STACK_PATH}" > "$OUTPUT_FILE"
if (( ret == 1 )); then
  echo $'Planning failed. See log for details.\n' >> "$OUTPUT_FILE"
  exit 1
fi

tofu show tfplan -no-color | grep -E '^(Plan:|No changes)' >> "$OUTPUT_FILE"

if (( ret == 2 )); then
  # print plan summary in diff-like format for GitHub Markdown `diff` formatter
  tofu show tfplan -no-color \
  | awk '
    BEGIN {
      print ""
      print "```diff"
    }
    # We could skip a few other patterns, but this one is really chatty.
    # https://github.com/opentofu/opentofu/blob/e6a0d6fc5ef2bbe2602bac9978a5baf3f1154723/internal/command/jsonformat/plan.go#L506
    /^  # \(because key \[".*"\] is not in for_each map\)$/ {
      next
    }
    /^  #/ {
      sub(/^  /, "")
      if ($0 ~ / will be created$/) sub(/^#/, "+")
      else if ($0 ~ / will be updated in-place$/) sub(/^#/, "!")
      else if ($0 ~ / must be replaced$/) sub(/^#/, "!")
      else if ($0 ~ / will be destroyed$/) sub(/^#/, "-")
      print
    }
    END {
      print "```"
    }
  ' >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"
