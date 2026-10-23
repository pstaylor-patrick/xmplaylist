# xmplaylist

A small command-line client for the [xmplaylist.com](https://xmplaylist.com) API, which tracks what SiriusXM channels play. Ruby standard library only: no Gemfile, no gems at runtime.

Commands cover public reads (channels, play history, the live feed, rankings, channel updates) and paid features (search, artists, reports, roster, subscriptions). Every write can be previewed with `-d`, and deletes ask you to type the resource id. There is no generic API passthrough: every command maps to one endpoint in `docs/xmplaylist-openapi.json`.

## Setup

1. Clone the repo:

   ```bash
   git clone https://github.com/pstaylor-patrick/xmplaylist.git
   cd xmplaylist
   ```

2. Get an API key from your xmplaylist.com account (public reads work without one).
3. Keep secrets outside the repo. The author's layout is `~/1-areas/servant/xmplaylist/secrets/`, holding a `.env` (and optionally `.env.local`) with a line `XMPLAYLIST_API_KEY=...`. See `.env.example`.
4. Symlink every `.env*` file from that directory into the repo root:

   ```bash
   for f in ~/1-areas/servant/xmplaylist/secrets/.env*; do ln -sfn "$f" "$(basename "$f")"; done
   ```

   `.env` and `.env.*` are gitignored. `bin/xmplaylist` loads `.env` then `.env.local` on every run without overriding anything you already exported.

5. Install the binary and the agent skill:

   ```bash
   ruby install.rb
   ```

6. Run `xmplaylist usage` to check the key.

Requires Ruby 3.4 or newer (CI runs 4.0).

### What install.rb does

`install.rb` is idempotent; re-run it after pulling. It:

| Target | Action |
|--------|--------|
| `~/.local/bin/xmplaylist` | Symlink to `bin/xmplaylist`. Only replaces a missing entry or a symlink already pointing into this repo; anything else stops the install with `refusing to replace` and changes nothing |
| Claude Code | Symlinks `~/.claude/skills/xmplaylist` to `skills/xmplaylist` |
| Pi | Adds `~/.claude/skills` to the `skills` roots in `~/.pi/agent/settings.json` |
| OpenCode | Copies the skill to `~/.config/opencode/skills/xmplaylist`, marks it with `.xmplaylist-skill-generated`, and lists that directory under `skills.paths` in `~/.config/opencode/opencode.jsonc` |

Config files are backed up to `*.bak` before they are rewritten.

## Commands

```
Stations (CH is a deeplink, name, or channel number):
  stations [--extended]           Every channel (--extended is paid)
  station CH [-n N] [--all] [--since-ms MS]
                                  Recent plays, newest first; --all follows pages (cap 50)
  newest CH                       Tracks the channel played for the first time
  most-heard CH [WINDOW]          Most-played tracks
  movers CH [WINDOW] [--decliners]
                                  Biggest play-count gainers (or decliners)
  rankings CH [WINDOW]            Track ranks against the previous period
  artist-rankings CH [WINDOW]     Artist ranks against the previous period
  track CH TRACK_ID               One track's detail on a channel
  WINDOW is one of --days N, --year YYYY, --month YYYY-MM, --week YYYY-MM-DD
  (past 60 days and calendar windows are paid).

Feed and channel updates:
  feed                            The latest plays across every channel
  channel-updates [--days 1-30] [--channel CH] [--name S] [--offset N] [--all]
                                  Daily channel lineup changes
  update-channels                 Channels with update history

Search (requires XMPLAYLIST_API_KEY):
  search [FILTERS] [--as-of TIME] [--page N] [--limit 50|100|200|500|1000] [--aggregate] [--all]
                                  Track plays matching the filters
  search-insights [FILTERS] [--page N]
                                  Summary for the same filters
  labels Q [--limit 1-25]         Record label suggestions
  recent-searches                 Your recent searches
  search-export [FILTERS] [--aggregate] [--out FILE] [-d]
                                  Paid write: CSV export (large ones are emailed)
  FILTERS: --track S --track-match includes|exact --isrc S --artist S
           --artist-match all|any --label S --station CH --time-ago SECONDS
           --start YYYY-MM-DD --end YYYY-MM-DD

Artists (ID is a Spotify artist id):
  artists Q [--full]              Find artists (--full: every known identity)
  artist ID                       One artist
  artist-peers ID                 Artists played alongside
  artist-history ID [--stations]  Play history by track (or station)
  artist-rank ID --station CH     Current rank on one channel
  hot [--full]                    Artists gaining spins
  artist-updates ID [--preview]   Update-email setting (or email preview)
  artist-updates-set ID --on|--off [-d]
                                  Write: turn update emails on or off

Reports (paid):
  report --list                   Every report kind and its flags
  report KIND [ID] [--FLAG V ...] e.g. report most-played --days 30

Roster (ID is a roster artist id):
  membership                      Your roster plan and seats
  roster                          Roster artists
  roster-show ID                  One roster artist
  roster-add NAME [--spotify ID] [-d]
                                  Write: add an artist
  roster-remove ID [--yes] [-d]   Write: remove an artist (typed-id guard)
  roster-link ID [--show] [-d]    Show, or write: switch to the linked artist
  roster-peers ID                 Artists played alongside
  roster-report ID [--days 7|30|90|365]
  roster-catalog ID [--days 7|30|90|365]
  roster-sparklines ID [--days 7|30|90|365]
  roster-history ID [--stations]  Play history by track (or station)
  roster-rank ID --station CH     Current rank on one channel

Subscriptions:
  subs                            Your subscriptions
  sub ID                          One subscription
  sub-create --file F | --stdin [-d]
                                  Write: create from a JSON object
  sub-update ID --file F | --stdin [-d]
                                  Write: patch from a JSON object
  sub-delete ID [--yes] [-d]      Write: delete (typed-id guard)

Misc:
  usage                           API requests remaining today
  track-report TRACK_ID --link URL [-d]
                                  Write: report a corrected track link
```

Global flags: `-j/--json` (JSON envelope), `--version`, `-h/--help`. Run `xmplaylist report --list` for report kinds.

Every write takes `-d/--dry-run`. `roster-remove` and `sub-delete` require typing the id on a TTY, or `--yes`.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | OK |
| 1 | Usage or other error |
| 2 | Auth: 401 (set `XMPLAYLIST_API_KEY`) or 403 (requires paid plan) |
| 3 | Not found |
| 4 | Other API error, including 429 after one retry |

## Quota

Supporter keys allow 100 requests a day. `--all` follows pages but stops at 50 with a warning. `xmplaylist usage` shows what is left.

## Development

```bash
for f in spec/*_spec.rb; do ruby -Ilib "$f" || exit 1; done
```

Specs use minitest with no network.

## License

MIT. See [LICENSE](LICENSE).
