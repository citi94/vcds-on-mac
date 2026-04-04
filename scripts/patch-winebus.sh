#!/bin/bash
#
# Patch Wine's winebus.so to expose all USB HID devices
#
# Wine's IOHID driver only exposes gamepad-type HID devices by default.
# This patch changes a conditional jump to unconditional, making Wine
# expose ALL HID devices to Windows applications (including the HEX-NET
# and HEX-V2 diagnostic interfaces).
#
# This patch is for Wine 11.0 (wine-stable from Homebrew).
# The offset may change in future Wine versions.
#
set -e

WINEBUS="/Applications/Wine Stable.app/Contents/Resources/wine/lib/wine/x86_64-unix/winebus.so"
BACKUP_DIR="$HOME/.vcds-wine/backups"

if [ ! -f "$WINEBUS" ]; then
    echo "Error: winebus.so not found."
    echo "Is Wine installed? Run: brew install --cask wine-stable"
    exit 1
fi

# Check if python3 is available
if ! command -v python3 &>/dev/null; then
    echo "Error: python3 is required but not found."
    echo "Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

# Check if already patched
CURRENT=$(xxd -p -l 6 -s 0xe07 "$WINEBUS")
ORIGINAL="0f85f9fdffff"
PATCHED="e9fafdffff90"

if [ "$CURRENT" = "$PATCHED" ]; then
    echo "USB HID patch is already applied."
    exit 0
fi

if [ "$CURRENT" != "$ORIGINAL" ]; then
    echo ""
    echo "Warning: This USB patch was made for Wine 11.0."
    echo "You have a different version: $(wine --version 2>/dev/null || echo 'unknown')"
    echo ""
    echo "The patch might not work with your version."
    echo "USB may not work, but WiFi will still work fine."
    echo ""
    echo "Try anyway? (y/N)"
    read -r answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        echo "Skipped USB patch. USB will not work, but WiFi still will."
        exit 0
    fi
fi

# Check write permissions
if [ ! -w "$WINEBUS" ]; then
    echo "Need permission to modify Wine. You may be asked for your Mac password."
    echo "(When you type it, nothing appears on screen — that's normal.)"
    sudo chmod u+w "$WINEBUS"
fi

# Backup
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/winebus.so.$(date +%Y%m%d-%H%M%S)"
cp "$WINEBUS" "$BACKUP_FILE"

# Apply patch: change jne (0f 85) to jmp (e9) + nop (90)
# Write to temp file first, then move (atomic)
TMPFILE="$(mktemp)"
python3 - "$WINEBUS" "$TMPFILE" << 'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
data = bytearray(open(src, 'rb').read())
data[0xe07] = 0xe9
data[0xe08] = 0xfa
data[0xe09] = 0xfd
data[0xe0a] = 0xff
data[0xe0b] = 0xff
data[0xe0c] = 0x90
open(dst, 'wb').write(data)
PYEOF
cp "$TMPFILE" "$WINEBUS"
rm -f "$TMPFILE"

echo "USB HID patch applied."

# Re-sign the Wine app bundle (required after modifying binaries)
echo "Re-signing Wine (this takes a moment)..."
codesign --force --deep --sign - "/Applications/Wine Stable.app" 2>/dev/null || {
    echo ""
    echo "Note: Could not re-sign Wine automatically."
    echo "If macOS blocks Wine from opening, go to:"
    echo "  System Settings > Privacy & Security > Open Anyway"
}

echo "Done. USB diagnostic interfaces will now work with VCDS."
