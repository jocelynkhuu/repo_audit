#!/bin/bash
CONTAINER_NAME="repo-auditor"

# Set default folder name if argument is missing
DIR_NAME="${1:-python}"
TARGET_DIR="/home/auditoruser/analysis/$DIR_NAME"

echo "=================================================="
echo "    ⚡ RUNNING LIGHTWEIGHT MALWARE TRIAGE ⚡       "
echo "=================================================="
echo "[*] Target Directory: $TARGET_DIR"
echo "--------------------------------------------------"

# 1. Fast, safe check to see if the directory has files before running
if ! podman exec $CONTAINER_NAME find "$TARGET_DIR" -type f -not -path '*/.*' -print -quit 2>/dev/null | grep -q .; then
    echo "[-] Error: No source files found in $TARGET_DIR. Check your folder name."
    exit 1
fi

# 2. Display the first 5 files for human verification using a direct stream
echo "[*] Verifying target directory contents (First 5 files):"
podman exec $CONTAINER_NAME find "$TARGET_DIR" -type f -not -path '*/.*' 2>/dev/null | head -n 5 | sed 's|^|- |'
echo "--------------------------------------------------"

# 3. Run YARA signature match
echo -e "\n[*] Running YARA Backdoor & Webshell Scanner..."
podman exec $CONTAINER_NAME yara /home/auditoruser/rules/webshells.yar "$TARGET_DIR"

# 4. BusyBox-safe recursive regex checks via direct stream piping
echo -e "\n[*] Checking for Suspicious Execution Hooks & Exfiltration..."

# Check for automatic code execution tricks (pre/post install hooks)
podman exec $CONTAINER_NAME find "$TARGET_DIR" -type f -not -path '*/.*' -print0 2>/dev/null | xargs -0 -I {} podman exec $CONTAINER_NAME grep -nHnE '(preinstall|postinstall|pre-install|post-install)' "{}" 2>/dev/null

# Check for reverse shell strings or raw TCP pipes
podman exec $CONTAINER_NAME find "$TARGET_DIR" -type f -not -path '*/.*' -print0 2>/dev/null | xargs -0 -I {} podman exec $CONTAINER_NAME grep -nHnE '(/dev/tcp/|nc -e |ws://|wss://)' "{}" 2>/dev/null

# Check for environmental variable or key scraping
podman exec $CONTAINER_NAME find "$TARGET_DIR" -type f -not -path '*/.*' -print0 2>/dev/null | xargs -0 -I {} podman exec $CONTAINER_NAME grep -nHnE '(\.aws/credentials|\.ssh/id_|\.env|process\.env)' "{}" 2>/dev/null

# 5. Deep Credential & Entropy Scan
echo -e "\n[*] Running Deep Credential & Secret Verification Scan..."
podman exec $CONTAINER_NAME trufflehog filesystem "$TARGET_DIR" --no-update --only-verified

echo -e "\n=================================================="
echo "[+] Scan Complete. If no output appeared above, the repo is clean."
echo "=================================================="