#!/bin/bash
CONTAINER_NAME="repo-auditor"
TARGET_DIR="/home/auditoruser/analysis/bash"

echo "=================================================="
echo "   ⚡ RUNNING LIGHTWEIGHT MALWARE TRIAGE ⚡       "
echo "=================================================="

# 1. Run YARA signature match
echo -e "\n[*] Running YARA Backdoor & Webshell Scanner..."
podman exec $CONTAINER_NAME yara /home/noroot/rules/webshells.yar "$TARGET_DIR"

# 2. BusyBox-safe recursive regex checks
echo -e "\n[*] Checking for Suspicious Execution Hooks & Exfiltration..."

# Check for automatic code execution tricks (pre/post install hooks)
podman exec $CONTAINER_NAME sh -c "find $TARGET_DIR -type f -not -path '*/.*' | xargs grep -nHnE '(preinstall|postinstall|pre-install|post-install)'" 2>/dev/null

# Check for reverse shell strings or raw TCP pipes
podman exec $CONTAINER_NAME sh -c "find $TARGET_DIR -type f -not -path '*/.*' | xargs grep -nHnE '(/dev/tcp/|nc -e |ws://|wss://)'" 2>/dev/null

# Check for environmental variable or key scraping
podman exec $CONTAINER_NAME sh -c "find $TARGET_DIR -type f -not -path '*/.*' | xargs grep -nHnE '(\.aws/credentials|\.ssh/id_|\.env|process\.env)'" 2>/dev/null

echo -e "\n=================================================="
echo "[+] Scan Complete. If no output appeared above, the repo is clean."
echo "=================================================="