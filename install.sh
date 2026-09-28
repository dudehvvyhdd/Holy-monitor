#!/bin/sh

# Compile holymon.hc (detects HolyC compiler, falls back to GCC)
if command -v holyc >/dev/null 2>&1; then
    holyc holymon.hc -o holy-monitor
elif command -v 3360-holyc >/dev/null 2>&1; then
    3360-holyc holymon.hc -o holy-monitor
elif command -v gcc >/dev/null 2>&1; then
    gcc -O2 -x c -D_GNU_SOURCE holymon.hc -o holy-monitor
else
    echo "[-] Error: No supported compiler found."
    exit 1
fi

chmod +x holy-monitor

# Install directly into PATH
if [ -w /usr/local/bin ]; then
    mv holy-monitor /usr/local/bin/holy-monitor
elif command -v sudo >/dev/null 2>&1; then
    sudo mv holy-monitor /usr/local/bin/holy-monitor
else
    mkdir -p "$HOME/.local/bin"
    mv holy-monitor "$HOME/.local/bin/holy-monitor"
fi

echo "[+] Holy Monitor installed successfully."
echo "[+] Run 'holy-monitor' to begin monitoring."
echo
echo "May your system remain holy."
