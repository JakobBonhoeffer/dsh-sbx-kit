# AGENTS.md

## What this project is

A Docker Sandboxes kit (`kind: workload`, spec `docker/sandbox-kit:3`) that runs
the DeepSeek Harness (DSH) web UI in a microVM. It is the sandbox half of a pair:
[dsh-sbx-client](https://github.com/JakobBonhoeffer/dsh-sbx-client) is the
desktop client half. Keep both descriptions pointing at each other.

## Repository rules

* **Language:** everything in the repository (code, comments, file names, commit
  messages, docs) is in English.
* **No machine-specific details.** No personal paths, user names, drive letters
  of one machine, Docker account names, billing or support details, IPs of a
  home network. Use neutral examples such as `C:\work\dsh_work`.
* **Never commit secrets.** No API keys, launch tokens (`?token=...`), DSH state
  or `.credentials.yaml`. Keys go through `sbx secret set-custom --value-stdin`.
* **Private notes live in `.claude/`**, which is git-ignored. Do not move that
  content into tracked files without removing personal data first.
* **Commit and push only when explicitly asked.**
* Keep this file and `README.md` current with every change that affects them.

## Layout

```
dsh/dsh.yaml          kit descriptor: args, capabilities, agent briefing
dsh/dsh.dockerfile    image recipe
dsh/files/dsh-start   starts dsh web + socat (idempotent, runs every boot)
dsh/files/dsh-url     prints the browser URL with the launch token
usb-esp32/            optional USB mixin, UNTESTED
README.md SECURITY.md LICENSE AGENTS.md .gitignore .gitattributes
```

`dsh.yaml` and `dsh.dockerfile` are paired by their shared file name stem
(`dsh`), which also becomes the agent name. Keep the folder and stem lowercase.

## Architecture and invariants

* DSH binds to `127.0.0.1:3080` only and refuses `--host 0.0.0.0`. A `socat`
  forwarder on `0.0.0.0:3081` makes it reachable for `sbx` port publishing. Do
  not "fix" this by passing `--trusted-host` or changing the bind address.
* The startup hook (`lifecycle@1`) runs `dsh-start` on every boot in the
  background. `long-running@1` keeps the sandbox alive after the last shell
  closes. `dsh-start` must stay idempotent and must set its own `PATH`.
* `network-policy`, `credential` and `usb-device` capabilities are intentionally
  **not** in `dsh.yaml`. Network follows the user's global policy, keys go
  through the host secret store, USB is a separate mixin.
* Core apt packages (Dockerfile step 1) fail the build when missing; tool
  packages (step 2) and pip packages (step 5) are installed one by one and
  logged to `/usr/share/dsh-kit-skipped.txt`. Keep that split.
* The shell scripts are copied with `sed -i 's/\r$//'` in the Dockerfile and
  `.gitattributes` forces LF. Do not remove either.
* The `agent-context` briefing in `dsh.yaml` must stay in sync with what the
  Dockerfile installs.
* Field `family` on `port@1` is not supported by `sbx` 0.51; leave it out.
* Pin versions through the `args` in `dsh.yaml` (`dshVersion`, `nodeVersion`),
  never as literals in the Dockerfile. DSH is a developer preview with breaking
  changes.

## Commands

Run on the host (PowerShell). Existing sandboxes do not pick up kit changes, so
test with a new one.

```powershell
sbx run .\dsh --name dsh-test C:\work\dsh_test      # builds the kit, creates the sandbox
sbx ports dsh-test --publish 18080:3081
sbx exec dsh-test bash -lc "dsh-url 18080"           # token URL
sbx -D run --name dsh-test                           # debug output
sbx rm dsh-test                                      # clean up
```

Inside the sandbox: `ss -ltnp | grep -E ':3080|:3081'`, `tail -n 20 ~/.dsh-web.log`,
`cat /usr/share/dsh-kit-skipped.txt`. `sbx kit validate --offline` does not work
for source kits.

## Testing

There is no automated test suite. Before reporting a change as done:

* Build and start a fresh sandbox from the changed kit and check that the web UI
  answers on the published port and that `dsh-url` prints a working URL.
* Stop and start the sandbox once to prove the startup hook restarts DSH.
* Check `/usr/share/dsh-kit-skipped.txt` for newly skipped packages.
* Mark anything you could not run as "untested" in the docs. Do not claim
  behaviour you have not observed.

## Out of scope

* Heavy tools (Ghidra, ESP-IDF, PlatformIO) in the image. Users add them and use
  `sbx template save`.
* Handling API keys in any form other than the host secret store.
* Cloud-sandbox support (untested; see README quirks).

## Maintenance rules

* New build argument: add it to `args` in `dsh.yaml`, to the `ARG` list in the
  Dockerfile, to the README configuration table.
* New installed tool: add it to the Dockerfile, the briefing in `dsh.yaml` and
  the README feature list.
* Security-relevant behaviour changes must update `SECURITY.md` and the
  README's "Security model".
* Never use `sbx reset` or delete a user's sandboxes, templates or the
  `sbx-kit-builder` sandbox without asking.
