#!/usr/bin/env bash
# Sets up a venv with an AirSim Python client that works on macOS.
#
#   bash scripts/setup_python_client.sh           # original 'airsim' (Python 3.9-3.11)
#   bash scripts/setup_python_client.sh --cosys   # 'cosysairsim' (Python 3.12+ OK)
#
# Set VENV=~/somewhere to put the venv somewhere else.
set -euo pipefail

MODE="airsim"
[ "${1:-}" = "--cosys" ] && MODE="cosys"

if [ "$MODE" = "cosys" ]; then
  VENV="${VENV:-$HOME/cosys-venv}"
  PY="$(command -v python3)"
else
  VENV="${VENV:-$HOME/airsim-venv}"
  PY=""
  for v in 3.11 3.10 3.9; do
    if command -v "python$v" >/dev/null 2>&1; then PY="$(command -v python$v)"; break; fi
  done
  if [ -z "$PY" ] && command -v python3 >/dev/null 2>&1; then
    if python3 -c 'import sys; sys.exit(0 if (3,9) <= sys.version_info[:2] < (3,12) else 1)'; then
      PY="$(command -v python3)"
    fi
  fi
  if [ -z "$PY" ]; then
    echo "The original 'airsim' client needs Python 3.9-3.11 (its tornado 4.x breaks on 3.12+)."
    echo "Install one with:  brew install python@3.11"
    echo "Or rerun with --cosys to use the maintained 'cosysairsim' client."
    exit 1
  fi
fi

echo "Using $PY ($("$PY" --version)) -> $VENV"
"$PY" -m venv "$VENV"
"$VENV/bin/python" -m pip install --quiet --upgrade pip setuptools wheel

if [ "$MODE" = "cosys" ]; then
  "$VENV/bin/pip" install --quiet cosysairsim
  "$VENV/bin/python" -c "import cosysairsim; print('cosysairsim client OK')"
else
  # airsim's setup.py imports numpy, so it has to be there first
  "$VENV/bin/pip" install --quiet numpy msgpack-rpc-python
  "$VENV/bin/pip" install --quiet --no-build-isolation airsim
  "$VENV/bin/python" -c "import airsim; print('airsim client OK')"
fi

echo
echo "Activate with:  source $VENV/bin/activate"
