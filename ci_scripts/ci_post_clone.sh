#!/bin/sh

set -eu

echo "========== Downloading Qwen Model =========="

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
MODEL_ROOT="$REPO_ROOT/UcapHutang/Resources/Models"
MODEL_NAME="Qwen3-0.6B-4bit"
MODEL_DIR="$MODEL_ROOT/$MODEL_NAME"
MODEL_ARCHIVE="${TMPDIR:-/tmp}/Qwen3-0.6B-4bit.zip"
MODEL_ASSET_URL="${QWEN_MODEL_ASSET_URL:-https://github.com/AdhiKrisna/UcapHutang/releases/download/model-qwen3-0.6b-v1/Qwen3-0.6B-4bit.zip}"
EXPECTED_SHA256="3eb0e4e690cae81104ef834e3dc5142edc3725786cec610fb00145d03d60e7f2"

rm -rf "$MODEL_DIR"
mkdir -p "$MODEL_ROOT"

curl --fail --location --retry 3 --retry-all-errors \
    "$MODEL_ASSET_URL" \
    --output "$MODEL_ARCHIVE"

ACTUAL_SHA256="$(shasum -a 256 "$MODEL_ARCHIVE" | awk '{print $1}')"
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
    echo "Model checksum mismatch." >&2
    echo "Expected: $EXPECTED_SHA256" >&2
    echo "Actual:   $ACTUAL_SHA256" >&2
    exit 1
fi

unzip -q -o "$MODEL_ARCHIVE" -d "$MODEL_ROOT"

for REQUIRED_FILE in config.json tokenizer.json tokenizer_config.json model.safetensors; do
    if [ ! -f "$MODEL_DIR/$REQUIRED_FILE" ]; then
        echo "Missing required model file: $MODEL_DIR/$REQUIRED_FILE" >&2
        exit 1
    fi
done

rm -f "$MODEL_ARCHIVE"

echo "========== Qwen Model Ready =========="
echo "$MODEL_DIR"
