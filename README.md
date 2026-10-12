<div align="center">

# 🐣ghfind

**A GitHub repository search tool for the terminal.**

Pure Lua. Single file. No dependencies beyond `curl`.

[![Lua](https://img.shields.io/badge/lua-5.1%2B-2C2D72?logo=lua&logoColor=white)](https://www.lua.org/)
[![License](https://img.shields.io/badge/license-MIT-3DA639.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20Termux-4A90D9)]()
[![Dependencies](https://img.shields.io/badge/dependencies-curl%20only-orange)]()
[![Status](https://img.shields.io/badge/status-stable-brightgreen)]()

[Report Bug](https://github.com/7helix/ghfind/issues) · [Request Feature](https://github.com/7helix/ghfind/issues)

</div>

---

`ghfind` searches GitHub from the command line and returns results in a
clean, color-coded list. It is designed for developers who want fast
repository discovery without leaving the terminal, and for scripts that
need structured search output.

There is no installer, no package manager, and no runtime environment to
configure. The entire program is a single Lua script that reads and writes
plain text files.

```
$ lua5.4 ghfind.lua

  ghfind  repo searcher

  1  search
  2  filters
  3  presets
  4  watch
  5  favorites
  6  history
  7  token
  8  settings
  9  help
  c  clear screen
  0  exit

  >
```

---

## Contents

- [Why ghfind](#why-ghfind)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Usage](#usage)
  - [Search](#search)
  - [Filters](#filters)
  - [Presets](#presets)
  - [Watch mode](#watch-mode)
  - [Favorites and history](#favorites-and-history)
  - [Settings](#settings)
- [Authentication](#authentication)
- [Configuration files](#configuration-files)
- [Environment variables](#environment-variables)
- [Cross-platform support](#cross-platform-support)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)
- [Acknowledgements](#acknowledgements)

---

## Why ghfind

Most GitHub search tools fall into one of two categories. Either they are
web interfaces that require a browser and a mouse, or they are heavyweight
CLI tools with dozens of dependencies and a configuration language of
their own.

`ghfind` takes a third approach. It is a single Lua file that does one
thing: search GitHub and display the results. It stores its state as plain
text. It uses the tools already present on most systems. It runs equally
well on a laptop, a server, and an Android phone.

If you need something with more features, the GitHub CLI (`gh`) is
excellent and probably what you want. If you need something you can read
end-to-end in a coffee break, modify in five minutes, and carry in your
dotfiles, `ghfind` is designed for that.

---

## Features

| Feature | Description |
|---|---|
| **Interactive menu** | All operations behind numbered options. No flags to memorize. |
| **Structured search** | Filter by language, minimum stars, and last-push date. Sort by stars, forks, or recency. |
| **Presets** | Save a query with its filters and recall it with a single keystroke. |
| **Watch mode** | Poll a query on an interval. Only new repositories are displayed. |
| **Desktop notifications** | Optional system notifications on Linux and macOS when watch mode finds results. |
| **Favorites** | Bookmark repositories from search results and revisit them. |
| **Search history** | The last 30 queries are stored. Any of them can be rerun. |
| **Token management** | Paste, validate, and audit a GitHub token from inside the tool. |
| **Scope auditing** | Warns if a token has more permissions than necessary. |
| **Zero dependencies** | The JSON parser is included. Only `curl` is required at runtime. |
| **Cross-platform** | Linux, macOS, Windows, and Termux from the same file. |

---

## Requirements

| Component | Minimum version | Notes |
|---|---|---|
| Lua | 5.1 | 5.4 recommended |
| curl | any recent | Bundled with Windows 10+ |
| git | any | Optional, required only for the clone action |

---

## Installation

### Package managers

**Ubuntu / Debian**

```bash
sudo apt install lua5.4 curl git
```

**macOS**

```bash
brew install lua curl git
```

**Arch Linux**

```bash
sudo pacman -S lua curl git
```

**Termux**

```bash
pkg install lua54 curl git
```

**Windows**

```powershell
winget install DEVCOM.Lua
winget install Git.Git
```

`curl` is already included with Windows 10 and later.

### Download the script

```bash
curl -sSL -o ghfind.lua https://raw.githubusercontent.com/7helix/ghfind/main/ghfind.lua
```

### Optional: install as a global command

Linux, macOS, Termux:

```bash
mkdir -p ~/bin
mv ghfind.lua ~/bin/ghfind
chmod +x ~/bin/ghfind
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Then run:

```bash
ghfind
```

---

## Quick start

```bash
lua5.4 ghfind.lua
```

Enter `1` to search. Type a query. Press Enter.

The first time you run `ghfind`, no configuration exists. Defaults are
applied automatically. Everything you change is saved and reused on the
next run.

---

## Usage

### Search

Menu option **1**. Enter a natural-language query. Results show the
repository name, description, primary language, star and fork counts,
last update date, and URL.

After a search, the following single-key actions are available:

| Key | Action |
|---|---|
| `o` | Open the top result in the default browser |
| `c` | `git clone` the top result into the current directory (or a directory you specify) |
| `f` | Save a specific result to favorites |
| `s` | Save the query and current filters as a named preset |

### Filters

Menu option **2**. Filters persist across searches until changed.

| Filter | Accepted values |
|---|---|
| Language | Any language recognized by GitHub (`lua`, `rust`, `python`, `go`, ...) |
| Sort | `stars`, `forks`, or `updated` |
| Minimum stars | Integer. Repositories below this threshold are excluded. |
| Maximum age | Days since last push. Repositories older than this are excluded. |
| Limit | Result count. Default `5`. |

### Presets

Menu option **3**. Presets capture a query together with every active
filter at the time of saving.

- Press `r` to run a preset.
- Press `d` to delete it.

Presets are stored in the configuration file and survive upgrades.

### Watch mode

Menu option **4**. Runs a search on an interval and displays only
repositories not previously seen.

```
4  watch
   query > neovim plugin
   every how many seconds? > 300
   max passes (blank=forever) >
   desktop notifications? [y/N] > y
```

Progress is tracked per query in `~/.config/ghfind/seen_<query>.txt`.
Restarting the tool does not repeat previous results.

Notifications use `notify-send` on Linux and `osascript` on macOS. They
are silently skipped on Windows.

### Favorites and history

Menu options **5** and **6**.

Favorites list saved repositories with the option to open or delete any
entry. History lists the last 30 queries with the option to rerun or
clear.

### Settings

Menu option **8**.

| Setting | Description |
|---|---|
| Default limit | Result count used when `ghfind` starts |
| Default language | Language filter applied when `ghfind` starts |
| Notifications | Enable or disable desktop notifications in watch mode |
| Auto-open | Open the top result automatically after each search |
| Clear seen cache | Delete all watch-mode progress files |
| Reset all settings | Return every option to its default |

---

## Authentication

`ghfind` works without authentication. Unauthenticated requests to
GitHub's search API are limited to **10 requests per minute**.

Providing a personal access token raises the limit to **30 requests per
minute**. A token with **no scopes selected** is sufficient — `ghfind`
only reads public data.

### Creating a token

1. Open https://github.com/settings/tokens
2. Select **Generate new token (classic)**
3. Name it, for example `ghfind`
4. Leave **every scope checkbox unchecked**
5. Click **Generate token**
6. Copy the value. It is shown only once.

### Providing the token

**Through the menu**

```
7  token
   1  paste token
```

**Through a file**

```bash
mkdir -p ~/.config/ghfind
echo 'ghp_xxxxxxxxxxxx' > ~/.config/ghfind/token
chmod 600 ~/.config/ghfind/token
```

**Through the environment**

```bash
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

Precedence order, from highest to lowest: environment variable, then
token file.

### Auditing the token

```
7  token
   2  check token
```

This reads the `OAuth-Scopes` response header from GitHub and reports
every scope granted to the token. Any of the following indicates an
over-privileged token that should be revoked immediately:

`repo`, `user`, `security_events`, `delete_repo`, `admin:org`,
`workflow`, `admin:public_key`.

---

## Configuration files

All state lives in a single directory. Plain text only.

```
~/.config/ghfind/
├── token            GitHub personal access token (mode 600)
├── config.txt       Defaults and presets, key=value format
├── history.txt      Last 30 queries, one per line
├── favs.txt         Favorite repositories, name<TAB>url
└── seen_*.txt       Watch mode progress, one file per query
```

On Windows the directory is `%USERPROFILE%\.config\ghfind\`. The contents
are identical.

### `config.txt`

```
default_limit=5
default_lang=lua
notify=off
auto_open=off
preset_my_lua_tui_q=tui file manager
preset_my_lua_tui_lang=lua
preset_my_lua_tui_sort=stars
```

Every line is `key=value`. Empty lines and lines beginning with `#` are
ignored. The file can be edited by hand without restarting the tool.

### `favs.txt`

```
folke/tokyonight.nvim	https://github.com/folke/tokyonight.nvim
catppuccin/nvim	https://github.com/catppuccin/nvim
```

Name and URL separated by a tab character.

---

## Environment variables

| Variable | Description |
|---|---|
| `GITHUB_TOKEN` | A GitHub personal access token. Overrides the token file. |
| `NO_COLOR` | When set to any value, disables ANSI color output. |
| `XDG_CACHE_HOME` | Overrides the default Linux cache location. |

---

## Cross-platform support

`ghfind` detects the host platform at startup and selects the appropriate
commands. No separate builds are required.

| Operation | Linux, macOS, Termux | Windows |
|---|---|---|
| Path separator | `/` | `\` |
| Config directory | `~/.config/ghfind/` | `%USERPROFILE%\.config\ghfind\` |
| Clear screen | `clear` | `cls` |
| Sleep | `sleep` | `ping -n` |
| Notifications | `notify-send`, `osascript` | Not supported |
| Open URL | `xdg-open`, `open` | `start` |
| File permissions | `chmod 600` | NTFS permissions |

Windows users on shared machines should protect the token file using
NTFS permissions. The `chmod` call in the script is a no-op on Windows
and produces no error.

---

## Roadmap

Planned for future releases. Order is approximate.

- [ ] JSON output for scripting (`--json` flag)
- [ ] Non-interactive mode with command-line flags
- [ ] Self-update command
- [ ] Additional search fields (topics, license, size)
- [ ] Support for GitHub Enterprise API endpoints
- [ ] Optional Shell completion scripts

Suggestions are welcome through
[GitHub Issues](https://github.com/7helix/ghfind/issues).

---

## Contributing

Contributions are welcome. The project follows a small set of rules to
keep it useful.

### Constraints

- **Single file.** The entire program is one `.lua` file. No modules, no
  build step, no code generation.
- **No new dependencies.** `curl` is the only external tool. If a library
  is needed, it is written inline.
- **Cross-platform.** Every change must work on Linux, macOS, Windows,
  and Termux.
- **Backwards compatible.** Existing menu options, key bindings, and file
  formats should not change without a strong reason.
- **Readable.** Lines under 80 characters. Meaningful variable names in
  new code. Comments where behavior is not obvious.

### Development setup

```bash
git clone https://github.com/7helix/ghfind.git
cd ghfind
lua5.4 ghfind.lua
```

No other setup is required.

### Before opening a pull request

```bash
lua5.4 -e "assert(loadfile('ghfind.lua'))" && echo ok
lua5.4 ghfind.lua
```

Both commands must succeed without warnings or errors.

### Reporting bugs

Open an issue at
[github.com/7helix/ghfind/issues](https://github.com/7helix/ghfind/issues).
Include:

- Operating system and Lua version (`lua5.4 -v`)
- The exact command you ran
- Full output, including any error message
- Whether `GITHUB_TOKEN` was set

### Suggesting features

Describe the use case before the implementation. "I want to do X but
ghfind makes it hard" is more useful than "add flag Y".

---

## Security

- **Never commit a token.** `.gitignore` covers the common locations.
  A pre-commit hook is included in the repository to catch accidents.
- **Never paste a token in a screenshot or a chat.** If you do, revoke
  it immediately at https://github.com/settings/tokens.
- **Use the minimum scope.** For `ghfind`, that means no scopes at all.
- **Report security issues privately.** Use the GitHub Security Advisory
  form at https://github.com/7helix/ghfind/security/advisories/new
  instead of opening a public issue.

---

## License

MIT. See [LICENSE](LICENSE).

You are free to use, modify, and redistribute this software, including
for commercial purposes. Attribution is appreciated but not required.

---

## Acknowledgements

- [Lua](https://www.lua.org/) — the language
- [GitHub REST API](https://docs.github.com/en/rest) — the data source
- Everyone who has filed an issue or opened a pull request

---

<div align="center">

<sub>Made with Lua. Maintained at <a href="https://github.com/7helix/ghfind">7helix/ghfind</a>.</sub>

</div>
