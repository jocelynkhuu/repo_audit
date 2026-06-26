# 🛡️ Repository Auditor

This project provides an isolated, and resource-efficient environment for analyzing code. It leverages containerization to ensure that analysis performed remains sandboxed from the host system.

The system operates in distinct phases:
1. **Initialization:** A clean, minimal container image is built using `alpine:latest`.
2. **Ingestion:** The target code is copied into the container's ephemeral filesystem.
3. **Analysis:** Static analysis tools (e.g., regex, pattern matching) are run against the code.
4. **Reporting:** Results are aggregated and presented to the user.

### Pre-requisites
1. Podman
2. Ollama (By default uses the model `qwen2.5:3b`)
    - Ex. `ollama pull deepseek-coder:latest` or `ollama pull qwen2.5:3b`

## Scripts Included
### 1. `build_container.sh`

This script helps to build the isolated container first deleting an existing running container with the `repo-auditor` name, building a new image named `secure-audit-image` from the `alpine_linux_Dockerfile.yaml` file and running the newly built image as a detached container called `repo-auditor`. It also applies hardening techniques during the build by dropping all Linux capabilities, making the filesystem read-only by default, mounting a temporary filesystem (tmpfs) so that it is wiped when the container stops, and preventing the process from gaining new privileges.

It then prompts the user to enter a Git URL (ex. https://github.com/user/my-repo.git) and then clones that repo in the container in the temp directory. 

After cloning the repo, it disconnects the container's network interface.

### 2. `yara_rule_check.sh`

This script runs a static analysis designed to spot common malware indicators inside an isolated folder before inspecting the code deeper.

It boots up the yara engine inside the container and feeds it the webshells.yar signature file (compiled by Florian Roth).

YARA sweeps through every file, checking the raw text structure against known cryptographic strings and behaviors tied to web shells, backdoor entry points, and common obfuscation templates. If it finds a match, it prints the exact filename and the rule it tripped.

It also runs Trufflehog to scan for secrets that match known patterns. 

### 3. `evaluate_code.sh`

This an automated AI-driven source code auditor. It acts as a bridge that safely reaches into the isolated container, grabs all the source files, packages them together into a single structured text payload, and streams them directly into Ollama's local AI model for a context-aware malware review.

## 🚀 Manually building from Dockerfile
To manually build the image and create the container from the image, the manual steps are here. This is automated in `build_container.sh` and the container can be spun up with different settings in Step 2. 

1. `podman build -t secure-audit-image -f alpine_linux_Dockerfile.yaml`
2. `podman run -d --name repo-auditor --cap-drop=ALL --security-opt=no-new-privileges:true --read-only --mount type=tmpfs,destination=/home/auditoruser/analysis,tmpfs-mode=1777,tmpfs-size=512M secure-audit-image`
3. `podman exec -it repo-auditor git clone --depth 1 <REPLACE_WITH_GIT_URL>`
4. `podman network disconnect podman repo-auditor`
5. Update the `TARGET_DIR` in both `evaluate_code.sh` and `yara_rule_check.sh` (or the MODEL in `evaluate_code.sh`)
    - can run `./evaluate_code.sh bash` or `./evaluate_code.sh bash deepseek-coder:latest` to specify a directory at $1 and model at $2 (Defaults to using qwen2.5:3b and a directory called "python")
6. `podman rm -f repo-auditor`

### Example:

```bash
❯ ./build_container.sh
==================================================
   🛡️  INITIALIZING SECURE AUDIT SANDBOX
==================================================
[*] Building Podman Security Image...
STEP 1/8: FROM alpine:latest
Resolved "alpine" as an alias (/etc/containers/registries.conf.d/000-shortnames.conf)
Trying to pull docker.io/library/alpine:latest...
Getting image source signatures
Copying blob sha256:5de55e5ef9c033997441461efe7ba23a986db059c0bb78b38f84ee0d72b99167
Copying config sha256:1991bd789d7184290c3cce84fd6af068b8b745e9bddf178661ce7f5ecf68135c
Writing manifest to image destination
STEP 2/8: RUN apk add --no-cache     git     bash     yara     curl     jq
( 1/21) Installing ncurses-terminfo-base (6.6_p20260516-r0)
( 2/21) Installing libncursesw (6.6_p20260516-r0)
( 3/21) Installing readline (8.3.3-r1)
( 4/21) Installing bash (5.3.9-r1)
  Executing bash-5.3.9-r1.post-install
( 5/21) Installing brotli-libs (1.2.0-r1)
( 6/21) Installing c-ares (1.34.6-r0)
( 7/21) Installing libunistring (1.4.2-r0)
( 8/21) Installing libidn2 (2.3.8-r0)
( 9/21) Installing nghttp2-libs (1.69.0-r0)
(10/21) Installing libpsl (0.21.5-r3)
(11/21) Installing zstd-libs (1.5.7-r2)
(12/21) Installing libcurl (8.20.0-r1)
(13/21) Installing curl (8.20.0-r1)
(14/21) Installing libexpat (2.8.1-r0)
(15/21) Installing pcre2 (10.47-r1)
(16/21) Installing git (2.54.0-r0)
(17/21) Installing git-init-template (2.54.0-r0)
(18/21) Installing oniguruma (6.9.10-r0)
(19/21) Installing jq (1.8.1-r0)
(20/21) Installing libmagic (5.47-r2)
(21/21) Installing yara (4.5.7-r0)
Executing busybox-1.37.0-r31.trigger
OK: 38.0 MiB in 37 packages
--> a8f90ca35ddb
STEP 3/8: RUN curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin
trufflesecurity/trufflehog info checking GitHub for latest tag
trufflesecurity/trufflehog info found version: 3.95.6 for v3.95.6/linux/arm64
trufflesecurity/trufflehog info installed /usr/local/bin/trufflehog
--> b621f51139b3
STEP 4/8: RUN addgroup -S auditorgroup && adduser -S auditoruser -G auditorgroup
--> 26f096983eb9
STEP 5/8: WORKDIR /home/auditoruser/analysis
--> 7d0ff63810ea
STEP 6/8: RUN mkdir -p /home/auditoruser/rules &&     curl -sL "https://raw.githubusercontent.com/Neo23x0/signature-base/master/yara/gen_webshells.yar" -o /home/auditoruser/rules/webshells.yar &&     chown -R auditoruser:auditorgroup /home/auditoruser
--> efd557130c9f
STEP 7/8: USER auditoruser
--> 97a5ffa83872
STEP 8/8: CMD ["sleep", "infinity"]
COMMIT secure-audit-image
--> 963cbd9534fe
Successfully tagged localhost/secure-audit-image:latest
963cbd9534fe058cc46658b230c6d7d4fe2f5dcd1a8da560d33612f2cf490599
[*] Spawning unprivileged sandbox container...
83989ccc765296ab2a8235129db7102d0068fe09e2b98c1c5af2deeb9c292a70
--------------------------------------------------
👉 Enter the untrusted repository Git URL: https://github.com/jocelynkhuu/codeinplace.git
--------------------------------------------------
[*] Securely cloning: https://github.com/jocelynkhuu/codeinplace.git
Cloning into 'codeinplace'...
remote: Enumerating objects: 8, done.
remote: Counting objects: 100% (8/8), done.
remote: Compressing objects: 100% (8/8), done.
Receiving objects: 100% (8/8), done.
remote: Total 8 (delta 0), reused 5 (delta 0), pack-reused 0 (from 0)
[*] Severing container network interface...
[*] Verifying network isolation status...
✅ VERIFIED: Container network is completely dark.
==================================================
[+] Sandbox Initialization Complete!
    - Destination directory inside container: /home/auditoruser/analysis/codeinplace
    - Network Status: 🚫 DISCONNECTED (Safe to triage)
==================================================

Next steps to execute your triage tools:
  ./yara_rule_check.sh codeinplace
  ./evaluate_code.sh codeinplace
```
```bash
❯ ./yara_rule_check.sh codeinplace
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

2026-06-26T22:41:19Z	info-0	trufflehog	running source	{"source_manager_worker_id": "louMT", "with_units": true}
2026-06-26T22:41:19Z	info-0	trufflehog	finished scanning	{"chunks": 34, "bytes": 35873, "verified_secrets": 0, "unverified_secrets": 0, "scan_duration": "3.381308ms", "trufflehog_version": "3.95.6", "verification_caching": {"Hits":0,"Misses":0,"HitsWasted":0,"AttemptsSaved":0,"VerificationTimeSpentMS":0}}

==================================================
[+] Scan Complete. If no output appeared above, the repo is clean.
==================================================
```
```bash
❯ ./evaluate_code.sh codeinplace
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

VERDICT: NO MALICIOUS CODE DETECTED
SUMMARY: The provided Python files do not contain any backdoors or malicious hooks;
they are functional and safe for educational purposes.


==================================================
```