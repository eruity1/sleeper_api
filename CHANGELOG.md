## [1.5.0] - 2026-09-25

### Added

- **`Client#scores(season, week = nil)` — games with their kickoff times.** Each
  game carries `start_time`, epoch milliseconds, which is **the only kickoff
  time Sleeper publishes**: `#schedule` has a `date` and nothing finer. Measured
  2026-09-25 against ATL @ GB, the previous night's Thursday game — its
  `start_time` is 2026-09-25T00:15Z and agrees with `metadata.date_time` on
  every game of the week.

  ⚠️ **Also on `api.sleeper.com`**, like `#stats_with_context`, and with a
  different shape: the season type is a **path segment**
  (`/scores/nfl/regular/2026/3`), and the query-parameter form answers 200 with
  nothing.

  **Leave the week off for the whole season** — all 272 games of 2026 in one
  ~610 KB call (~93 KB gzipped), against ~57 KB a week. `metadata` is the live
  game (`quarter`, `time_remaining`, quarter scores, `is_in_progress`) plus the
  TV channel, spread and forecast. Its `status` vocabulary (`scheduled`,
  `closed`) differs from the top level's (`pre_game`, `complete`), and neither
  value a live game carries has been read yet. Nothing 404s: week 19 and a
  garbage season type answer `[]`.

## [1.4.0] - 2026-09-14

### Added

- **`Client#stats_with_context(season, week)` — one week's stat lines carrying
  the week they were played in.** Each row has the player's team *that week*,
  their `opponent`, the `game_id` and the `date`, which the existing `#stats`
  endpoint does not return at all.

  ⚠️ **It is served from a different host: `api.sleeper.com`, not
  `api.sleeper.app`.** Same sport and season in the path, no `/v1`, and the
  season type is a query parameter rather than a segment. The `.app` endpoint
  answers the *same stat lines with none of this metadata*, which is how it sat
  unfound through four epics of stats work in the consuming app.

  **What is genuinely per-week, measured** over the 2,275 players present in
  both week 1 and week 16 of 2021: `team` differs on **164** of them and
  `opponent` on **2,262**. ⚠️ **The nested `player` object is not history** — it
  is the current catalog record stapled on, with `team` null inside it and
  `injury_status` differing on 1 of the 204 rows carrying one across those
  fifteen weeks. A 2021 row reporting "Questionable" is reporting that he is
  questionable *now*.

  ⚠️ **Pass a week.** Dropping it answers season totals — 8,251 rows for 2021 —
  with `week` and `opponent` null on every one, so the season form carries none
  of the context the endpoint exists for. Shares `#stats`' traps otherwise:
  nothing 404s, and `pre`/`post` restart week numbering. An array of rows, not
  a hash keyed by player id.

### Changed

- **`make_request` takes an optional `host:`**, which is how the second host is
  reached. ⚠️ **Passing an absolute URL instead does not work**: HTTParty 0.24
  raises `UnsafeURIError` for any URL whose host differs from the configured
  `base_uri` — "this request could send credentials to an unintended server" —
  so a second host has to arrive as its own per-request `base_uri`.

  **Errors and logs now name the host whenever it is not the default.**
  `/stats/nfl/2021/16` is a real path on both hosts and they return different
  things, so a message quoting the path alone cannot say which one failed.
  Messages for paths on `api.sleeper.app` are byte-for-byte what they were.

## [1.3.1] - 2026-09-10

### Fixed

- **Every request raised `ArgumentError: unknown keyword: quirks_mode` under
  `json` 3.0.** HTTParty 0.24.2 parses with `JSON.parse(body, quirks_mode:
  true, allow_nan: true)`; json 3.0 removed that keyword. Total breakage rather
  than a degradation, and it arrives through a transitive bump rather than
  anything a consumer chose — this gem has no committed lockfile, so CI went
  red with no commit in between. httparty 0.24.2 is the newest release and has
  no fix.

  `SleeperApi::JsonParser` subclasses `HTTParty::Parser` and overrides its
  `json` method to drop the flag; `Client` parses with it. **Deliberately not a
  `json < 3` pin in the gemspec**, which would fix the same crash by forbidding
  every app that uses this gem from upgrading json at all, for a flag none of
  them asked for.

  `quirks_mode: true` allowed a bare scalar at the top level, which is not
  academic here — Sleeper answers an unknown username with a literal `null`.
  Both majors parse that correctly without it: `JSON.parse("null")` is `nil`
  under 2.21.2 and under 3.0.2. The suite passes under both.

