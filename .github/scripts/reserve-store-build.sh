#!/usr/bin/env bash
set -euo pipefail

case "$GITHUB_REF/$TARGET" in
  refs/heads/main/production|refs/heads/staging/staging) ;;
  *) echo "::error::Invalid store release destination"; exit 1 ;;
esac
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
repo="repos/$GITHUB_REPOSITORY"
if (( GITHUB_RUN_ATTEMPT > 1 )); then
  tip=$(gh api "$repo/git/ref/heads/$GITHUB_REF_NAME" --jq .object.sha)
  if [[ "$tip" != "$GITHUB_SHA" ]]; then
    echo "::error::This release was superseded. Dispatch the current branch tip."
    exit 1
  fi
fi

prefix=refs/tags/mobile-store-build/
previous=$(gh api --paginate "$repo/git/matching-refs/tags/mobile-store-build/" |
  jq -ser --arg prefix "$prefix" '[.[][] | .ref | ltrimstr($prefix) | tonumber] | max // "unseeded"')

if [[ "$previous" == unseeded ]]; then
  # Migrate once from the last release's prepared artifact, including full reruns.
  # Only the two deploy workflows on their assigned branches are trusted.
  echo "Initializing the counter from release history. If evidence has expired, seed the counter as described in docs/reference/ci-setup.md."
  previous_attempt=$(gh api --paginate "$repo/actions/runs?status=completed&per_page=100" |
    jq -ser '
      [.[].workflow_runs[] | select(.event == "push" or .event == "workflow_dispatch")
       | select((.path == ".github/workflows/deploy_testing.yml" and .head_branch == "staging") or
                (.path == ".github/workflows/deploy_live.yml" and .head_branch == "main"))]
      | max_by(.updated_at, .id) | select(. != null) | "\(.id)-\(.run_attempt)"')
  evidence=$(mktemp -d)
  trap 'rm -rf "$evidence"' EXIT
  gh run download "${previous_attempt%-*}" --repo "$GITHUB_REPOSITORY" \
    --name "prepared-$previous_attempt" --dir "$evidence"
  previous=$(jq -er --arg attempt "$previous_attempt" '
    select(.release == true and (.runId + "-" + .attempt) == $attempt)
    | .storeBuild | numbers | select(. > 0 and . == floor)' "$evidence/.ci-evidence/prepared.json")
fi

if ! [[ "$previous" =~ ^(0|[1-9][0-9]{0,7})$ ]] || (( previous >= 99989999 )); then
  echo "::error::Invalid or exhausted store build counter: $previous"
  exit 1
fi
next=$((previous + 1))
# Creating an existing ref fails even when two releases target the same SHA.
gh api --silent --method POST "$repo/git/refs" -f "ref=$prefix$next" -f "sha=$GITHUB_SHA"
echo "store_build=$next" >> "$GITHUB_OUTPUT"
echo "attempt=$GITHUB_RUN_ATTEMPT" >> "$GITHUB_OUTPUT"
echo "Reserved store build \`$next\`." >> "$GITHUB_STEP_SUMMARY"
