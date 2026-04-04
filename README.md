# VCDS on Mac (Apple Silicon)

Run Ross-Tech VCDS on your Mac. No Windows, no VM — just download and go.

**USB and WiFi** connections to HEX-NET and HEX-V2 both work. It runs fast.

## What You Need

- A Mac with an Apple Silicon chip (M1, M2, M3, M4, etc.)
- A licensed copy of [VCDS](https://www.ross-tech.com/vcds/download/) from Ross-Tech
- A Ross-Tech HEX-NET or HEX-V2 diagnostic interface

## Setup (10–15 minutes)

### Step 1 — Install Homebrew

Homebrew is a free tool that installs software on your Mac. If you already
have it, skip to Step 2.

Open **Terminal** (press Cmd+Space, type "Terminal", press Enter) and paste
this command (Cmd+V), then press Enter:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

This is safe — Homebrew is used by millions of people. It may ask for your
Mac password. **When you type your password, nothing will appear on screen —
that's normal.** Just type it and press Enter.

When it finishes, it will print something like this:

```
==> Next steps:
  eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Copy and paste those lines into Terminal and press Enter.** This only needs
to be done once.

### Step 2 — Download This Project

Click the green **Code** button at the top of this page, then **Download ZIP**.

Unzip the file (double-click it), then open Terminal and type:

```
cd ~/Downloads/vcds-on-mac-main
chmod +x setup.sh
./setup.sh
```

The setup script will:
1. Install Rosetta 2 (lets your Mac run Intel/Windows software)
2. Install Wine (free software that runs Windows programs on Mac)
3. Ask you for the VCDS installer (download it from ross-tech.com first)
4. Set up USB support for HEX-NET / HEX-V2
5. Set up WiFi auto-discovery for HEX-NET
6. Create a VCDS icon in your Applications folder

### Step 3 — Launch VCDS

Double-click **VCDS** in your Applications folder.

If macOS says it can't open the app, go to **System Settings** >
**Privacy & Security** and click **Open Anyway**.

## Connecting to Your Interface

### WiFi (HEX-NET only)

After setup, WiFi auto-discovery works automatically. VCDS will find your
HEX-NET on the network. Make sure the HEX-NET is connected to the same WiFi
network as your Mac.

If auto-discovery doesn't find it, you can enter the IP manually:
**Options** > **IP Parameters** > **Fixed** > enter your HEX-NET's IP address.

The HEX-V2 does not have WiFi — use USB instead.

### USB (HEX-NET and HEX-V2)

Plug in your interface via USB. VCDS should detect it automatically.

If it doesn't, the USB patch may need re-applying (see Troubleshooting below).

## Troubleshooting

**macOS says the app "is damaged" or "can't be opened"**
Go to **System Settings** > **Privacy & Security**, scroll down, and click
**Open Anyway**. This only needs to be done once.

**"Can't Open Codes File: CODES.DAT"**
Use the VCDS app in Applications or the `launch-vcds.sh` script. Don't try
to run VCDS.exe directly.

**USB interface not found**
The USB patch needs re-applying after Wine updates. Run:
```
cd vcds-on-mac
./scripts/patch-winebus.sh
```

**WiFi shows "Broadcast(s) used: NONE"**
The WiFi fix may need reinstalling. Run `./setup.sh` again — it won't
reinstall everything, just fix what's needed.

**Wine won't start at all**
Try: `codesign --force --deep --sign - "/Applications/Wine Stable.app"`
Then go to **System Settings** > **Privacy & Security** > **Open Anyway**.

**After a Wine update, USB stopped working**
Wine updates overwrite the USB patch. Re-apply it:
```
./scripts/patch-winebus.sh
```
WiFi is not affected by Wine updates.

## How It Works

<details>
<summary>Technical details (click to expand)</summary>

VCDS is a Windows program. On Apple Silicon Macs, it runs through two
translation layers:

```
VCDS.EXE (Windows program)
    |
Wine (translates Windows calls to macOS)
    |
Rosetta 2 (translates Intel code to Apple Silicon)
    |
macOS
```

### USB Fix

Wine's USB HID driver only exposes gamepad-type devices by default. The
HEX-NET/HEX-V2 is a USB HID device but not a gamepad, so Wine ignores it.

The fix (`scripts/patch-winebus.sh`) changes a single conditional jump in
Wine's `winebus.so` to unconditional, making it expose all HID devices.
This is a 1-byte change at offset 0xe07 in Wine 11.0.

### WiFi Fix

macOS has 30+ network interfaces (Thunderbolt bridges, VPN tunnels, etc.).
VCDS calls Windows' `GetAdaptersInfo` with a fixed-size buffer that overflows
with this many interfaces and gives up.

The fix (`iphlpapi-wrapper/`) is a wrapper DLL that properly allocates the
buffer and filters to only real network adapters, excluding loopback,
Tailscale/CGNAT, and link-local addresses.

Source: `iphlpapi-wrapper/iphlpapi.c`

</details>

## Disclaimer

VCDS, VAG-COM, HEX-NET, and HEX-V2 are registered trademarks of Ross-Tech, LLC.
This project is **not affiliated with, endorsed by, or associated with Ross-Tech**.
All trademarks are the property of their respective owners.

This project does not include or modify VCDS software. You must purchase a valid
VCDS license and interface directly from [Ross-Tech](https://www.ross-tech.com).

This software is provided "as is" without warranty of any kind. Use at your own
risk. The authors are not responsible for any damage to your vehicle, diagnostic
equipment, or computer.

This project uses [Wine](https://www.winehq.org/) (LGPL 2.1+). Wine binaries are
not redistributed — only a patching script is provided.

## License

The scripts and wrapper DLL in this repository are released under the
[MIT License](LICENSE).
