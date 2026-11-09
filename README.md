# DSH Docker Sandbox Kit

A [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) kit that runs the
[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (DSH) web UI
inside an isolated microVM, so the agent never runs directly on your computer.

> **Companion app:** this kit is built to be used together with
> **[dsh-sbx-client](https://github.com/JakobBonhoeffer/dsh-sbx-client)**, a
> desktop client that connects to the DSH web UI in the sandbox and adds
> sandbox tools (start/stop, file browser, log viewer, templates). The kit
> builds and runs the sandbox, the client is the window onto it. Together they
> give you DSH on the host desktop with the agent kept inside a sandbox. The kit
> also works on its own with any browser.

This is an unofficial community project and is not affiliated with DeepSeek or
Docker. The kit format (`docker/sandbox-kit:3`) and several `sbx` commands are
marked experimental by Docker and may change.

## What you get

* **DSH 0.2.2-rc.1** (configurable) and **Node 24** on **Ubuntu 26.04**, in a
  microVM with its own Linux kernel.
* The DSH web UI, started automatically on every boot and published on a
  loopback port of the host.
* A tool box for reverse engineering, ESP32 and Android work: `binwalk`,
  `radare2`, `gdb`/`gdb-multiarch`, `yara`, `nmap`, `tcpdump`, `picocom`,
  `adb`, `apktool`, Java, a Python venv with `esptool`, `pyserial`, `capstone`,
  `unicorn`, `keystone-engine`, `r2pipe`, and a Docker engine inside the
  sandbox. The full list is in [`dsh/dsh.dockerfile`](dsh/dsh.dockerfile).
* API keys that stay on the host. The sandbox only sees placeholders, and the
  host proxy swaps in the real key for the configured provider hosts.

Heavy tools such as Ghidra, ESP-IDF or PlatformIO are deliberately not included.
Install them in the sandbox and save the result with `sbx template save`.

## Requirements

* The Docker Sandboxes CLI [`sbx`](https://docs.docker.com/ai/sandboxes/),
  signed in with `sbx login`. Developed and tested with `sbx` 0.51.0.
* Windows 11 with the Windows Hypervisor Platform feature enabled. **Windows is
  the only tested host.** macOS and Linux may work, but this is untested.
* Internet access for the first build (about 6 minutes) and for the model
  providers you use.
* An account with a model provider that DSH supports.

## Quick start

All commands below run on the host in PowerShell. Replace the placeholders in
angle brackets with your own values:

| Placeholder | Meaning |
|---|---|
| `<name>` | Name you choose for the sandbox. Lowercase, unique per sandbox. |
| `<workspace>` | Folder on your computer that the agent may read and write, for example `C:\work\my_project`. |
| `<host-port>` | Free port on your computer for the web UI, for example `18080`. Use a different one per sandbox. |

**1. Get the kit and create the sandbox.** The first path is the primary
workspace, further paths are optional extra mounts (`:ro` makes one read-only).

```powershell
git clone https://github.com/JakobBonhoeffer/dsh-sbx-kit
sbx run .\dsh-sbx-kit\dsh --name <name> <workspace>
```

`sbx` builds the kit on first use and starts a login shell in the new sandbox.
You can leave it with `exit`: the kit keeps the sandbox running.

**2. Publish the web UI on a fixed host port.** Without this, `sbx` picks a
random port that changes on every start. The sandbox side is always `3081`.

```powershell
sbx ports <name> --publish <host-port>:3081
```

**3. Store your API key on the host** (see [API keys](#api-keys)).

**4. Open the web UI.** DSH creates a new launch token each time it starts. The
helper `dsh-url` prints a ready-to-use address with that token. It needs the
host port from step 2, because the address points at your computer, not at the
sandbox. Run it in one of two ways:

*From the host (PowerShell)*, without entering the sandbox:

```powershell
sbx exec <name> bash -lc "dsh-url <host-port>"
```

*From inside the sandbox*, if you are already in its shell (for example right
after `sbx run`, or after `sbx exec -it <name> bash`):

```bash
dsh-url <host-port>
```

Open the printed `http://127.0.0.1:<host-port>/?token=...` address in your browser or
connect with [dsh-sbx-client](https://github.com/JakobBonhoeffer/dsh-sbx-client).
DSH exchanges the token for a session cookie, so you need it only once per
browser profile. To skip the manual step in the client, set its login command to
`dsh-url {port}`; see the client README.

Day-to-day commands: `sbx ls`, `sbx stop <name>`, `sbx run --name <name>`,
`sbx ports <name>`. To start over, `sbx rm <name>` and repeat step 1 and 2.

## API keys

Keys never go into the sandbox. Store them in the host credential store; the
host proxy replaces a placeholder with the real key on requests to the host you
name.

```powershell
$k = Read-Host "Key" -MaskInput
$k | sbx secret set-custom --host openrouter.ai --env OPENROUTER_API_KEY --value-stdin
Remove-Variable k
```

`sbx secret ls` then shows a placeholder (`sbx-cs-...`). Enter that placeholder
as the API key in the DSH web UI (Settings, Models) together with the provider's
base URL. Use a dedicated key with a spending limit for this.

`sbx secret set-custom` is experimental. Secrets set before a sandbox exists may
not appear as environment variables in older sandboxes, which does not matter
here because DSH takes the placeholder directly.

## How it works

```
Host (Windows)
  Browser / dsh-sbx-client ──> 127.0.0.1:<host-port> ──┐
  sbx + daemon (egress proxy, secret store)            │ published port
                                                       v
  microVM "<name>" (own kernel)
    socat 0.0.0.0:3081 ──> 127.0.0.1:3080 (dsh web)
    mounts: your folders only
```

* **`dsh.yaml`** is the kit descriptor. It declares the build arguments, the
  startup hook, `long-running` (so the UI survives closing the last shell) and
  the `port` request for container port 3081.
* **`dsh.dockerfile`** builds the image: base packages, tools (one by one, so a
  missing package lands in `/usr/share/dsh-kit-skipped.txt` instead of failing
  the build), Node, DSH, the Python venv.
* **`dsh/files/dsh-start`** starts `dsh web` and a `socat` forwarder.
  It is idempotent and runs at every boot.
* **`dsh/files/dsh-url`** prints the browser URL with the current launch token.

Why `socat`? DSH binds to `127.0.0.1` only and refuses `--host 0.0.0.0`. Port
publishing reaches the sandbox from outside and cannot see a loopback-only
service, so `socat` listens on `0.0.0.0:3081` and passes traffic to
`127.0.0.1:3080`. The `Host` header stays `127.0.0.1:<port>`, so DSH's own
loopback check still applies.

## Configuration

Build arguments are set in `dsh/dsh.yaml` or at creation time with `--kit-arg`:

| Argument | Default | Meaning |
|---|---|---|
| `dshVersion` | `0.2.2-rc.1` | `@deepseek-ai/dsh` release to install |
| `nodeVersion` | `24.22.2` | Node.js release to install |

DSH is a developer preview with breaking changes, so the version is pinned.
Existing sandboxes do not pick up kit changes; create a new sandbox after
editing the kit. To add packages, test them first with `sudo apt install` in the
running sandbox and add them to `dsh/dsh.dockerfile` only if you need them
permanently.

To run several sandboxes from one kit, give each a unique lowercase name and its
own host port:

```powershell
sbx run .\dsh-sbx-kit\dsh --name <other-name> <other-workspace>
sbx ports <other-name> --publish <other-host-port>:3081
```

## Security model

**Protected**

* The agent reaches the host only through the folders you mount.
* Real API keys stay on the host.
* The web UI is published on host loopback only and needs the launch token or
  its session cookie.
* The sandbox has its own Docker daemon and no access to the host's.

**Not protected, by design**

* The agent has full write access to every mounted folder. Files it leaves
  there (a `Makefile`, `package.json` scripts, git hooks) can act on your host
  if you run them there. Review results before using them.
* Outbound network access follows your global `sbx` policy. With a permissive
  policy the sandbox can send data from mounted folders to the internet.
* The agent has passwordless `sudo` and a Docker daemon inside the VM, so it is
  effectively root there.
* The sandbox can still spend your provider credit through the placeholder key.
  Limit this with spending caps on the key itself.
* DSH calls itself an experimental developer preview without a security audit.
  Its built-in permission system is not a security boundary, which is why this
  kit exists.

Mount only what the agent needs, use `:ro` for input data, and keep valuable
data out of writable mounts. See [SECURITY.md](SECURITY.md).

## Known quirks

* Use lowercase names for the kit folder, sandboxes and templates. The kit
  name comes from the `dsh.yaml` file name stem.
* Mounts, `--clone` and `-e` can only be set when a sandbox is created.
* `dsh-start` sets its own `PATH`, because the startup hook runs with a
  different one than `sbx exec`.
* DSH shows up as `MainThread` in `ps`; check `ss -ltnp | grep -E ':3080|:3081'`
  instead of `pgrep dsh`.
* Each DSH start prints a new launch token; the cookie is bound to address and
  port, hence the fixed port.
* `sbx reset` deletes every sandbox, policy, secret and your login. Don't.
* `sbx kit validate --offline` does not work for source kits; validation
  happens during `sbx run`.
* Not tested: combining the kit with a saved template (`-t`), and running the
  kit in Docker's cloud sandboxes (which would need a different
  `--public-url` / `--trusted-host` setup and have no host mounts).

## Optional: USB for ESP32

[`usb-esp32/`](usb-esp32/) is a mixin that asks for USB passthrough of common
ESP32 boards. **It is untested**; see its README.

## Related projects

* [dsh-sbx-client](https://github.com/JakobBonhoeffer/dsh-sbx-client): desktop
  client for the DSH web UI with sandbox tools. Use it with this kit.
* [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
* [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) and the
  [kit specification](https://github.com/docker/sandbox-kit-spec)

## License

[MIT](LICENSE)
