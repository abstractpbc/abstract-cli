# abstract

The command-line tool for [Abstract](https://abstract.inc). It signs you in and saves an
API key on your machine, so a script or an agent can call the Abstract API.

## Install

```sh
curl -fsSL https://abstract.inc/install.sh | bash
```

The installer supports macOS and Linux on arm64 and x64. It downloads the binary for your
machine, verifies its SHA-256 against the release's `checksums.txt`, and puts it in
`~/.local/bin`. `ABSTRACT_INSTALL_DIR` names another directory, and `ABSTRACT_VERSION`
installs one release, for example `0.1.0`. On Alpine, install `libstdc++` and `libgcc`
first.

## Sign in

```sh
abstract login
```

The command prints a link and a code. Open the link in a browser and confirm the code.
The CLI then saves an API key in `~/.config/abstract/credentials.json`, readable by you
alone.

```sh
curl -H "Authorization: Bearer $(abstract token)" https://api.abstract.inc/v1/models
```

| Command | What it does |
| --- | --- |
| `abstract login` | Signs in through a browser and saves an API key on this machine. |
| `abstract token` | Prints the saved API key, for a script or an agent. |
| `abstract status` | Shows the saved key and checks it against the API. |
| `abstract logout` | Revokes the saved key and signs out. |
| `abstract logout --local` | Removes the saved key from this machine only. |
| `abstract skill` | Prints the skill that teaches an agent the Abstract API. |
| `abstract skill install` | Saves that skill where your agents read skills. |

## For an agent

Paste this into Claude Code, Codex, Cursor, OpenCode or another agent with a terminal:

> Set up Abstract for me. Run `curl -fsSL https://abstract.inc/install.sh | bash`, then
> `abstract login`, and show me the link and code it prints. After I confirm, run
> `abstract status`. Use `$(abstract token)` as the API key and never print it. Then run
> `abstract skill install`, read the skill it installs, and follow it for every call to
> the Abstract API.

## This repository

This repository holds the releases. Every release is compiled here, by the
[release workflow](.github/workflows/release.yml), from `dist/abstract.js`, the bundled
CLI. Each release lists the SHA-256 of every binary in `checksums.txt`.
