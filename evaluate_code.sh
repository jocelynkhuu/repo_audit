#!/bin/bash
CONTAINER_NAME="repo-auditor"
MODEL="deepseek-coder:1.3b"  # Explicit tag to prevent auto-manifest checks
TARGET_DIR="/home/auditoruser/analysis/bash"

echo "=================================================="
echo "    🔍 STARTING AI SOURCE CODE ANALYSIS          "
echo "=================================================="

# 1. Grab all relevant code files
ALL_FILES=$(podman exec $CONTAINER_NAME find "$TARGET_DIR" -type f -not -path '*/.*' -not -name '*.md')

if [ -z "$ALL_FILES" ]; then
    echo "[-] Error: No source files found in $TARGET_DIR"
    exit 1
fi

# 2. Extract and display the first 5 files for verification
echo "[*] Verifying target directory contents (First 5 files):"
echo "$ALL_FILES" | head -n 5 | sed 's|^|- |'
echo "--------------------------------------------------"

# 3. Compile all file names and contents into a text payload
REPO_CONTEXT=""
while read -r filepath; do
    REPO_CONTEXT+=$'\n'"=== FILE: ${filepath##$TARGET_DIR/} ==="$'\n'
    REPO_CONTEXT+=$(podman exec $CONTAINER_NAME cat "$filepath")
    REPO_CONTEXT+=$'\n'
done <<< "$ALL_FILES"

echo "[*] Transmitting codebase to $MODEL..."
echo -e "[*] Generating concise audit summary...\n"

# 4. Execute with strict output parameters forced on the LLM
ollama run $MODEL <<-EOF
You are an expert AppSec and Malware Reverse Engineer. Analyze the provided codebase.

CRITICAL INSTRUCTIONS:
- Your response must be strictly LESS THAN 10 SENTENCES total.
- Do not list or summarize the filenames in your answer (the user can already see them).
- If the repository contains no malicious patterns, your response must start with the exact phrase: "VERDICT: NO MALICIOUS CODE DETECTED." followed by a brief summary of what the code normally does.
- If it is dangerous, start with "VERDICT: MALICIOUS PAYLOAD DETECTED" and explicitly name the high-risk lines.

---
REPOSITORY CODE EXTRANEOUS CONTEXT:
$REPO_CONTEXT
EOF
echo -e "\n=================================================="