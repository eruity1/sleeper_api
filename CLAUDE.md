# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`sleeper_api` — a published Ruby gem (rubygems.org, v1.0.0) wrapping [Sleeper's fantasy football API](https://docs.sleeper.com/). Read-only public API: no auth, no API key, no write endpoints.

Consumed by the `fantasy-football-manager` project in the sibling directory, which is the primary real-world user.

## Commands

```bash
bin/setup                  # install deps
bundle exec rake ci        # rubocop + rspec — this is what CI runs
bundle exec rspec
bundle exec rspec spec/sleeper_api/league_spec.rb:42   # single example
bundle exec rubocop -A     # autocorrect
bin/console                # IRB with the gem loaded
```

CI (`.github/workflows/ci.yml`) runs `bundle exec rake ci` on Ruby 3.2 only. The gemspec claims `required_ruby_version >= 2.6.0` and RuboCop targets 2.6, but nothing tests below 3.2 — treat 2.6 compatibility as unverified.

## Architecture

Four layers, with a deliberate split between HTTP and modeling:

- **`SleeperApi`** (`lib/sleeper_api.rb`) — module-level config + memoized global `SleeperApi.client`. `Configuration` validates `timeout` (10–60) and `retries` (0–5), raising `SleeperApi::Error` outside those bounds.
- **`Client`** — the only thing that talks HTTP. `include HTTParty` with `base_uri "https://api.sleeper.app/v1"`. Every call funnels through the private `make_request`, which handles retry-on-timeout, logging, and converts non-2xx into `SleeperApi::Error`. It also owns the 24-hour in-memory player cache.
- **`League` / `User` / `Draft`** — resource objects. Each takes `(id, client)`, fetches eagerly in the constructor, memoizes into ivars, and exposes formatted hashes.
- **`Helpers`** — mixed into all four. `deep_symbolize_keys` plus `player_details`, which reaches through `@client` — so any class including it must define `@client`.

### Conventions that matter

**Raw data is string-keyed; formatted output is symbol-keyed.** The `ATTRIBUTES` readers (defined via `define_method` on each class) return raw API values straight off the string-keyed hash. The `format_*` private methods return symbol-keyed hashes. Don't mix the two — inside `format_rosters` you're indexing `roster["starters"]` but returning `starters:`.

**`Client` returns `HTTParty::Response`, not Hash.** `make_request` returns the response object, which delegates `[]` and `dig` to `parsed_response`, so it usually behaves like a Hash. `get_players` is the exception — it explicitly stores `.parsed_response`. If you add code that needs a real Hash (e.g. `.merge`, `.transform_keys`), call `.parsed_response` yourself; `fetch_playoff_bracket` already does.

**Eager construction.** `League.new` and `User.new` hit the network in the constructor. `League.new(id, client, no_data: true)` skips it — used by `User#rosters` to avoid N redundant league fetches. Be aware `no_data: true` leaves `@league_data` nil, so `format_rosters`' `remaining_faab` falls back to `0 - waiver_budget_used`.

**Guard nil defensively.** Sleeper omits fields freely — users without `metadata`, rosters without `players`, matchups without `points`. Real leagues hit these; the spec fixtures often don't. Use `&.dig` rather than `[]` on anything nested off an API response.

**Never fan out `get_players`.** It's a multi-megabyte payload of every NFL player. It's cached for 24h in an ivar on the client instance — which means the cache dies with the client. Consumers holding a short-lived client re-download it every time.

## Testing

RSpec + WebMock, with `WebMock.disable_net_connect!` — **specs must never hit the network**. Stub with `stub_request` (see `client_spec.rb`) or `instance_double(SleeperApi::Client)` for resource-object specs (see `league_spec.rb`).

`spec_helper.rb` resets `SleeperApi`'s `@client` and `@configuration` ivars before each example, since both are module-level memoized state that would otherwise leak between tests.

**SimpleCov must start before `require "sleeper_api"`.** It previously started after, which meant zero lines were instrumented and `minimum_coverage 90` passed vacuously on 0/0. Don't reorder those requires back — it silently disables the gate rather than failing loudly.

`lib/` is at 100% line coverage. Every bug found in this gem so far has been in a `League#format_*` method handling a field Sleeper omitted, exercised only by real data. When adding a formatter, write the nil-field case first.

## Release

Version lives in `lib/sleeper_api/version.rb`. `bundle exec rake release` tags and pushes to rubygems. Update `CHANGELOG.md` first.

v1.0.0 is published with six bugs that are fixed in the working tree but not yet released — see the unreleased section of `CHANGELOG.md`. Consumers on the published gem still hit them.
