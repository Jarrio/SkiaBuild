# PowerShell script for windows-latest
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== Windows build script starting ==="

# Ensure git is available (should be on windows-latest)
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git not found on PATH"
}

$WorkDir = Join-Path $env:RUNNER_WORKSPACE "skia-build"
if (-Not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }
Set-Location $WorkDir

if (-Not (Test-Path depot_tools)) {
  git clone --depth=1 https://chromium.googlesource.com/chromium/tools/depot_tools.git
}
# Add depot_tools to PATH for this script
$env:PATH = (Join-Path $WorkDir "depot_tools") + ";" + $env:PATH

if (-Not (Test-Path skia)) {
  git clone --depth=1 https://skia.googlesource.com/skia.git
}
Set-Location (Join-Path $WorkDir "skia")

Write-Host "=== Syncing Skia deps ==="
python tools/git-sync-deps

Write-Host "=== Generating GN build files ==="
# Use x64 target
$skiaOut = "out\Release"
if (-Not (Test-Path $skiaOut)) { New-Item -ItemType Directory -Path $skiaOut | Out-Null }
.\bin\gn.exe gen $skiaOut --args='is_official_build=true skia_enable_gpu=false target_cpu="x64" skia_use_system_freetype2=true'

Write-Host "=== Running ninja build ==="
# ninja.exe should be in depot_tools or fetched as part of deps
ninja -C $skiaOut

Write-Host "=== Copying artifacts to workspace ==="
$OutDir = Join-Path $env:GITHUB_WORKSPACE "out"
if (Test-Path $OutDir) { Remove-Item -Recurse -Force $OutDir }
New-Item -ItemType Directory -Path $OutDir | Out-Null
Copy-Item -Path "$skiaOut\*" -Destination $OutDir -Recurse -Force -ErrorAction SilentlyContinue

# Copy headers
if (Test-Path "include") {
  $destInclude = Join-Path $env:GITHUB_WORKSPACE "skia\include"
  if (Test-Path $destInclude) { Remove-Item -Recurse -Force $destInclude }
  Copy-Item -Path "include" -Destination (Join-Path $env:GITHUB_WORKSPACE "skia") -Recurse -Force
}

Write-Host "=== Windows build finished ==="