### Documented

Three facts measured against the live API on 2026-09-10, while NFL week 1 was
half-played — one game finished, one being played, fourteen not yet started.
No behaviour changed; all three are things a caller could previously only find
out by being wrong first.

- **`#schedule`'s `status` values are named: `pre_game`, `in_game`, `complete`,
  `canceled`.** `in_game` was read off a live game; the other three come from
  the published 2025 and 2026 schedules. It is the only per-game signal that a
  game has been played — this payload has a `date` and no kickoff time, so a
  caller can know a game is under way but never how far into it. **A week is
  not one event**: week 1 of 2026 held three of those states at once, so
  reasoning about "has the week started" from `date` alone gets it wrong for
  everyone whose game is on Sunday. Treat the four as open and match with a
  fallback — a postponement would be a fifth and none has been seen.

- **`#projections` is a pre-game, whole-game projection that does not move
  while the game is played.** Five players in one night's game held the same
  `pts_ppr` to the decimal across six hours spanning its kickoff; a game that
  had already finished still projected 19.69 for a player who scored 26.2, so
  it does not settle onto the final either. This is the natural endpoint to
  reach for when building anything live, and it cannot answer the question:
  **there is no live projection here**, so nothing in this payload says whether
  a player is on pace. A player on 8 of a projected 12 in the first quarter is
  ahead of schedule, and this reports 12 all afternoon.

- **`#stats` answers a week still being played with a partial set, and says
  nothing about being partial.** Mid-week-1 it returned 301 rows with 42
  carrying a `pts_ppr`. That is distinct from the already-documented empty
  week: a caller treating "the week's stats" as the whole week gets a
  half-filled answer for as long as the week is in progress, which for a
  regular-season week is most of five days. `#schedule`'s per-game `status` is
  the only thing that tells a missing row from a scoreless one.

### Changed

- `#schedule`'s spec fixture carries all four statuses rather than `pre_game`
  alone, and an example pins that they pass through untranslated. The narrow
  fixture was a shape live data produces only on a quiet Tuesday, and a fixture
  narrower than the API is how a caller ends up written against a vocabulary of
  one.

## [1.3.0] - 2026-08-27

### Added

- `Client#stats(season, week:, season_type:, sport:)` and `Client#projections(...)` — per-player weekly statistics and projections, both undocumented, both under `/v1`. Found by probing on 2026-08-27; the consuming app's backlog had recorded "Sleeper has no projections endpoint and no player-stats endpoint" as settled fact, and several of its cards were blocked on that.

  Each returns an object keyed by player id — plus `TEAM_XXX` keys for team-level rows — holding raw counting stats (`rec`, `rush_yd`, `off_snp`, `rec_rz_tgt`, …) alongside Sleeper's canned `pts_ppr` / `pts_half_ppr` / `pts_std`. 228 distinct fields were observed across one week of 2025. Omitting `week` requests season totals, which is a shorter path and a different resource rather than a default of week 1.

  Three things a caller has to know, all confirmed live:

  - **Nothing 404s.** An unplayed week (`regular/2026/1`), a week out of range (`regular/2025/99`) and an unrecognised season type (`banana`) all answer 200 with `{}`. An empty body is indistinguishable from a typo, so validate arguments rather than trusting emptiness.
  - **A row count is not evidence of a projection.** `projections` for a season Sleeper has not projected still returns a full set of entries — 9,386 for 2030 — every one holding only `{"adp_dd_ppr" => 1000.0}` and no `pts_ppr`. Filter on the field you want.
  - **`pre` and `post` restart week numbering at 1**, exactly as `#schedule` does, so rows from different season types must never be pooled.

  `adp_dd_ppr` 1000.0 and `pos_rank_*` 999.0 are "unknown" sentinels rather than values.

  Path segments are escaped, unlike the older `#get_user` — an unescaped segment can walk out of the endpoint entirely, which the consuming app had to work around at its own boundary.

### Fixed

