#!/bin/bash
CONTAINER_NAME="repo-auditor"

# Set default folder name if argument is missing
DIR_NAME="${1:-python}"
TARGET_DIR="/home/auditoruser/analysis/$DIR_NAME"

echo "=================================================="
echo "   ⚡ RUNNING LIGHTWEIGHT MALWARE TRIAGE ⚡       "
echo "=================================================="
echo "[*] Target Directory: $TARGET_DIR"
echo "--------------------------------------------------"

# Grab all relevant files inside the target directory
ALL_FILES=$(podman exec $CONTAINER_NAME find "$TARGET_DIR" -type f -not -path '*/.*' 2>/dev/null)

if [ -z "$ALL_FILES" ]; then
    echo "[-] Error: No source files found in $TARGET_DIR. Check your folder name."
    exit 1
fi

# Display the first 5 files for human verification
echo "[*] Verifying target directory contents (First 5 files):"
echo "$ALL_FILES" | head -n 5 | sed 's|^|- |'
echo "--------------------------------------------------"

# 1. Run YARA signature match
echo -e "\n[*] Running YARA Backdoor & Webshell Scanner..."
podman exec $CONTAINER_NAME yara /home/auditoruser/rules/webshells.yar "$TARGET_DIR"

# 2. BusyBox-safe recursive regex checks
echo -e "\n[*] Checking for Suspicious Execution Hooks & Exfiltration..."

# Check for automatic code execution tricks (pre/post install hooks)
echo "$ALL_FILES" | xargs -I {} podman exec $CONTAINER_NAME grep -nHnE '(preinstall|postinstall|pre-install|post-install)' "{}" 2>/dev/null

# Check for reverse shell strings or raw TCP pipes
echo "$ALL_FILES" | xargs -I {} podman exec $CONTAINER_NAME grep -nHnE '(/dev/tcp/|nc -e |ws://|wss://)' "{}" 2>/dev/null

# Check for environmental variable or key scraping
echo "$ALL_FILES" | xargs -I {} podman exec $CONTAINER_NAME grep -nHnE '(\.aws/credentials|\.ssh/id_|\.env|process\.env)' "{}" 2>/dev/null

# 3. Deep Credential & Entropy Scan (Added --no-update)
echo -e "\n[*] Running Deep Credential & Secret Verification Scan..."
podman exec $CONTAINER_NAME trufflehog filesystem "$TARGET_DIR" --no-update --only-verified

echo -e "\n=================================================="
echo "[+] Scan Complete. If no output appeared above, the repo is clean."
echo "=================================================="