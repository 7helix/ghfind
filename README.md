<div align="center">

# 🐣 ghfind

**A tiny, cute GitHub repository searcher — in pure Lua.**

Single file · zero dependencies · ships with its own JSON parser

[![Made with Lua](https://img.shields.io/badge/made%20with-Lua-2C2D72?logo=lua&logoColor=white)](https://www.lua.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/7helix/ghfind/pulls)
[![Website](https://img.shields.io/badge/site-live-8be9fd)](https://7helix.github.io/ghfind/)

[**🌐 Live demo**](https://7helix.github.io/ghfind/) · [**📖 Usage**](#-usage) · [**🔐 Token safety**](#-token-safety) · [**🤝 Contributing**](#-contributing)

</div>

---

## ✨ Overview

`ghfind` searches GitHub from the command line. It prints results as a
cute, colorful list with stars, forks, language, and last-updated date.
The whole tool is a single Lua file with no external libraries — the JSON
parser is bundled in.

---

## 📥 Installation

**Requirements:** `lua` (5.1+) and `curl`.

```bash
# Ubuntu / Debian
sudo apt install lua5.4 curl

# macOS
brew install lua curl

# Arch
sudo pacman -S lua curl
```

**Get the script:**

```bash
curl -O https://raw.githubusercontent.com/7helix/ghfind/main/ghfind.lua
chmod +x ghfind.lua
```

Optionally move it onto your `$PATH`:

```bash
sudo mv ghfind.lua /usr/local/bin/ghfind
```

---

## 🚀 Usage

```
lua ghfind.lua "words" [options]
```

### Search options

| Flag | Description |
|---|---|
| `-l`, `--lang LANG` | Filter by programming language |
| `-s`, `--sort FIELD` | Sort by `stars`, `forks`, or `updated` |
| `-n`, `--limit N` | Number of results (default: 5) |
| `--min-stars N` | Only repos with at least N stars |
| `--pushed DATE` | Only repos pushed after `YYYY-MM-DD` |

### Actions

| Flag | Description |
|---|---|
| `-o`, `--open` | Open top result in browser |
| `-c`, `--clone [DIR]` | `git clone` the top result |
| `--random` | Pick one result at random |

### Automation

| Flag | Description |
|---|---|
| `-w`, `--watch N` | Repeat every N seconds, show only new |
| `-W N` | Stop watch after N passes |
| `--seen` | Skip already-seen repos (cached) |
| `--clear-seen` | Wipe the seen cache |
| `--notify` | Desktop notification on new repos |
| `--save FILE` | Append results to a file |
| `--json` | JSON output (pipe-friendly) |

### Token utilities

| Flag | Description |
|---|---|
| `-t`, `--check-token` | Inspect your token's scopes |
| `-r`, `--recommend` | Show the recommended minimal scopes |

### Examples

```bash
# Basic search
lua ghfind.lua "neovim colorscheme"

# Lua HTTP servers, sorted by stars
lua ghfind.lua "http server" --lang lua --sort stars

# High-quality projects only
lua ghfind.lua "web framework" --min-stars 5000

# Open the top result in your browser
lua ghfind.lua "tui file manager" -s stars -o

# Clone the top result
lua ghfind.lua "http server" -l lua -c ~/src

# Random pick
lua ghfind.lua "terminal game" --random -o

# Watch for new repos, notify, save
lua ghfind.lua "neovim plugin" -w 300 --seen --notify --save ~/ghf.log

# Pipe to jq
lua ghfind.lua "markdown parser" --json | jq '.[].full_name'

# Cron job (once per day)
lua ghfind.lua "lua game engine" --seen --notify -w 1 -W 1
```

---

## 🔐 Token safety

`ghfind` only needs **read access to public repositories** — which is
exactly what a classic token with **zero scopes** provides. Use a token
to raise the rate limit from 10 to 30 searches per minute.

**Check your current token:**

```bash
lua ghfind.lua --check-token
```

**See the recommended minimal scopes:**

```bash
lua ghfind.lua --recommend
```

**Provide a token** (either method works):

```bash
# environment variable
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

```bash
# or a locked-down file
mkdir -p ~/.config/ghfind
echo ghp_xxxxxxxxxxxx > ~/.config/ghfind/token
chmod 600 ~/.config/ghfind/token
```

Create a token at https://github.com/settings/tokens — **no scopes needed.**

Never commit a token. Never put it in the script. If you leak one, revoke
it immediately at the link above.

---

## 🎨 Environment

| Variable | Purpose |
|---|---|
| `GITHUB_TOKEN` | Optional. Raises your API rate limit. |
| `NO_COLOR` | Set to any value to disable ANSI colors. |
| `XDG_CACHE_HOME` | Where the `--seen` cache is stored (default `~/.cache`) |

---

## 🧪 Testing

```bash
lua ghfind.lua --help
lua ghfind.lua --recommend
lua ghfind.lua --check-token
lua ghfind.lua "hello world" -n 1
```

The repository runs these automatically on every push via GitHub Actions
(see `.github/workflows/test.yml`).

---

## 🖥️ Web playground

A browser version lives at https://7helix.github.io/ghfind/ — same search,
no installation required. It stores an optional token in `sessionStorage`
only and never sends it anywhere except GitHub's API.

---

## 🤝 Contributing

Contributions are welcome. Please keep the CLI:

- **single file** — no external modules, no build step
- **dependency-free** — only `curl` and Lua's standard library
- **backwards-compatible** — don't rename flags without a good reason

Before opening a pull request:

```bash
lua ghfind.lua --help
lua ghfind.lua "hello world" -n 1
```

---

## 📜 License

MIT — see [LICENSE](LICENSE).

---

<div align="center">

Made with 🐣 and Lua

</div>
