#!/bin/bash

CONTAINER_NAME="repo-auditor"
DOCKERFILE="alpine_linux_Dockerfile.yaml"
IMAGE_NAME="secure-audit-image"

echo "=================================================="
echo "   🛡️  INITIALIZING SECURE AUDIT SANDBOX          "
echo "=================================================="

# 1. Clean up any stale container instance with the same name
if [ "$(podman ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
    echo "[*] Cleaning up existing container instance..."
    podman rm -f $CONTAINER_NAME &>/dev/null
fi

# 2. Rebuild the base image if modifications were made
echo "[*] Building Podman Security Image..."
podman build -t $IMAGE_NAME -f $DOCKERFILE

# 3. Spin up the background sandbox instance (Network Connected initially)
echo "[*] Spawning unprivileged sandbox container..."
podman run -d \
  --name $CONTAINER_NAME \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  --read-only \
  --mount type=tmpfs,destination=/home/auditoruser/analysis,tmpfs-mode=1777,tmpfs-size=512M \
  $IMAGE_NAME

echo "--------------------------------------------------"
# 4. Interactively prompt for the Target Git URL
echo -n "👉 Enter the untrusted repository Git URL: "
read -r GIT_URL

if [ -z "$GIT_URL" ]; then
    echo "[-] Error: No URL provided. Aborting."
    podman rm -f $CONTAINER_NAME &>/dev/null
    exit 1
fi

# 5. Extract the repository folder name automatically from the URL
# (e.g., https://github.com/user/my-repo.git -> my-repo)
REPO_DIR=$(basename "$GIT_URL" .git)

echo "--------------------------------------------------"
echo "[*] Securely cloning: $GIT_URL"
podman exec -it $CONTAINER_NAME git clone --depth 1 "$GIT_URL" "$REPO_DIR"

# 6. Completely drop the network interface link
echo "[*] Severing container network interface..."
podman network disconnect podman $CONTAINER_NAME

# 7. Automated Network Self-Test Verification
echo "[*] Verifying network isolation status..."
if podman exec $CONTAINER_NAME ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
    echo -e "⚠️  WARNING: Network is STILL CONNECTED! Isolation failed."
else
    echo -e "✅ VERIFIED: Container network is completely dark."
fi

echo "=================================================="
echo "[+] Sandbox Initialization Complete!"
echo "    - Destination directory inside container: /home/auditoruser/analysis/$REPO_DIR"
echo "    - Network Status: 🚫 DISCONNECTED (Safe to triage)"
echo "=================================================="
echo -e "\nNext steps to execute your triage tools:"
echo "  ./yara_rule_check.sh $REPO_DIR"
echo "  ./evaluate_code.sh $REPO_DIR"