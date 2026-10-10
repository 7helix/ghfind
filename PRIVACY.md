# privacy

i don't collect anything. there's no analytics, no tracking, no
server, no account, no email signup. i don't know who you are and
i have no way to find out.

## the cli

when you run `ghfind.lua --seen`, it writes repo names to
`~/.cache/ghfind/`. that's a text file on your disk. delete it
with `--clear-seen` or just `rm -rf ~/.cache/ghfind`. it never
leaves your machine.

your github token — if you set one — lives where you put it.
either in `GITHUB_TOKEN` or in `~/.config/ghfind/token`. that's
your file, your permissions, your problem. put `chmod 600` on it.

the script talks to `api.github.com` and nothing else. no other
server, no proxy, no middleman. whatever github does with the
requests is between you and github, not me.

## the website

the site stores a few things in your browser so it doesn't forget
them:

- favorites you starred
- search history
- saved presets
- dark/light theme
- grid/list view

those are in `localStorage` on `7helix.github.io`. if you paste a
token into the token field, that goes in `sessionStorage` — gone
when you close the tab.

wipe everything: devtools → application → clear storage. or use
the clear buttons in the favorites and history drawers.

the site loads fonts from google. that's the only third party.
sorry, i know, but i'm not self-hosting font files for a cute
lua toy.

## what i don't do

- no cookies
- no analytics
- no error reporting
- no crash reporting
- no "product improvements"
- no fingerprinting
- no tracking pixels
- no ads
- no signing you up for anything
- no sharing with anyone because there's nothing to share

## changes

if this changes, the date at the top changes. the git history
shows every edit. it's a static site and a single lua file, you
can diff it yourself.

## contact

open an issue on the repo if you have a question about any of
this. i'll answer.
