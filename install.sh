#!/usr/bin/env bash
set -e

echo "Installing Holy Monitor"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f "holymon.hc" ]; then
    echo "[-] Error: holymon.hc was not found."
    echo "    Make sure you are running the installer from the Holy Monitor repository."
    exit 1
fi

echo "[+] Found holymon.hc"

COMPILER=""

if command -v holyc >/dev/null 2>&1; then
    COMPILER="holyc"
    echo "[+] HolyC compiler detected: holyc"
elif command -v 3360-holyc >/dev/null 2>&1; then
    COMPILER="3360-holyc"
    echo "[+] HolyC compiler detected: 3360-holyc"
elif command -v gcc >/dev/null 2>&1; then
    COMPILER="gcc"
    echo "[!] HolyC compiler not detected."
    echo "[+] GCC detected. Using GCC compatibility compilation."
else
    echo "[-] Error: No supported compiler was found."
    echo
    echo "    Install a HolyC compiler or GCC and run this installer again."
    exit 1
fi

echo
echo "[+] Compiling holymon.hc..."

case "$COMPILER" in
    holyc)
        holyc holymon.hc -o holy-monitor
        ;;
    3360-holyc)
        3360-holyc holymon.hc -o holy-monitor
        ;;
    gcc)
        gcc -O2 -x c -D_GNU_SOURCE holymon.hc -o holy-monitor
        ;;
esac

if [ ! -f "holy-monitor" ]; then
    echo "[-] Error: Compilation failed. No executable was produced."
    exit 1
fi

if [ ! -x "holy-monitor" ]; then
    echo "[-] Error: Compiler produced a file, but it is not executable."
    exit 1
fi

echo "[+] Compilation successful."

INSTALL_DIR="$HOME/.local/bin"

echo
echo "[+] Checking installation directory..."

if [ ! -d "$INSTALL_DIR" ]; then
    echo "[+] Creating $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

if [ ! -w "$INSTALL_DIR" ]; then
    echo "[-] Error: $INSTALL_DIR is not writable."
    exit 1
fi

echo "[+] Installation directory is ready."

echo
echo "[+] Installing Holy Monitor..."

cp holy-monitor "$INSTALL_DIR/holy-monitor"
chmod +x "$INSTALL_DIR/holy-monitor"

if [ ! -x "$INSTALL_DIR/holy-monitor" ]; then
    echo "[-] Error: Installation failed."
    exit 1
fi

echo "[+] Holy Monitor installed successfully."

echo
echo "[+] Checking PATH..."

case ":$PATH:" in
    *":$INSTALL_DIR:"*)
        echo "[+] $INSTALL_DIR is already in PATH."
        ;;
    *)
        echo "[!] $INSTALL_DIR is not currently in PATH."
        echo
        echo "    Add this line to your shell configuration:"
        echo
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo
        echo "    Then restart your shell."
        ;;
esac

echo
echo "[+] Installation complete!"
echo
echo "    Run:"
echo
echo "    holy-monitor"
echo
echo "May your system remain holy."
