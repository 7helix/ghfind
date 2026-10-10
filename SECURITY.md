# security

## versions

only `main` is supported. no releases, no backports, no LTS. fix
lands on main, you `git pull`, done.

## found a bug?

please don't open a public issue if it's a security thing. use
github's private advisory thing:

https://github.com/7helix/ghfind/security/advisories/new

or open a blank issue saying "security, need contact" and i'll
reply with an email. don't put the details in the issue itself.

tell me:

- what's broken
- how to make it happen
- what you expected
- what you think the damage is
- if you want credit when it's fixed

i'll get back to you in a few days. this is a hobby project, be
cool about it.

## not my problem

- github's api having issues → tell github
- github pages going down → tell github
- google fonts → tell google
- your `curl` being compromised → reinstall your system
- someone reading your token because you pasted it in a screenshot
  → revoke it now at https://github.com/settings/tokens
- rate limits → those are github's, not mine
- anything that needs physical access to your box

## how this thing actually trusts stuff

**your token** is a bearer credential. anyone who reads it can act
as it. put it in `~/.config/ghfind/token` with `chmod 600`. never
commit it. never paste it anywhere public. if you leak it, revoke
it immediately — that's the only real fix.

**the seen cache** is just a file. if something else on your
system can write to `~/.cache/ghfind/`, it could inject fake
entries. cosmetic, not dangerous, but worth knowing.

**the website** keeps your token in `sessionStorage` only. it
never goes anywhere except `api.github.com`. close the tab and
it's gone.

**curl** does all the cli http. if your curl is compromised, that's
your system, not this tool.

## good habits

- use a classic github token with **zero scopes checked**. this
  tool reads public data only, it doesn't need any permissions.
  `lua ghfind.lua --recommend` shows you exactly this.
- run `lua ghfind.lua --check-token` to see what your current
  token can do. it flags over-privileged ones.
- rotate tokens once in a while.
- don't pipe `--json` output into `bash`. it's for `jq`. come on.

## thanks
--
