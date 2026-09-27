#!/usr/bin/env bash
set -e

echo "================================="
echo "    Installing Holy Monitor      "
echo "================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[+] Compiling holymon.HC..."

if command -v holyc &> /dev/null; then
    holyc holymon.HC -o holy-monitor
elif command -v 3360-holyc &> /dev/null; then
    3360-holyc holymon.HC -o holy-monitor
elif command -v gcc &> /dev/null; then
    echo "[!] Notice: HolyC compiler not detected in PATH. Attempting GCC wrapper compilation..."
    gcc -O2 -x c -D_GNU_SOURCE holymon.HC -o holy-monitor
else
    echo "[-] Error: Neither HolyC nor GCC were found on your system."
    exit 1
fi

echo "[+] Installing binary to ~/.local/bin/..."
mkdir -p "$HOME/.local/bin"
cp holy-monitor "$HOME/.local/bin/holy-monitor"
chmod +x "$HOME/.local/bin/holy-monitor"

echo ""
echo "[+] Installation complete!"
echo "[+] Execute 'holy-monitor' from any terminal window."
