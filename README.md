# 🐣 ghfind

A tiny, cute GitHub repository searcher — in pure Lua. Single file, no deps.

    lua ghfind.lua "neovim colorscheme" --sort stars

## Install

    curl -O https://raw.githubusercontent.com/7helix/ghfind/main/ghfind.lua

Needs `lua` and `curl`.

## Usage

    lua ghfind.lua "words" [opts]

    -l/--lang X      language filter
    -s/--sort X      stars | forks | updated
    -n/--limit N     how many (default 5)
    -t/--check-token inspect token scopes
    -r/--recommend   show safe scopes
    -h/--help

## Token

Optional. Raises rate limit. No scopes needed.

    export GITHUB_TOKEN=ghp_xxx

or drop it in `~/.config/ghfind/token`.

Check it:

    lua ghfind.lua --check-token

## License

MIT
