# 🛡️ Basic Repo Auditor

> NOTE: Created with the help of ✨ _**AI**_ 🤖 This was created for my own personal use for fun and learning purposes. Please use at your own risk and with caution. Always double-check what you are executing or running on your computer, and never run untrusted scripts/software.

This project provides an isolated, and resource-efficient environment for analyzing code. It leverages containerization to ensure that analysis performed remains sandboxed from the host system.

The project has scripts for different phases:
1. **Initialization:** A clean, minimal container image is built using `alpine:latest`.
2. **Ingestion:** The target code is copied into the container's ephemeral filesystem.
3. **Analysis:** Static analysis tools (e.g., regex, pattern matching) are run against the code.
4. **Reporting:** Results are aggregated and presented to the user.

### Pre-requisites
Setup for Ollama and Podman are omitted and should be done in advance.
1. Podman (https://podman.io/)
2. Ollama (https://ollama.com/) 
    - By default uses the model `qwen2.5:3b`

> NOTE: The AI analysis of the code is only as good as the model that is evaluating it. AI is not always accurate. Please always verify before running/executing anything on your computer.

## Scripts Included
### 1. `init_sandbox.sh`

This script helps to build the isolated container first deleting an existing running container with the `repo-auditor` name, building a new image named `secure-audit-image` from the `alpine_linux_Dockerfile.yaml` file and running the newly built image as a detached container called `repo-auditor`. It also applies hardening techniques during the build by dropping all Linux capabilities, making the filesystem read-only by default, mounting a temporary filesystem (tmpfs) so that it is wiped when the container stops, and preventing the process from gaining new privileges.

It then prompts the user to enter a Git URL (ex. https://github.com/jocelynkhuu/codeinplace.git) and clones that repo in the container in the temp directory. 

After cloning the repo, it disconnects the container's network interface to ensure the container is isolated.

It then gives an option to run `yara_rule_check.sh` and `evaluate_code.sh` right afterwards and asks if you would like to log the output.

### 2. `yara_rule_check.sh`

This script runs a static analysis designed to spot common malware indicators inside an isolated folder before inspecting the code deeper.

It boots up the yara engine inside the container and feeds it the webshells.yar signature file (compiled by Florian Roth).

YARA sweeps through every file, checking the raw text structure against known cryptographic strings and behaviors tied to web shells, backdoor entry points, and common obfuscation templates. If it finds a match, it prints the exact filename and the rule it tripped.

It also runs Trufflehog to scan for secrets that match known patterns. 

### 3. `evaluate_code.sh`

This an automated AI-driven source code auditor. It acts as a bridge that safely reaches into the isolated container, grabs all the source files, packages them together into a single structured text payload, and streams them directly into Ollama's local AI model for a context-aware malware review.

## 🚀 Manually building from Dockerfile
To manually build the image and create the container from the image, the steps are here. This is automated in `init_sandbox.sh` and the container can be spun up with different settings in Step 2. 

1. `podman build -t secure-audit-image -f alpine_linux_Dockerfile.yaml`
2. `podman run -d --name repo-auditor --cap-drop=ALL --security-opt=no-new-privileges:true --read-only --mount type=tmpfs,destination=/home/auditoruser/analysis,tmpfs-mode=1777,tmpfs-size=512M secure-audit-image`
3. `podman exec -it repo-auditor git clone --depth 1 <REPLACE_WITH_GIT_URL>`
4. `podman network disconnect podman repo-auditor`
5. Update the `TARGET_DIR` in both `evaluate_code.sh` and `yara_rule_check.sh` (or the MODEL in `evaluate_code.sh`)
    - can run `./evaluate_code.sh bash` or `./evaluate_code.sh bash deepseek-coder:latest` to specify a directory at $1 and model at $2 (Defaults to using qwen2.5:3b and a directory called "python")
6. `podman rm -f repo-auditor`

### Example:

```bash
❯ ./init_sandbox.sh
==================================================
   🛡️  INITIALIZING SECURE AUDIT SANDBOX          
==================================================
[*] Cleaning up existing container instance...
[*] Building Podman Security Image...
STEP 1/8: FROM alpine:latest
STEP 2/8: RUN apk add --no-cache     git     bash     yara     curl     jq
--> Using cache 795682d7e51be16c69d5d96c8d8439cbe3a8111a879ca2895016123caddf389c
--> 795682d7e51b
STEP 3/8: RUN curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin
--> Using cache e308ebae7697f1b7c1a6384c5892e5de1e8a8bb0597da7fa3b00924a937acccd
--> e308ebae7697
STEP 4/8: RUN addgroup -S auditorgroup && adduser -S auditoruser -G auditorgroup
--> Using cache 4a73416d42eb13385564200a56076021abba84bf4e4027abc456075ea845b915
--> 4a73416d42eb
STEP 5/8: WORKDIR /home/auditoruser/analysis
--> Using cache f2f4ed2a5f9f3b854146942a59ab9d2a033ce3e5198c221cb0f5747c003f2292
--> f2f4ed2a5f9f
STEP 6/8: RUN mkdir -p /home/auditoruser/rules &&     curl -sL "https://raw.githubusercontent.com/Neo23x0/signature-base/master/yara/gen_webshells.yar" -o /home/auditoruser/rules/webshells.yar &&     chown -R auditoruser:auditorgroup /home/auditoruser
--> Using cache f4c5a5e05cd44ac644c5a8f7a722b0ff2896e0d8b4d69c41eb8880ae60d21a46
--> f4c5a5e05cd4
STEP 7/8: USER auditoruser
--> Using cache 0638d0772e423fdb2e40470db1643678aa21e6602d66fec66ad3f6c123cee46f
--> 0638d0772e42
STEP 8/8: CMD ["sleep", "infinity"]
--> Using cache ff782b0e82319f03ed73d45ce58753b7ac036d2489dab4f664c2c7c9f268d342
COMMIT secure-audit-image
--> ff782b0e8231
Successfully tagged localhost/secure-audit-image:latest
ff782b0e82319f03ed73d45ce58753b7ac036d2489dab4f664c2c7c9f268d342
[*] Spawning unprivileged sandbox container...
c8f985244aba212581b43b3fb4cc4194a90d9879b26f100d3aa91680a72b5124
--------------------------------------------------
👉 Enter the untrusted repository Git URL: https://github.com/jocelynkhuu/codeinplace.git
--------------------------------------------------
[*] Securely cloning: https://github.com/jocelynkhuu/codeinplace.git
Cloning into 'codeinplace'...
remote: Enumerating objects: 8, done.
remote: Counting objects: 100% (8/8), done.
remote: Compressing objects: 100% (8/8), done.
remote: Total 8 (delta 0), reused 5 (delta 0), pack-reused 0 (from 0)
Receiving objects: 100% (8/8), done.
[*] Severing container network interface...
[*] Verifying network isolation status...
✅ VERIFIED: Container network is disconnected.
==================================================
[+] Sandbox Initialization Complete!
    - Destination directory inside container: /home/auditoruser/analysis/codeinplace
==================================================

Next steps to execute your audit tools:
  ./yara_rule_check.sh codeinplace
  ./evaluate_code.sh codeinplace
--------------------------------------------------
👉 Would you like to run ./yara_rule_check.sh? (y/n): y
👉 Would you like to run ./evaluate_code.sh? (y/n): y
👉 Would you like to log the outputs to a file? (y/n): y
--------------------------------------------------
[*] Session logging activated. Saving copy to: ./audit_logs/codeinplace_audit_20260626_203003.log
--------------------------------------------------
==================================================
    ⚡ RUNNING LIGHTWEIGHT MALWARE TRIAGE ⚡       
==================================================
[*] Target Directory: /home/auditoruser/analysis/codeinplace
--------------------------------------------------
[*] Verifying target directory contents (First 5 files):
- /home/auditoruser/analysis/codeinplace/README.md
- /home/auditoruser/analysis/codeinplace/codeinplace_filter.py
- /home/auditoruser/analysis/codeinplace/forest_fire.py
- /home/auditoruser/analysis/codeinplace/khansole_academy.py
- /home/auditoruser/analysis/codeinplace/liftoff.py
--------------------------------------------------

[*] Running YARA Backdoor & Webshell Scanner...

[*] Checking for Suspicious Execution Hooks & Exfiltration...

[*] Running Deep Credential & Secret Verification Scan...
🐷🔑🐷  TruffleHog. Unearth your secrets. 🐷🔑🐷

2026-06-27T03:30:07Z    info-0  trufflehog      running source  {"source_manager_worker_id": "8FEY1", "with_units": true}
2026-06-27T03:30:07Z    info-0  trufflehog      finished scanning       {"chunks": 34, "bytes": 35873, "verified_secrets": 0, "unverified_secrets": 0, "scan_duration": "5.158889ms", "trufflehog_version": "3.95.6", "verification_caching": {"Hits":0,"Misses":0,"HitsWasted":0,"AttemptsSaved":0,"VerificationTimeSpentMS":0}}

==================================================
[+] Scan Complete. If no output appeared above, the repo is clean.
==================================================
==================================================
    🔍 STARTING AI SOURCE CODE ANALYSIS          
==================================================
[*] Target Directory: /home/auditoruser/analysis/codeinplace
[*] Evaluation Model: qwen2.5:3b
--------------------------------------------------
[*] Verifying target directory contents (First 5 files):
- /home/auditoruser/analysis/codeinplace/codeinplace_filter.py
- /home/auditoruser/analysis/codeinplace/forest_fire.py
- /home/auditoruser/analysis/codeinplace/khansole_academy.py
- /home/auditoruser/analysis/codeinplace/liftoff.py
- /home/auditoruser/analysis/codeinplace/nimm.py
--------------------------------------------------
[*] Transmitting codebase to qwen2.5:3b...
[*] Generating concise audit summary...

EXPECTED OUTPUT FORMAT:
VERDICT: NO MALICIOUS CODE DETECTED
SUMMARY: All provided Python scripts are functional and do not contain any 
malicious code or backdoors.

==================================================
```