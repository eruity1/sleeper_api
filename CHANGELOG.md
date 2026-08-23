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
