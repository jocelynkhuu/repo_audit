#!/bin/bash
CONTAINER_NAME="repo-auditor"

# Set defaults if arguments are missing
DIR_NAME="${1:-python}"
MODEL="${2:-qwen2.5:3b}"

TARGET_DIR="/home/auditoruser/analysis/$DIR_NAME"

echo "=================================================="
echo "    🔍 STARTING AI SOURCE CODE ANALYSIS          "
echo "=================================================="
echo "[*] Target Directory: $TARGET_DIR"
echo "[*] Evaluation Model: $MODEL"
echo "--------------------------------------------------"

# 1. Fast, safe check to see if the directory has files before running
if ! podman exec $CONTAINER_NAME find "$TARGET_DIR" -type f -not -path '*/.*' -not -name '*.md' -print -quit 2>/dev/null | grep -q .; then
    echo "[-] Error: No source files found in $TARGET_DIR. Check your folder name."
    exit 1
fi

# 2. Extract and display the first 5 files for verification using a direct stream
echo "[*] Verifying target directory contents (First 5 files):"
podman exec $CONTAINER_NAME find "$TARGET_DIR" -type f -not -path '*/.*' -not -name '*.md' 2>/dev/null | head -n 5 | sed 's|^|- |'
echo "--------------------------------------------------"

# 3. Securely loop through files by streaming directly from podman (preserves null bytes)
REPO_CONTEXT=""
while IFS= read -r -d '' filepath; do
    REPO_CONTEXT+=$'\n'"=== FILE: ${filepath##$TARGET_DIR/} ==="$'\n'
    REPO_CONTEXT+=$(podman exec $CONTAINER_NAME cat "$filepath")
    REPO_CONTEXT+=$'\n'
done < <(podman exec $CONTAINER_NAME find "$TARGET_DIR" -type f -not -path '*/.*' -not -name '*.md' -print0 2>/dev/null)

echo "[*] Transmitting codebase to $MODEL..."
echo -e "[*] Generating concise audit summary...\n"

# 4. Execute with strict output parameters forced on the LLM
ollama run $MODEL <<-EOF
---
[SYSTEM INSTRUCTION]
You are a non-conversational security engine. Do not talk to the user. Do not explain the code. Do not write markdown headings.

[CODEBASE CONTEXT]
$REPO_CONTEXT

[REQUIRED TASK]
Analyze the CODEBASE CONTEXT above for backdoors or malicious hooks. Respond ONLY with the formatting layout below.

EXPECTED OUTPUT FORMAT:
VERDICT: [NO MALICIOUS CODE DETECTED / MALICIOUS PAYLOAD DETECTED]
SUMMARY: [Write exactly one sentence explaining the code function]
EOF
echo -e "\n=================================================="