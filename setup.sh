#!/bin/bash
#
# VCDS on Mac - Setup Script
# Installs Wine, creates a prefix, and configures everything for VCDS.
#
set -e
trap 'echo ""; echo "Something went wrong (line $LINENO). Please report this issue."; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WINEPREFIX="$HOME/.vcds-wine"
VCDS_DIR="$WINEPREFIX/drive_c/Ross-Tech/VCDS"

# Ensure Wine and Homebrew are on PATH even if shell profile hasn't been sourced
export PATH="/opt/homebrew/bin:/Applications/Wine Stable.app/Contents/Resources/wine/bin:$PATH"

echo "========================================="
echo "  VCDS on Mac - Setup"
echo "========================================="
echo ""

# --- Step 1: Rosetta 2 ---
if ! /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
    echo "[1/7] Installing Rosetta 2 (needed to run Windows software)..."
    softwareupdate --install-rosetta --agree-to-license
else
    echo "[1/7] Rosetta 2 is installed."
fi

# --- Step 2: Homebrew ---
if ! command -v brew &>/dev/null; then
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo ""
        echo "[2/7] Homebrew is not installed."
        echo ""
        echo "Paste this into Terminal to install it:"
        echo ""
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo ""
        echo "When it finishes, it will show two commands starting with 'eval'."
        echo "Copy and paste those into Terminal too, then run this script again."
        exit 1
    fi
else
    echo "[2/7] Homebrew found."
fi

# --- Step 3: Wine ---
if ! command -v wine &>/dev/null; then
    echo "[3/7] Installing Wine (this may take a few minutes)..."
    brew install --cask wine-stable
    export PATH="/Applications/Wine Stable.app/Contents/Resources/wine/bin:$PATH"
else
    echo "[3/7] Wine already installed."
fi

# --- Step 4: Wine prefix ---
if [ ! -d "$WINEPREFIX" ]; then
    echo "[4/7] Setting up Wine (first time — may take a moment)..."
    WINEPREFIX="$WINEPREFIX" wineboot --init 2>/dev/null || {
        echo "Error: Wine failed to start. Try opening Wine Stable from"
        echo "Applications first, then run this script again."
        exit 1
    }
    WINEPREFIX="$WINEPREFIX" wineserver -w 2>/dev/null || true
else
    echo "[4/7] Wine is set up."
fi

