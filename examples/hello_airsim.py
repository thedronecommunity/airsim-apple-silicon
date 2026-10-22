#!/usr/bin/env python3
"""Quick AirSim test flight: take off, fly a square, land.

Uses the airsim package if you have it, otherwise cosysairsim.

    python hello_airsim.py                    # simulator on this Mac
    python hello_airsim.py --ip 192.168.1.50  # simulator on another machine
"""
import argparse
import sys

try:
    import airsim
except ImportError:
    try:
        import cosysairsim as airsim
    except ImportError:
        sys.exit("No AirSim client found. Run scripts/setup_python_client.sh first.")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--ip", default="127.0.0.1", help="IP of the machine running AirSim")
    parser.add_argument("--alt", type=float, default=5.0, help="flight altitude in metres")
    parser.add_argument("--side", type=float, default=10.0, help="square side length in metres")
    parser.add_argument("--speed", type=float, default=3.0, help="speed in m/s")
    args = parser.parse_args()

    client = airsim.MultirotorClient(ip=args.ip)
    client.confirmConnection()

    client.enableApiControl(True)
    client.armDisarm(True)
    try:
        print("Taking off...")
        client.takeoffAsync().join()

        # AirSim uses NED coordinates, so up is negative Z
        z = -abs(args.alt)
        client.moveToZAsync(z, 2).join()

        s = args.side
        for x, y in [(s, 0), (s, s), (0, s), (0, 0)]:
            print(f"Flying to x={x} y={y} alt={args.alt}")
            client.moveToPositionAsync(x, y, z, args.speed).join()

        pos = client.getMultirotorState().kinematics_estimated.position
        print(f"Back at start: x={pos.x_val:.1f} y={pos.y_val:.1f} z={pos.z_val:.1f}")

        print("Landing...")
        client.landAsync().join()
    finally:
        client.armDisarm(False)
        client.enableApiControl(False)
    print("Done.")


if __name__ == "__main__":
    main()