- README.md contained 272 non-breaking spaces across 90 lines, 58 of them **inside `​```ruby` code fences** — so the documented examples raised a syntax error when copy-pasted. `lib/` and `spec/` were unaffected; only the documentation was broken. Replaced with ordinary spaces.

## [1.2.0] - 2026-08-23

### Added

- `Client#schedule(season, season_type:, sport:)` — a season's game list, each entry `{status, date, home, away, week, game_id}`. A team's bye week is the week it appears in no game, which derives exactly: checked against 2024, 2025 and 2026, every one gives exactly one bye per team. Note `pre` (weeks 1-3) and `post` (weeks 1-4) restart week numbering, so games from different season types must never be pooled, and a season Sleeper has not scheduled yet answers 200 with `[]` rather than 404.

### Changed

- **`base_uri` is now the bare host, `https://api.sleeper.app`, and every path carries its own `/v1`.** The schedule endpoint is served from the host root, so while the version lived in `base_uri` it was unreachable at any path a caller could pass to `make_request`. Moving the version into the paths means one mechanism for every endpoint rather than an escape hatch for the exceptions.

  **This changes the text of `SleeperApi::Error`**, which quotes the path it failed on: `"Failed to fetch /user/x: 404"` is now `"Failed to fetch /v1/user/x: 404"`. Anything matching on that string needs updating — though matching on it was never sound, since the same error covers a missing user, a 5xx and a timeout alike.

## [1.1.0] - 2026-08-22

### Fixed

- `League#rosters` truncated every score. Sleeper splits a score across two integer fields — `fpts: 1617` with `fpts_decimal: 78` is 1617.78 — and `total_points` read `fpts` alone. The loss was invisible because what remained was still a plausible score, and no fixture carried a `fpts_decimal` to catch it. **This changes `total_points` from an Integer to a Float** for any roster whose score has a fractional part.
- `League#rosters` returned `co_owners: nil` for every roster, always. It read `roster["co_owner"]`, singular; no Sleeper payload has ever contained that key. Now reads the plural spelling, and still yields `nil` when the field is absent — Sleeper's documented roster object does not include co-owners, though the published docs are partial (the league `settings` object is rendered only as `{ settings object }`).

### Added

- `League#rosters` now returns `points_against`, combining `fpts_against` with `fpts_against_decimal` the same way. Previously reachable only by digging into the raw `settings` hash that passes through wholesale.

## [1.0.1] - 2026-08-12

### Fixed

- `User#leagues` returned `nil` on every call after the first, because the memoization guard was the method's return value
- `League#users` raised `NoMethodError` when any league member had no `metadata` (Sleeper omits it for users who never set a team name), which also broke `#playoff_bracket` and `#toilet_bowl`
- `Client#make_request` raised `NameError: undefined local variable 'config'` when a retry fired with a logger configured — the retry path was only reachable with logging on, so it never surfaced in tests
- `League#matchups_by_week` returned a literal `nil` element for any roster with no `matchup_id` (bye weeks / unscheduled rosters)
- `League#matchups_by_week` raised `NoMethodError` when a matchup roster had no `players` or no `points`
- `League#users` memoization checked an undefined `@fetch_users` ivar instead of `@league_users`

### Changed

- SimpleCov now starts before the library is required. It previously started after, so no lines were instrumented and the `minimum_coverage 90` gate passed vacuously on 0/0 lines. Real coverage at the time was 72%; `lib/` is now at 100%.

## [1.0.0] - 2025-01-17

### Added

- Complete Sleeper API coverage (users, leagues, drafts, players, matchups, transactions)
- Smart caching system for player data (24-hour TTL)
- Comprehensive error handling with automatic retries
- Configurable timeouts and logging
- Type signatures (RBS) for better IDE support
- Extensive test suite with 90%+ coverage
- CI/CD pipeline with GitHub Actions
- Code quality tools (RuboCop, SimpleCov)

### Features

- League management with roster and matchup data
- User profiles with league and draft history
- Draft analysis with picks and traded picks
- Player data with trending statistics
- Performance optimizations and rate limiting
- Comprehensive inline documentation

### Development

- RSpec test suite
- RuboCop code quality
- SimpleCov test coverage
- GitHub Actions CI/CD