# --- Step 5: Install VCDS ---
if [ ! -f "$VCDS_DIR/VCDS.exe" ]; then
    echo "[5/7] VCDS not found."
    echo ""
    echo "Download the VCDS installer from:"
    echo "  https://www.ross-tech.com/vcds/download/"
    echo ""
    echo "Then drag the downloaded file into this Terminal window"
    echo "and press Enter."
    echo ""
    read -p "Installer path: " INSTALLER

    # Clean up the path (handle drag-and-drop escaping, quotes, tilde)
    INSTALLER="$(echo "$INSTALLER" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    INSTALLER="${INSTALLER/#\~/$HOME}"
    INSTALLER="${INSTALLER//\\/}"
    INSTALLER="${INSTALLER#[\"\']}"
    INSTALLER="${INSTALLER%[\"\']}"

    if [ ! -f "$INSTALLER" ]; then
        echo "File not found: $INSTALLER"
        echo "Make sure you downloaded the VCDS installer and try again."
        exit 1
    fi
    echo "Running VCDS installer..."
    echo "(Follow the installer — click Next, accept defaults, then Finish)"
    echo ""
    WINEPREFIX="$WINEPREFIX" wine "$INSTALLER" 2>/dev/null
    WINEPREFIX="$WINEPREFIX" wineserver -w 2>/dev/null || true
    if [ ! -f "$VCDS_DIR/VCDS.exe" ]; then
        echo ""
        echo "VCDS was not found after installation."
        echo ""
        echo "If you cancelled the installer, run this script again."
        echo "If it installed to a different folder, copy the VCDS folder to:"
        echo "  $VCDS_DIR/"
        exit 1
    fi
    echo "VCDS installed."
else
    echo "[5/7] VCDS already installed."
fi

# --- Step 6: Patch winebus.so for USB HID ---
echo "[6/7] Setting up USB support..."
bash "$SCRIPT_DIR/scripts/patch-winebus.sh"

# --- Step 7: Install WiFi auto-discovery fix ---
echo "[7/7] Setting up WiFi support..."
WINE_IPHLPAPI="/Applications/Wine Stable.app/Contents/Resources/wine/lib/wine/x86_64-windows/iphlpapi.dll"

if [ ! -f "$VCDS_DIR/iphlpapi_wine.dll" ]; then
    if [ -f "$WINE_IPHLPAPI" ]; then
        cp "$WINE_IPHLPAPI" "$VCDS_DIR/iphlpapi_wine.dll"
    else
        echo "Note: Could not find Wine's network library."
        echo "WiFi auto-discovery may not work, but you can still enter"
        echo "your HEX-NET's IP address manually in VCDS Options."
    fi
fi

if [ -f "$SCRIPT_DIR/iphlpapi-wrapper/iphlpapi.dll" ]; then
    cp "$SCRIPT_DIR/iphlpapi-wrapper/iphlpapi.dll" "$VCDS_DIR/iphlpapi.dll"
else
    echo "Note: WiFi fix DLL not found in the download."
    echo "WiFi auto-discovery may not work, but manual IP will."
fi

# --- Create launcher script ---
cat > "$SCRIPT_DIR/launch-vcds.sh" << 'LAUNCHER'
#!/bin/bash
export PATH="/opt/homebrew/bin:/Applications/Wine Stable.app/Contents/Resources/wine/bin:$PATH"
WINEPREFIX="$HOME/.vcds-wine"
cd "$WINEPREFIX/drive_c/Ross-Tech/VCDS" || { echo "VCDS not found. Run setup.sh first."; exit 1; }
WINEDLLOVERRIDES="iphlpapi=n,b" WINEPREFIX="$WINEPREFIX" wine "C:\\Ross-Tech\\VCDS\\VCDS.exe" 2>/dev/null &
LAUNCHER
chmod +x "$SCRIPT_DIR/launch-vcds.sh"

# --- Create app bundle ---
APP_DIR="/Applications/VCDS.app"
mkdir -p "$APP_DIR/Contents/MacOS" 2>/dev/null || {
    echo ""
    echo "Could not create VCDS.app in /Applications."
    echo "You may be asked for your Mac password."
    echo "(Nothing appears when you type it — that's normal.)"
    sudo mkdir -p "$APP_DIR/Contents/MacOS"
    sudo mkdir -p "$APP_DIR/Contents/Resources"
}
mkdir -p "$APP_DIR/Contents/Resources" 2>/dev/null || true

cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>vcds-launcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.vcds-on-mac.launcher</string>
    <key>CFBundleName</key>
    <string>VCDS</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>VCDS</string>
</dict>
</plist>
PLIST

cat > "$APP_DIR/Contents/MacOS/vcds-launcher" << 'LAUNCHER'
#!/bin/bash
export PATH="/opt/homebrew/bin:/Applications/Wine Stable.app/Contents/Resources/wine/bin:$PATH"
WINEPREFIX="$HOME/.vcds-wine"
cd "$WINEPREFIX/drive_c/Ross-Tech/VCDS" || {
    osascript -e 'display dialog "VCDS is not installed. Please run setup.sh first." buttons {"OK"} with icon stop' 2>/dev/null
    exit 1
}
export WINEDLLOVERRIDES="iphlpapi=n,b"
export WINEPREFIX
exec wine "C:\\Ross-Tech\\VCDS\\VCDS.exe" 2>"$HOME/.vcds-wine/wine.log"
LAUNCHER
chmod +x "$APP_DIR/Contents/MacOS/vcds-launcher"

# Copy icon if available
if [ -f "$SCRIPT_DIR/VCDS.icns" ]; then
    cp "$SCRIPT_DIR/VCDS.icns" "$APP_DIR/Contents/Resources/VCDS.icns"
fi

# Remove quarantine so macOS doesn't block it
xattr -r -d com.apple.quarantine "$APP_DIR" 2>/dev/null || true

echo ""
echo "========================================="
echo "  Setup complete!"
echo "========================================="
echo ""
echo "Launch VCDS by double-clicking it in /Applications,"
echo "or run:  ./launch-vcds.sh"
echo ""
echo "If macOS blocks Wine from opening, go to:"
echo "  System Settings > Privacy & Security > Open Anyway"
echo ""
