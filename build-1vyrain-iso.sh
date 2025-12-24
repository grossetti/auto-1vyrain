#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="1vyrain:v1.0"
CONTAINER_NAME="1vyrain-build"
RESULT_DIR="$(pwd)/result"
ISO_PATH="$RESULT_DIR/1vyrain.iso"

echo "[1/5] Ensuring result directory exists: $RESULT_DIR"
mkdir -p "$RESULT_DIR"

echo "[2/5] Building Docker image: $IMAGE_NAME"
docker build --rm -t "$IMAGE_NAME" .

echo "[3/5] Removing any existing container named: $CONTAINER_NAME"
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "[4/5] Running container to generate ISO (detached)"
docker run -d --rm \
  --privileged \
  --name "$CONTAINER_NAME" \
  -v /dev:/dev \
  -v "$RESULT_DIR:/workspace/result" \
  "$IMAGE_NAME" >/dev/null

echo "[5/5] Waiting for container to finish..."
set +e
docker wait "$CONTAINER_NAME" >/dev/null
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "ERROR: Container exited with code $EXIT_CODE"
  echo "Container logs:"
  docker logs "$CONTAINER_NAME" || true
  exit "$EXIT_CODE"
fi

if [[ ! -f "$ISO_PATH" ]]; then
  echo "ERROR: Expected ISO not found at: $ISO_PATH"
  echo "Result directory contents:"
  ls -lah "$RESULT_DIR" || true
  echo "Container logs (if still accessible):"
  docker logs "$CONTAINER_NAME" || true
  exit 1
fi

echo "SUCCESS: ISO generated:"
ls -lah "$ISO_PATH"
