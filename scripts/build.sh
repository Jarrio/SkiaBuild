#!/usr/bin/env bash
# Builds Skia for one target. Runs unchanged on Linux, macOS and Windows (Git Bash).
# Required env: SKIA_BRANCH, TARGET_OS, TARGET_CPU. Optional: EXTRA_ARGS.
set -euo pipefail

: "${SKIA_BRANCH:?}" "${TARGET_OS:?}" "${TARGET_CPU:?}"
EXTRA_ARGS="${EXTRA_ARGS:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="out/Release"

if [ ! -d skia ]; then
  git clone -b "$SKIA_BRANCH" --depth 1 https://skia.googlesource.com/skia.git
fi
cd skia

# Syncing ~45 repos in parallel sometimes drops a connection; a rerun resumes.
for attempt in 1 2 3; do
  if python tools/git-sync-deps; then
    break
  fi
  if [ "$attempt" = 3 ]; then
    echo "git-sync-deps failed 3 times" >&2
    exit 1
  fi
  echo "=== git-sync-deps failed, retrying ($attempt/3) ==="
  sleep 10
done
python bin/fetch-ninja

mkdir -p "$OUT"
{
  cat "$ROOT/config/common.gn"
  echo ""
  echo "target_os = \"$TARGET_OS\""
  echo "target_cpu = \"$TARGET_CPU\""
  if [ "$TARGET_OS" = "android" ]; then
    echo "ndk = \"$ANDROID_NDK_LATEST_HOME\""
  fi
  echo "$EXTRA_ARGS"
} > "$OUT/args.gn"

echo "=== args.gn ==="
cat "$OUT/args.gn"

bin/gn gen "$OUT"
third_party/ninja/ninja -C "$OUT"
