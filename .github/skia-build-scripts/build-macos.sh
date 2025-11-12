#!/usr/bin/env bash
set -euo pipefail

echo "=== macOS build script starting ==="

# Homebrew is usually installed on macOS runners; install if missing
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found, installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Set up brew environment if needed (common on Apple Silicon)
  if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv || true)"
  fi
fi

echo "=== Installing build deps (brew) ==="
brew update
brew install ninja python pkg-config freetype fontconfig

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
mkdir -p "$SKIA_OUT"
bin/gn gen "$SKIA_OUT" --args='is_official_build=true skia_enable_gpu=false skia_use_system_freetype2=true target_cpu="x64"'

echo "=== Building Skia (ninja) ==="
# macOS runners have limited cores; keep a small -j value
ninja -C "$SKIA_OUT" -j 2

echo "=== Copying headers and artifacts to repo root ==="
OUTDIR="${GITHUB_WORKSPACE:-$WORKDIR}/out"
rm -rf "$OUTDIR" || true
mkdir -p "$OUTDIR"
cp -r "$SKIA_OUT"/* "$OUTDIR/" || true
cp -r include "${GITHUB_WORKSPACE:-$WORKDIR}/skia/include" || true

echo "=== macOS build finished ==="
