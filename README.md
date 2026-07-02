# This project has been replaced by DiagBridge

## → [github.com/citi94/diagbridge](https://github.com/citi94/diagbridge) ←

Everything this guide did, and much more, is now a single signed Mac app:
download a DMG, drag it to Applications, point it at your VCDS installer,
done. No Terminal, no Homebrew, no patching.

**DiagBridge is better in every way:**

| | This guide (old) | DiagBridge |
|---|---|---|
| Install | 10–15 min of Terminal commands | Drag and drop |
| How VCDS runs | Intel Wine translated by Rosetta 2 | **Native ARM64** — genuinely fast |
| Signed & notarized | No | Yes |
| USB + WiFi interfaces | Yes (after manual patching) | Yes, out of the box |
| Survives Wine updates | No — patches need re-applying | Self-contained |
| Scan logs | Buried in a hidden Wine prefix | `~/Documents/VCDS Logs` |
| VCDS updates | Manual | Hold Option at launch |

The old approach also stops working when Apple removes Rosetta 2 —
DiagBridge runs VCDS's own ARM64 binaries natively, so it doesn't care.

As before: you need your own licensed copy of VCDS (25.x or later) and a
Ross-Tech interface. DiagBridge ships no Ross-Tech software and is not
affiliated with Ross-Tech LLC.

The Wine port that makes this possible is open source:
[citi94/wine-macos-arm64](https://github.com/citi94/wine-macos-arm64).

---

*The old manual instructions remain in this repository's
[git history](../../commits/main) for anyone who needs them.*
