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

CI (`.github/workflows/ci.yml`) runs `bundle exec rake ci` on Ruby 3.2 and 3.4. The gemspec claims `required_ruby_version >= 2.6.0` and RuboCop targets 2.6, but nothing tests below 3.2 — treat 2.6 compatibility as unverified.

## Architecture

Four layers, with a deliberate split between HTTP and modeling:

- **`SleeperApi`** (`lib/sleeper_api.rb`) — module-level config + memoized global `SleeperApi.client`. `Configuration` validates `timeout` (10–60) and `retries` (0–5), raising `SleeperApi::Error` outside those bounds.
- **`Client`** — the only thing that talks HTTP. `include HTTParty` with `base_uri "https://api.sleeper.app"` — **the bare host; the `/v1` lives in each path**. That is deliberate and load-bearing: not every Sleeper endpoint is versioned. `/schedule/{sport}/{season_type}/{season}` is served from the host root, and while `base_uri` carried the version that endpoint was unreachable at any path a caller could pass in. A new endpoint spells out where it lives; do not move the version back into `base_uri` to shorten the paths.

  Every call funnels through the private `make_request`, which handles retry-on-timeout, logging, and converts non-2xx into `SleeperApi::Error`. **That error quotes the path**, so the path prefix is part of a public string — v1.2.0 changed it from `"Failed to fetch /user/x: 404"` to `"Failed to fetch /v1/user/x: 404"`. `Client` also owns the 24-hour in-memory player cache.
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

### There is no committed Gemfile.lock, so CI resolves fresh every run

That is right for a library — a lockfile would hide exactly the incompatibility
a consumer is going to hit — but it has a consequence worth naming: **a green
run does not stay green.** A transitive release can turn CI red with no commit
in between, and the first PR opened afterwards looks like the culprit.

`json` 3.0 did this on 2026-09-11. It removed `quirks_mode`, which
`httparty` 0.24.2 passes on every JSON parse, so 11 examples began raising
`ArgumentError: unknown keyword: quirks_mode` — on a documentation-only PR that
touched no code. Check whether `main` is red before reading a failure as the
branch's fault; `main`'s last run can be weeks old.

`SleeperApi::JsonParser` is the fix, and it is worth reading before reaching for
a version pin: the gem overrides the one broken method rather than constraining
`json` in the gemspec, because a constraint there would forbid every consuming
app from upgrading `json` for a flag none of them asked for.

## Release

Version lives in `lib/sleeper_api/version.rb`. Update `CHANGELOG.md`, then `bundle exec rake release` from a clean `main`, which builds to `pkg/`, tags, pushes the tag, and uploads to rubygems.

**The API key needs the `push_rubygem` scope.** `gem signin` defaults to `index_rubygems` only — read access — and answering `n` to "Do you want to customise scopes?" produces a key that fails the upload with `This API key cannot perform the specified action on this gem`. Answer `y` and enable `push_rubygem`, or edit the key's scopes at https://rubygems.org/profile/api_keys. Credentials land in `~/.local/share/gem/credentials` (the XDG path, not `~/.gem/credentials`).

**`rake release` is not atomic.** It tags and pushes the tag *before* uploading, so a failed upload leaves the tag published and the gem unreleased. Recovering means `gem push pkg/sleeper_api-<version>.gem` on the existing artifact — re-running `rake release` fails on the tag that already exists.

Consumers do not get a fix until it is published *and* they bump their lockfile.
