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
