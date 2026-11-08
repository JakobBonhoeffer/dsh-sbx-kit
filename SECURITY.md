# Security

## Scope

This repository contains a Docker Sandboxes kit (descriptor, Dockerfile, two
helper scripts) and an optional USB mixin. It runs the DeepSeek Harness inside a
microVM. It is **not** a hardened product: DSH is an experimental developer
preview, and the sandbox runs the agent with passwordless `sudo` and a Docker
daemon inside the VM.

## What the kit does and does not protect

See the "Security model" section of the [README](README.md). In short, isolation
comes from the microVM and from mounting only the folders you choose. Anything in
a writable mount is exposed to the agent, and outbound network access follows
your global `sbx` policy.

## Handling secrets

* Never put real API keys into the sandbox, a mounted folder, a template or this
  repository. Use `sbx secret set-custom ... --value-stdin` on the host.
* Do not commit launch tokens (`?token=...`) or DSH state (`~/.dsh`).

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private
vulnerability reporting under the repository's Security tab. If it is not
available, open an issue that asks for a private contact without describing the
details.

Problems in DSH itself belong to the
[DeepSeek Harness repository](https://github.com/deepseek-ai/deepseek-harness);
problems in `sbx` belong to Docker.
