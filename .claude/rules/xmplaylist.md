# xmplaylist CLI: stable project rules

## API and auth (no secrets here)
- Base URL: `https://xmplaylist.com` (override with `XMPLAYLIST_BASE_URL` only for testing).
- Auth: `Authorization: Bearer $XMPLAYLIST_API_KEY`, sent only when the key is set. Public endpoints work without it.
- The key comes from the repo `.env` (and optional `.env.local`), gitignored symlinks to `~/1-areas/servant/xmplaylist/secrets/.env*`, loaded by `bin/xmplaylist` without overriding exported variables.
- Never print, log, echo, or commit `XMPLAYLIST_API_KEY` or the Authorization header, including under `XMPLAYLIST_DEBUG=1`. Never commit `.env` or `.env.*`; only the placeholder `.env.example` is tracked.
- No keychain flow and no auth-guard hook.
- Quota: Supporter keys get 100 requests/day. Prefer one call per command; `--all` is capped at 50 pages.

## Invocation
- `xmplaylist` on PATH is `~/.local/bin/xmplaylist`, a symlink to `bin/xmplaylist` created by `ruby install.rb`. `bin/xmplaylist` finds its repo through `File.realpath`.
- Use `bin/xmplaylist` for every xmplaylist call. No raw curl and no generic passthrough command.

## Exit codes
- 0 ok; 1 usage or other; 2 auth (401, or 403 "requires paid plan"); 3 not found; 4 other API error, including 429 after one retry.

## Write safety
- Every write goes through `CommandSupport.write!`: build request -> dry-run exit -> guard -> send -> print. Every write supports `-d/--dry-run`; a dry run never prompts and never sends.
- Deletes need the resource name or id typed on a TTY, or `--yes`. Non-TTY without `--yes` exits 1 with nothing sent. No environment-variable bypass.
- No real write against the live API during development or tests. Verify writes with `-d` and specs.

## Code rules
- Ruby stdlib only. No Gemfile, gemspec, or Rakefile.
- One file per command in `lib/xmplaylist_cli/commands/`, listed in `COMMANDS` (and `WRITE_COMMANDS` for writes) in `bin/xmplaylist`, its usage heredoc, and the README.
- Request builders live in `lib/xmplaylist_cli/endpoints.rb` and are checked against `docs/xmplaylist-openapi.json`. Refresh with `curl -fsS https://xmplaylist.com/api/spec`.
- Specs are minitest with no network: `for f in spec/*_spec.rb; do ruby -Ilib "$f" || exit 1; done`.

## Public repo
- This repository is public under the MIT license. Fixtures and docs use placeholder data only. Never commit a real key, email, or account detail.
