#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:?usage: ci-api-dev-container.sh start|stop}"
BASE_REF="${2:-staging}"

OWNER="$(echo "${GITHUB_REPOSITORY_OWNER:-maya-invest}" | tr '[:upper:]' '[:lower:]')"
CONTAINER_NAME="${EDAYA_API_DEV_CONTAINER:-edaya-api-dev}"

case "$BASE_REF" in
  main|master) CHANNEL=production ;;
  *) CHANNEL=staging ;;
esac

IMAGE="${EDAYA_API_DEV_IMAGE:-ghcr.io/${OWNER}/edaya-api-dev:${CHANNEL}}"
PACKAGE_SETTINGS_URL="https://github.com/orgs/${OWNER}/packages/container/edaya-api-dev/settings"

case "$ACTION" in
  start)
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
      echo "Using local image: $IMAGE"
    elif ! docker pull "$IMAGE"; then
      echo "Failed to pull $IMAGE" >&2
      echo "One-time org setup (private package):" >&2
      echo "  1. Open $PACKAGE_SETTINGS_URL" >&2
      echo "  2. Manage Actions access → Add repository → ${GITHUB_REPOSITORY} → Role: Read" >&2
      echo "  3. Repeat for each consumer repo (edaya_web, edaya_mobile)" >&2
      echo "Alternative: Change package visibility to Public (anonymous docker pull)." >&2
      exit 1
    fi
    docker run \
      --name "$CONTAINER_NAME" \
      --detach \
      --rm \
      --publish 127.0.0.1:9999:9999 \
      --publish 127.0.0.1:9200:9200 \
      --memory 4g \
      "$IMAGE"
    for i in $(seq 1 60); do
      if curl -sf http://127.0.0.1:9999/reference > /dev/null; then
        echo "API dev container ready: $IMAGE"
        exit 0
      fi
      sleep 2
    done
    echo "Timed out waiting for API dev container: $IMAGE" >&2
    exit 1
    ;;
  stop)
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
