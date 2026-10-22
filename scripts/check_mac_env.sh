#!/usr/bin/env bash
# Checks whether this Mac is ready for AirSim. Only looks, never installs anything.
# Usage: bash scripts/check_mac_env.sh

PASS=0; WARN=0; FAIL=0
ok()   { printf "  \033[32m[ OK ]\033[0m %s\n" "$1"; PASS=$((PASS+1)); }
warn() { printf "  \033[33m[WARN]\033[0m %s\n" "$1"; WARN=$((WARN+1)); }
bad()  { printf "  \033[31m[FAIL]\033[0m %s\n" "$1"; FAIL=$((FAIL+1)); }

# true if version $1 >= $2
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

if [ "$(uname)" != "Darwin" ]; then
  echo "This checker is for macOS only."; exit 1
fi

echo "== System =="
ARCH="$(uname -m)"
MACOS="$(sw_vers -productVersion)"
echo "  macOS $MACOS on $ARCH"
if [ "$ARCH" = "arm64" ]; then
  APPLE_SILICON=1
  if /usr/bin/pgrep -q oahd || arch -x86_64 /usr/bin/true 2>/dev/null; then
    ok "Rosetta 2 is installed (needed for Unreal 4.27)"
  else
    bad "Rosetta 2 missing. Run: softwareupdate --install-rosetta --agree-to-license"
  fi
else
  APPLE_SILICON=0
  ok "Intel Mac (native Unreal 4.27 path)"
fi

echo "== Developer tools =="
if xcode-select -p >/dev/null 2>&1; then
  ok "Command line tools at $(xcode-select -p)"
else
  bad "No Xcode command line tools. Run: xcode-select --install"
fi
if XCV="$(xcodebuild -version 2>/dev/null | head -n1)"; [ -n "$XCV" ]; then
  ok "$XCV"
else
  warn "Full Xcode not found. You need it to open Blocks.xcworkspace."
fi
if command -v brew >/dev/null 2>&1; then
  ok "Homebrew at $(brew --prefix)"
  if [ -x "$(brew --prefix)/opt/llvm/bin/clang" ]; then
    ok "Homebrew llvm present (used by AirSim build.sh)"
  else
    warn "Homebrew llvm missing. AirSim's setup.sh installs it."
  fi
else
  bad "Homebrew missing. Install from https://brew.sh"
fi
if command -v cmake >/dev/null 2>&1; then
  CMV="$(cmake --version | head -n1 | awk '{print $3}')"
  if version_ge "$CMV" "3.19.2"; then ok "cmake $CMV (>= 3.19.2)"
  else bad "cmake $CMV is too old. Need >= 3.19.2: brew upgrade cmake"; fi
else
  warn "cmake missing. AirSim's setup.sh installs it."
fi

echo "== Unreal Engine =="
UE_ROOT="/Users/Shared/Epic Games"
FOUND_UE=0
for d in "$UE_ROOT"/UE_*; do
  [ -d "$d" ] || continue
  FOUND_UE=1
  case "$(basename "$d")" in
    UE_4.27) ok "Found $d (AirSim, options 2 and 3)";;
    UE_5.3)  ok "Found $d (Colosseum, option 4)";;
    *)       warn "Found $d (not the version AirSim or Colosseum expect)";;
  esac
done
[ $FOUND_UE -eq 1 ] || warn "No Unreal Engine in $UE_ROOT. Install 4.27 from the Epic Games Launcher, or run the sim on another machine (option 1)."

echo "== Python client =="
GOOD_PY=""
for v in 3.11 3.10 3.9; do
  if command -v "python$v" >/dev/null 2>&1; then GOOD_PY="python$v"; break; fi
done
if [ -n "$GOOD_PY" ]; then
  ok "$GOOD_PY found (works with the original 'airsim' package)"
else
  warn "No Python 3.9-3.11. Original 'airsim' fails on 3.12+. Run: brew install python@3.11 (or use cosysairsim)"
fi
if command -v python3 >/dev/null 2>&1; then
  PV="$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')"
  if version_ge "$PV" "3.12"; then
    warn "Default python3 is $PV. Use a 3.11 venv for 'airsim', or 'cosysairsim'."
  else
    ok "Default python3 is $PV"
  fi
fi

echo "== AirSim settings =="
SETTINGS="$HOME/Documents/AirSim/settings.json"
if [ -f "$SETTINGS" ]; then
  if python3 -m json.tool "$SETTINGS" >/dev/null 2>&1; then
    ok "$SETTINGS is valid JSON"
  else
    bad "$SETTINGS is not valid JSON. AirSim will refuse to start."
  fi
else
  warn "No $SETTINGS yet. Copy one from the settings folder in this repo"
fi

echo
echo "== Summary: $PASS ok, $WARN warnings, $FAIL failures =="
echo
if [ $FOUND_UE -eq 0 ]; then
  echo "Suggested: option 1 (AirSim on a Windows/Linux PC, SITL and Python here) or option 5 (a Mac-native sim)."
elif [ $APPLE_SILICON -eq 1 ]; then
  echo "Suggested: option 3 (Unreal 4.27 under Rosetta). Option 1 is more reliable if you have a PC around."
else
  echo "Suggested: option 2 (native build on Intel)."
fi
echo "More detail in the README."
[ $FAIL -eq 0 ]
