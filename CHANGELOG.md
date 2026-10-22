# Changelog

## v1.0.0 (2026-10-22)

First release.

- README covering five ways to run AirSim on a Mac, with Apple Silicon first.
- Fixes for the AirSim Python client on Python 3.12 (the numpy build error and the tornado import error).
- `scripts/check_mac_env.sh` to look over your Mac and suggest a route.
- `scripts/setup_python_client.sh` to build a working client venv.
- `examples/hello_airsim.py`, a short test flight.
- Settings files for SimpleFlight, local ArduPilot SITL and remote ArduPilot SITL.
- CI that lints the scripts and validates the settings on every push.
