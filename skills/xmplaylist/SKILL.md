---
name: xmplaylist
description: Use the local xmplaylist CLI for the xmplaylist.com API - SiriusXM channel plays, feeds, rankings, search, artists, reports, roster, and subscriptions. Use whenever the user asks about xmplaylist data or what a SiriusXM channel is playing.
---

# /xmplaylist skill

Use `xmplaylist` (on PATH through `~/.local/bin/xmplaylist`) for every
xmplaylist.com operation. Never call the API with raw curl and never parse it
yourself. If a field you need is missing from human output, run the same
command with `-j` and read the JSON; a missing field is a CLI bug worth
reporting.

The CLI reads `XMPLAYLIST_API_KEY` from the `.env` symlink in its own repo.
Never print, echo, or pass the key on the command line. Public reads (stations,
station history, feed) need no key.

## Invocation

```
xmplaylist [-j|--json] <command> [args] [options]
xmplaylist --help        # full command list with every flag
xmplaylist report --list # every report kind
```

- `-j` wraps output as `{"ok": true, "command": ..., "data": ...}` with the raw API data.
- `CH` is a channel deeplink, exact name, or channel number. No partial matches.

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

## Writes

Every write takes `-d/--dry-run`, which prints the request and sends nothing.
`roster-remove` and `sub-delete` need the id typed on a TTY or `--yes`; without
a TTY and without `--yes` they exit 1 and send nothing. Dry-run first, and only
write when the user asked for the change.

## Exit codes

0 ok; 1 usage or other; 2 auth (401: set `XMPLAYLIST_API_KEY`; 403: requires
paid plan); 3 not found; 4 other API error, including 429 after one retry.

## Paid plan and quota

Search, reports, roster, subscriptions, and longer windows need a paid key. A
403 means the key's plan does not cover the endpoint; do not retry it. A
Supporter key allows 100 requests a day: prefer `feed` for "what is playing",
make one call per question, avoid `--all` (it can spend up to 50 requests), and
check `xmplaylist usage` when in doubt.
