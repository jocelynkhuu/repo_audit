# 🛡️ Repository Auditor

This project contains the Dockerfile and scripts needed to create a lightweight Alpine Linux container that is segmented with a non-root user so malicious code cannot escalate and is sandboxed from the host.

To build this image
1. `podman build -t secure-audit-image -f alpine_linux_Dockerfile.yaml`
2. `podman run -d --name repo-auditor --cap-drop=ALL --security-opt=no-new-privileges:true --read-only --mount type=tmpfs,destination=/home/auditoruser/analysis,tmpfs-mode=1777,tmpfs-size=512M secure-audit-image`
3. `podman exec -it repo-auditor git clone --depth 1 <REPLACE_WITH_GIT_URL>`
4. `podman network disconnect podman repo-auditor`
5. Update the `TARGET_DIR` in both `evaluate_code.sh` and `yara_rule_check.sh`
6. `podman rm -f repo-auditor`

## What does this do?

```bash
podman run -d \
  --name repo-auditor \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  --read-only \
  --mount type=tmpfs,destination=/home/auditoruser/analysis,tmpfs-mode=1777,tmpfs-size=512M \
  secure-audit-image
```

1. Rootless Podman (The Ultimate Guardrail)

Because you are using Podman on a Mac, the container runs inside a rootless Linux virtual machine. Even if the malware finds a mythical zero-day exploit to break out of the container, it only escapes into a locked-down, unprivileged user account inside the VM. It still cannot touch your actual macOS filesystem or host processes.

2. `--cap-drop=ALL` & `--security-opt=no-new-privileges:true`

Linux malware often tries to escape by exploiting vulnerabilities to gain root (kernel privileges).

    `--cap-drop=ALL` strips away raw network control, raw disk access, and kernel modification capabilities.

    `no-new-privileges` ensures that even if the malware runs a setuid binary or finds a vulnerability, Linux strictly forbids it from escalating past your low-privilege auditoruser.

3. `--read-only` & `--mount type=tmpfs...`

The entire operating system of the container is locked down like a read-only CD-ROM. If malware tries to infect system binaries, drop a persistent script in /etc, or modify the shell, the kernel blocks the write request. The only place it can write files is inside the 512MB RAM disk (tmpfs), which evaporates the second you kill the container.

### Example:

```bash
~/github/dockerfile_yamls
❯ podman build -t secure-audit-image -f alpine_linux_Dockerfile.yaml
STEP 1/7: FROM alpine:latest
Resolved "alpine" as an alias (/etc/containers/registries.conf.d/000-shortnames.conf)
Trying to pull docker.io/library/alpine:latest...
Getting image source signatures
Copying blob sha256:5de55e5ef9c033997441461efe7ba23a986db059c0bb78b38f84ee0d72b99167
Copying config sha256:1991bd789d7184290c3cce84fd6af068b8b745e9bddf178661ce7f5ecf68135c
Writing manifest to image destination
STEP 2/7: RUN apk add --no-cache     git     bash     yara     curl     jq
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
--> d11398596d11
STEP 3/7: RUN addgroup -S auditorgroup && adduser -S auditoruser -G auditorgroup
--> 8422c3307cb5
STEP 4/7: WORKDIR /home/auditoruser/analysis
--> 3cbbef1adfe2
STEP 5/7: RUN mkdir -p /home/auditoruser/rules &&     curl -sL "https://raw.githubusercontent.com/Neo23x0/signature-base/master/yara/gen_webshells.yar" -o /home/auditoruser/rules/webshells.yar &&     chown -R auditoruser:auditorgroup /home/auditoruser
--> a5022d8472c3
STEP 6/7: USER auditoruser
--> bcebc5f1109a
STEP 7/7: CMD ["sleep", "infinity"]
COMMIT secure-audit-image
--> f5033b59e95d
Successfully tagged localhost/secure-audit-image:latest
f5033b59e95d78ccf44ddbe57025c1ff0c804084b6401f442bd0c4a5104b7d98

~/github/dockerfile_yamls                                                                 4s
❯ podman run -d --name repo-auditor --cap-drop=ALL --security-opt=no-new-privileges:true --read-only --mount type=tmpfs,destination=/home/auditoruser/analysis,tmpfs-mode=1777,tmpfs-size=512M secure-audit-image
c421473477327f3fdcdfd50902fbf85fa58390b2ea755f842f97d89350a8db30

~/github/dockerfile_yamls
❯ podman exec -it repo-auditor git clone --depth 1 https://github.com/jocelynkhuu/bash.git
Cloning into 'bash'...
remote: Enumerating objects: 10, done.
remote: Counting objects: 100% (10/10), done.
remote: Compressing objects: 100% (8/8), done.
remote: Total 10 (delta 0), reused 2 (delta 0), pack-reused 0 (from 0)
Receiving objects: 100% (10/10), done.

~/github/dockerfile_yamls
❯ podman network disconnect podman repo-auditor

~/github/dockerfile_yamls
❯ bash evaluate_code.sh
==================================================
    🔍 STARTING AI SOURCE CODE ANALYSIS
==================================================
[*] Verifying target directory contents (First 5 files):
- /home/auditoruser/analysis/bash/add_printer_mac.sh
- /home/auditoruser/analysis/bash/appointment_tracker.sh
- /home/auditoruser/analysis/bash/deprecationnotifier.sh
- /home/auditoruser/analysis/bash/jamf_recon.sh
- /home/auditoruser/analysis/bash/update_hostname.sh
--------------------------------------------------
[*] Transmitting codebase to deepseek-coder:1.3b...
[*] Generating concise audit summary...

VERDICT: NO MALICIOUS CODE DETECTED. The scripts provided in this codebase do not
contain any malicious components, which is a key point of security for MacOS systems as
it can be vulnerable to various attacks such as denial-of-service (DoS) and buffer
overflows where the system could hang or crash if too much data was processed at once.

The scripts also include features like appointment tracking in appointments CSV file, a
launch agent for automatic reminders after installing DeprecationNotifier MacOS app to
notify users about upcoming macOS updates/deprecations and cleanup of previous user's
.appointmentdates.csv if required (using the latest version).



==================================================
❯ bash yara_rule_check.sh
==================================================
   ⚡ RUNNING LIGHTWEIGHT MALWARE TRIAGE ⚡
==================================================

[*] Running YARA Backdoor & Webshell Scanner...
error: could not open file: /home/noroot/rules/webshells.yar

[*] Checking for Suspicious Execution Hooks & Exfiltration...

==================================================
[+] Scan Complete. If no output appeared above, the repo is clean.
==================================================

~/github/dockerfile_yamls
❯ podman images
REPOSITORY                         TAG         IMAGE ID      CREATED        SIZE
localhost/secure-audit-image       latest      f5033b59e95d  2 minutes ago  40.7 MB
docker.io/library/alpine           latest      1991bd789d71  10 days ago    8.95 MB
localhost/fedora_custom_image      latest      b19a03b1bb0a  6 weeks ago    348 MB
registry.fedoraproject.org/fedora  latest      de8e91948e78  6 weeks ago    199 MB

~/github/dockerfile_yamls
❯ podman ps -a
CONTAINER ID  IMAGE                                 COMMAND         CREATED        STATUS                   PORTS       NAMES
de26fbef6ed1  localhost/fedora_custom_image:latest  /usr/bin/zsh    6 weeks ago    Exited (0) 6 weeks ago               fedora_playground
c42147347732  localhost/secure-audit-image:latest   sleep infinity  2 minutes ago  Up 2 minutes (starting)              repo-auditor
```