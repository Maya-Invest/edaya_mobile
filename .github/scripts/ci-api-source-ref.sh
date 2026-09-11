#!/usr/bin/env bash
# Map the consumer head branch to the Identity + school git ref.
# staging → staging, main/master → main, anything else → dev
set -euo pipefail

HEAD_REF="${1:?usage: ci-api-source-ref.sh <head-ref>}"
HEAD_REF="${HEAD_REF#refs/heads/}"

case "$HEAD_REF" in
	staging)
		echo staging
		;;
	main | master)
		echo main
		;;
	*)
		echo dev
		;;
esac
