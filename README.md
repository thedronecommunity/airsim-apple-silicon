# AirSim on Apple Silicon

Getting [AirSim](https://github.com/microsoft/AirSim) running on an M1, M2, M3 or M4 Mac, plus the Intel notes we picked up along the way.

AirSim is one of the nicest ways to test vision and AI code before you fly, but on a Mac it fights you at every step. Windows and Linux get prebuilt binaries and working CI. The Mac gets a build page that says only Catalina was ever tested. This repo is what we wish we'd had: which routes actually work, what breaks, how to get around it, and a few scripts so you don't have to type everything by hand.

Part of [The Complete Drone Guide](https://github.com/thedronecommunity/complete-drone-guide) by The Drone Community.

---

## What's in here

```
scripts/check_mac_env.sh        looks over your Mac and suggests a route (changes nothing)
scripts/setup_python_client.sh  builds a venv with an AirSim client that actually imports
examples/hello_airsim.py        takeoff, fly a square, land
settings/                       ready-made settings.json files
```

## Quick start

```bash
git clone https://github.com/thedronecommunity/airsim-apple-silicon.git
cd airsim-apple-silicon

# 1. see what your Mac has and which route fits
bash scripts/check_mac_env.sh

# 2. get a working Python client
bash scripts/setup_python_client.sh
source ~/airsim-venv/bin/activate

# 3. AirSim reads its settings from here on macOS
mkdir -p ~/Documents/AirSim
cp settings/settings-simpleflight.json ~/Documents/AirSim/settings.json

# 4. start AirSim, press Play in Unreal, then
python examples/hello_airsim.py
```

If you see `Connected!` and the drone takes off in Unreal, you're done. If not, read on.

---

## Why it's awkward on a Mac

There are three separate problems, and it helps to know which one you're fighting.

**The project.** Microsoft stopped adding features to AirSim in 2022 and the repo only gets maintenance commits now. Its macOS CI used GitHub runners for macOS 10.15 and 11, which no longer exist, so nobody is checking that the Mac build still compiles.

**Unreal.** AirSim targets Unreal Engine 4.27, which is an Intel-only app. On Apple Silicon it runs through Rosetta. That works, but it's slow, and recent Xcode versions are stricter than 4.27 expects, so you can hit compiler errors inside Unreal's own headers.

**The Python client.** This one catches almost everyone, even people whose simulator runs fine. The `airsim` package depends on `msgpack-rpc-python`, last updated in 2018, which pins tornado to version 4. Tornado 4 doesn't import on Python 3.12, and 3.12 is what Homebrew gives you by default.

---

## Fixing the Python client

Start here whichever route you take, because they all need it.

On Python 3.12 you'll usually hit one of two errors. The first comes from `pip install airsim`, because its setup script imports numpy before pip has installed it:

```
ModuleNotFoundError: No module named 'numpy'
ERROR: Failed to build 'airsim' when getting requirements to build wheel
```

The second shows up once it's installed and you try to import it. That's tornado 4 reaching for an `ssl` function that 3.12 removed:

```
File ".../tornado/netutil.py", line 56, in <module>
    import backports.ssl_match_hostname
ModuleNotFoundError: No module named 'backports'
```

The simplest fix is an older Python for this one project. Anything from 3.9 to 3.11 is fine. Install numpy and the RPC library first, then airsim with build isolation off so it can see the numpy you just installed:

```bash
brew install python@3.11
python3.11 -m venv ~/airsim-venv
source ~/airsim-venv/bin/activate

pip install --upgrade pip setuptools wheel
pip install numpy msgpack-rpc-python
pip install --no-build-isolation airsim

python -c "import airsim; print('airsim OK')"
```

If you're on the [Cosys-AirSim](https://github.com/Cosys-Lab/Cosys-AirSim) fork instead, skip all that. Its client, `cosysairsim`, swapped the old RPC library for a maintained one and installs cleanly on 3.12:

```bash
python3 -m venv ~/cosys-venv
source ~/cosys-venv/bin/activate
pip install cosysairsim
```

Keep the client and the simulator from the same family. `cosysairsim` is meant for Cosys-AirSim, and `airsim` is meant for Microsoft AirSim and Colosseum. Mixing them might work for basic calls but isn't guaranteed.

The setup script does the same steps for you:

```bash
bash scripts/setup_python_client.sh          # original airsim client
bash scripts/setup_python_client.sh --cosys  # cosysairsim client
```

We tested both on an M-series Mac running macOS 26. The original client installed fine on 3.9 and 3.11 and failed on 3.12 with exactly the errors above. `cosysairsim` installed fine on 3.9 and 3.12.

---

## Pick a route

| Your situation | Route |
|----------------|-------|
| You have any Windows or Linux PC around | Option 1, the most reliable |
| Intel Mac | Option 2 |
| Apple Silicon, want it all on the Mac | Option 3 |
| Apple Silicon, curious about Unreal 5 | Option 4, experimental |
| You just need a working 3D sim today | Option 5 |

The checker script suggests one of these based on what it finds.

### Option 1: Simulator on another machine

If you have any Windows or Linux PC, even an old gaming laptop, this is the way to go. Let Unreal and AirSim run where they're properly supported, and keep ArduPilot SITL, your Python code and QGroundControl on the Mac. Everything talks over the network.

```
┌───────────────────────┐   UDP 9003 (sensor data)  ┌──────────────────────┐
│  Windows / Linux PC   │ ────────────────────────▶ │       Your Mac       │
│  AirSim + Unreal      │                           │  ArduPilot SITL      │
│                       │ ◀──────────────────────── │  Python scripts      │
│                       │   UDP 9002 (motor output) │  QGroundControl      │
│                       │ ◀──────────────────────── │                      │
│                       │   TCP 41451 (Python API)  │                      │
└───────────────────────┘                           └──────────────────────┘
```

On the PC, grab a prebuilt environment from the [AirSim releases page](https://github.com/microsoft/AirSim/releases). Copy `settings/settings-arducopter-remote.json` to `Documents\AirSim\settings.json` and change `UdpIp` to your Mac's IP address. `LocalHostIp` is already `0.0.0.0`, so the PC listens on every network. Let UDP 9002 and TCP 41451 through the firewall, then start the environment.

On the Mac, set up ArduPilot once with its macOS script:

```bash
git clone --recursive https://github.com/ArduPilot/ardupilot.git
cd ardupilot
Tools/environment_install/install-prereqs-mac.sh -y
source ~/.zshrc
```

Then start SITL pointed at the PC (use your PC's real IP):

```bash
cd ArduCopter
sim_vehicle.py -v ArduCopter -f airsim-copter --console --map \
    -A "--sim-address=192.168.1.50"
```

The Python side connects the same way:

```bash
python examples/hello_airsim.py --ip 192.168.1.50
```

Use a cable if you can. Sensor and motor packets go back and forth every few milliseconds, and Wi-Fi jitter shows up as a drone that wobbles for no obvious reason.

### Option 2: Native build on an Intel Mac

Intel Macs have the easiest local setup, because Unreal 4.27 runs natively.

Install Xcode from the App Store, then the command line tools, and accept the licence:

```bash
xcode-select --install
sudo xcodebuild -license accept
```

You'll also need [Homebrew](https://brew.sh).

Install Unreal 4.27 through the [Epic Games Launcher](https://www.unrealengine.com/download). It needs a free account. In the launcher, go to Library, add an engine version and pick 4.27. It installs to `/Users/Shared/Epic Games/UE_4.27`.

Build AirSim. `setup.sh` pulls in cmake, llvm and eigen through Homebrew, and `build.sh` compiles AirLib and the Unreal plugin:

```bash
git clone https://github.com/microsoft/AirSim.git
cd AirSim
./setup.sh
./build.sh
```

Open the Blocks environment that ships with AirSim:

```bash
cd Unreal/Environments/Blocks
./GenerateProjectFiles.sh "/Users/Shared/Epic Games/UE_4.27"
open Blocks.xcworkspace
```

In Xcode choose the BlocksEditor scheme and hit Run. When the Unreal editor opens, press Play.

One small thing that saves a lot of confusion: in Unreal, open Edit, then Editor Preferences, search for "CPU" and untick "Use Less CPU when in Background". Otherwise the sim crawls every time you click into your terminal.

### Option 3: Apple Silicon through Rosetta

Follow Option 2 with a few additions. Unreal 4.27 is an Intel app, so it runs under Rosetta, and AirSim's plugin has to be built for Intel too so the editor can load it. The good news is that AirSim's `build.sh` already does this. On macOS it passes `-DCMAKE_APPLE_SILICON_PROCESSOR=x86_64` to cmake for you.

Before building, install Rosetta and make sure cmake is at least 3.19.2, since older versions ignore that flag:

```bash
softwareupdate --install-rosetta --agree-to-license
cmake --version
```

Then `./setup.sh` and `./build.sh` as before.

The problems people hit most often on this route:

| What you see | What's going on | Fix |
|--------------|-----------------|-----|
| The Apple Silicon flag seems ignored | cmake older than 3.19.2 | `brew upgrade cmake` |
| "Plugin was built for a different architecture" | AirLib got built as arm64 | Delete `build_release/` and run `./build.sh` again |
| `clang: not found` under `/usr/local/opt/llvm` | Old instructions written for Intel Homebrew | Pull the latest AirSim. `build.sh` now uses `$(brew --prefix)`, which is `/opt/homebrew` on Apple Silicon |
| Compiler errors inside Unreal 4.27 headers | Newer Xcode is stricter than 4.27 expects | Install an older Xcode from [Apple's developer downloads](https://developer.apple.com/download/all/) and switch with `sudo xcode-select -s` |
| Very low frame rate | Rosetta plus graphics translation | Lower the editor's scalability settings and stick to a small map like Blocks |

Be honest with yourself about time here. This route can easily eat an afternoon. If there's a PC you can borrow, Option 1 gets you flying faster.

### Option 4: Colosseum and Unreal 5 (experimental)

[Colosseum](https://github.com/CodexLabsLLC/Colosseum) is a community fork of AirSim that moved to Unreal Engine 5. Unreal 5 runs natively on Apple Silicon, so in theory this takes Rosetta out of the picture.

```bash
git clone https://github.com/CodexLabsLLC/Colosseum.git
cd Colosseum
./setup.sh
./build.sh

cd Unreal/Environments/BlocksV2
./GenerateProjectFiles.sh "/Users/Shared/Epic Games/UE_5.3"
open Blocks.xcworkspace
```

Colosseum's own docs say macOS isn't currently supported and may not work. Worth a try if you're curious, but don't build a project on it.

[Cosys-AirSim](https://github.com/Cosys-Lab/Cosys-AirSim) is the other active fork. It's on Unreal 5.5 with a lot of extra sensors, but it officially targets Windows and Linux. There's Apple Silicon work in its pull requests that hasn't made a release yet.

### Option 5: Skip AirSim for now

Sometimes the right answer is to not fight it. ArduPilot SITL with its built-in physics runs natively and is enough for missions, failsafes and all your MAVLink code. Webots has a native Apple Silicon build and ships a Mavic model with a camera, which covers a lot of vision testing. Gazebo installs through Homebrew with partial macOS support and fits well with ROS 2.

None of it is wasted effort. The MAVLink and mission code you write against these carries straight over to AirSim later.

---

## Settings files

Copy whichever fits to `~/Documents/AirSim/settings.json`.

| File | Use it when |
|------|-------------|
| `settings-simpleflight.json` | You want AirSim's built-in flight controller, driven from Python. Easiest first test. |
| `settings-arducopter.json` | ArduPilot SITL and AirSim run on the same Mac. |
| `settings-arducopter-remote.json` | AirSim is on a PC and SITL is on your Mac (Option 1). |

In the ArduPilot files, four fields do the work. `UdpIp` is the address of the machine running SITL. `UdpPort` (9003) is where ArduPilot receives sensor data. `ControlPort` (9002) is where AirSim receives motor outputs. `LocalHostIp` is AirSim's own address, and `0.0.0.0` means listen on every network.

Always start AirSim first and press Play, then start SITL:

```bash
sim_vehicle.py -v ArduCopter -f airsim-copter --console --map
```

---

## When things go wrong

**Python can't import airsim.** Check your Python version first. On 3.12 or newer, make a 3.11 venv or switch to `cosysairsim`. If pip complains about numpy, install numpy on its own, then install airsim with `--no-build-isolation`.

**The script sits on "Waiting for connection".** Usually Unreal isn't in Play mode, the IP is wrong (pass `--ip` with the simulator machine's address), or a firewall is blocking TCP 41451.

**SITL says no sensor data, or the drone won't arm.** You probably started SITL before AirSim was playing, so restart SITL. Also check that `UdpIp` really is the SITL machine's address and that `VehicleType` says `ArduCopter`, not `SimpleFlight`.

**The build fails.** The usual suspects are cmake older than 3.19.2, an Xcode too new for Unreal 4.27, or a leftover arm64 build. For the last one, delete `build_release` and build again.

---

## Further reading

- [AirSim: Build on macOS](https://microsoft.github.io/AirSim/build_macos/)
- [Colosseum: Build on macOS](https://codexlabsllc.github.io/Colosseum/build_macos/)
- [Cosys-AirSim](https://github.com/Cosys-Lab/Cosys-AirSim)
- [ArduPilot: Using SITL with AirSim](https://ardupilot.org/dev/docs/sitl-with-airsim.html)

## Contributing

Got it working on a setup we haven't covered, or found a fix for one of the errors above? Open an issue or a pull request. Mention your Mac model, macOS version and Python version so others can tell if it applies to them.

## License

MIT, see [LICENSE](LICENSE).

Happy flying,
The Drone Community
