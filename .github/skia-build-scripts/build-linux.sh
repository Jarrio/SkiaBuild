#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== Installing build deps (apt) ==="
sudo apt-get update -y
sudo apt-get install -y git curl python3 python3-pip python3-venv build-essential clang pkg-config libfreetype6-dev libfontconfig1-dev ninja-build

WORKDIR="$PWD/skia-build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "=== Cloning depot_tools ==="
if [ ! -d depot_tools ]; then
  git clone --depth=1 https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi
export PATH="$PWD/depot_tools:$PATH"

echo "=== Cloning Skia (shallow) ==="
if [ ! -d skia ]; then
  git clone --depth=1 https://skia.googlesource.com/skia.git
fi

cd skia

echo "=== Syncing Skia deps ==="
python3 tools/git-sync-deps

echo "=== Generating ninja build (GN) ==="
# Simple Release build; disable GPU to avoid GPU drivers issues on CI.
python3 tools/git-sync-deps  # run again if needed for some systems (no-op if deps already there)
mkdir -p "$SKIA_OUT"
bin/gn gen "$SKIA_OUT" --args='is_official_build=true skia_enable_gpu=false skia_use_system_freetype2=true target_cpu="x64"'

echo "=== Building Skia (ninja) ==="
ninja -C "$SKIA_OUT" -j "$(nproc)"

echo "=== Copying headers and artifacts to repo root ==="
# copy artifacts to workspace root so workflow upload picks them up predictably
OUTDIR="${GITHUB_WORKSPACE:-$WORKDIR}/out"
rm -rf "$OUTDIR" || true
mkdir -p "$OUTDIR"
cp -r "$SKIA_OUT"/* "$OUTDIR/" || true
cp -r include "${GITHUB_WORKSPACE:-$WORKDIR}/skia/include" || true

echo "=== Build finished ==="
