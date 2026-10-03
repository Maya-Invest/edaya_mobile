#!/usr/bin/env bash
# Fail with a clear message when Identity or school does not have the mapped branch.
set -euo pipefail

REF="${1:?usage: ci-assert-sibling-ref.sh <ref>}"
OWNER="${GITHUB_REPOSITORY_OWNER:-Maya-Invest}"
TOKEN="${IDENTITY_CHECKOUT_TOKEN:-}"

if [ -z "$TOKEN" ]; then
	echo "IDENTITY_CHECKOUT_TOKEN is required to read private sibling repos." >&2
	echo "Create a PAT with contents:read on ${OWNER}/edaya_backend," >&2
	echo "then add it as the IDENTITY_CHECKOUT_TOKEN repo secret." >&2
	exit 1
fi

export GH_TOKEN="$TOKEN"

assert_branch() {
	local repo="$1"
	if gh api "repos/${OWNER}/${repo}/branches/${REF}" --silent >/dev/null; then
		echo "Found ${OWNER}/${repo}@${REF}"
		return 0
	fi
	echo "Could not read ${OWNER}/${repo}@${REF}." >&2
	echo "Mobile integration starts the unified API (:9999) from that branch." >&2
	echo "Create ${REF} on ${OWNER}/${repo} (Identity needs dev, staging, and main)," >&2
	echo "and grant IDENTITY_CHECKOUT_TOKEN contents:read on both sibling repos." >&2
	exit 1
}

assert_branch edaya_backend
