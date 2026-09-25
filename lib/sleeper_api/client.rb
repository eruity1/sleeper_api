require "httparty"
require "openssl"
require "json"
require "erb"

module SleeperApi
  # HTTP client for Sleeper API requests.
  #
  # Handles all low-level HTTP calls, caching, retries, and error handling.
  # Use via {SleeperApi.client} or create directly.
  #
  # @example
  #   client = SleeperApi::Client.new(config)
  #   league = client.league("123456")
  #   user = client.user("username")
  class Client
    include Helpers
    include HTTParty

    # The host only. The API version belongs in the paths because not every
    # endpoint has one: /schedule is served from the root, and while base_uri
    # carried "/v1" that endpoint was unreachable at any path a caller could
    # pass to make_request.
    base_uri "https://api.sleeper.app"

    # ⚠️ **The other Sleeper host.** The web app talks to `api.sleeper.com`,
    # which serves *richer rows from same-looking paths* — see
    # #stats_with_context. Reached per-request rather than by moving base_uri,
    # because every other endpoint here lives on `.app`.
    WEB_HOST = "https://api.sleeper.com".freeze

    # The request never got an answer (1.5.1): no DNS, a refused or reset
    # connection, a failed TLS handshake, a socket closed mid-response. Before,
    # these escaped as themselves, so a caller rescuing SleeperApi::Error for
    # an outage missed the commonest one. Timeouts are handled separately.
    CONNECTION_ERRORS = [SocketError, SystemCallError, OpenSSL::SSL::SSLError, EOFError].freeze

    # Not HTTParty's own. Its JSON branch passes `quirks_mode`, which json 3.0
    # removed, so without this every response raises ArgumentError the moment a
    # consumer resolves json 3. See JsonParser.
    parser SleeperApi::JsonParser

    # @param config [SleeperApi::Configuration] Client configuration
    def initialize(config)
      @config = config
      @players_cache = nil
      @cache_timestamp = nil
    end

    # Create a new {SleeperApi::League} instance.
    #
    # @param league_id [String] League identifier
    # @return [SleeperApi::League]
    # @see https://docs.sleeper.com/#leagues
    def league(league_id)
      League.new(league_id, self)
    end

    # Create a new {SleeperApi::User} instance.
    #
    # @param identifier [String] Username or user ID
    # @return [SleeperApi::User]
    # @see https://docs.sleeper.com/#user
    def user(identifier)
      User.new(identifier, self)
    end

    # Create a new {SleeperApi::Draft} instance.
    #
    # @param draft_id [String] Draft identifier
    # @return [SleeperApi::Draft]
    # @see https://docs.sleeper.com/#drafts
    def draft(draft_id)
      Draft.new(draft_id, self)
    end

    # Fetch user data by identifier.
    #
    # @param identifier [String] Username or user ID
    # @return [Hash] Raw user data
    # @see https://docs.sleeper.com/#user
    def get_user(identifier)
      make_request("/v1/user/#{identifier}")
    end

    # Get leagues for a user in a specific season.
    #
    # @param user_id [String] User ID
    # @param sport [String] Sport code (default: "nfl")
    # @param season [Integer] Season year (default: current year)
    # @return [Array<Hash>] League data
    # @see https://docs.sleeper.com/#get-all-leagues-for-user
    def get_user_leagues(user_id, sport: "nfl", season: Time.now.year)
      make_request("/v1/user/#{user_id}/leagues/#{sport}/#{season}")
    end

    # Get drafts for a user in a specific season.
    #
    # @param user_id [String] User ID
    # @param sport [String] Sport code (default: "nfl")
    # @param season [Integer] Season year (default: current year)
    # @return [Array<Hash>] Draft data
    # @see https://docs.sleeper.com/#get-all-drafts-for-user
    def get_user_drafts(user_id, sport: "nfl", season: Time.now.year)
      make_request("/v1/user/#{user_id}/drafts/#{sport}/#{season}")
    end

    # Fetch league details.
    #
    # @param league_id [String] League ID
    # @return [Hash] League metadata
    # @see https://docs.sleeper.com/#get-a-specific-league
    def get_league(league_id)
      make_request("/v1/league/#{league_id}")
    end

    # Get all rosters in a league.
    #
    # @param league_id [String] League ID
    # @return [Array<Hash>] Roster data
    # @see https://docs.sleeper.com/#getting-rosters-in-a-league
    def get_league_rosters(league_id)
      make_request("/v1/league/#{league_id}/rosters")
    end

    # Get all users in a league.
    #
    # @param league_id [String, Integer] League ID
    # @return [Array<Hash>] User data
    # @see https://docs.sleeper.com/#getting-users-in-a-league
    def get_league_users(league_id)
      make_request("/v1/league/#{league_id}/users")
    end

    # Get matchups for a specific week.
    #
    # @param league_id [String, Integer] League ID
    # @param week [Integer] Week number (1-17)
    # @return [Array<Hash>] Matchup data
    # @see https://docs.sleeper.com/#getting-matchups-in-a-league
    def get_league_matchups(league_id, week)
      make_request("/v1/league/#{league_id}/matchups/#{week}")
    end

    # Get playoff winners bracket.
    #
    # @param league_id [String, Integer] League ID
    # @return [Array<Hash>] Bracket matchups
    # @see https://docs.sleeper.com/#getting-the-playoff-bracket
    def get_playoff_bracket(league_id)
      make_request("/v1/league/#{league_id}/winners_bracket")
    end

    # Get toilet bowl (losers bracket).
    #
    # @param league_id [String, Integer] League ID
    # @return [Array<Hash>] Bracket matchups
    # @see https://docs.sleeper.com/#getting-the-playoff-bracket
    def get_toilet_bowl(league_id)
      make_request("/v1/league/#{league_id}/losers_bracket")
    end

    # Get transactions for a specific week.
    #
    # @param league_id [String, Integer] League ID
    # @param week [Integer] Week number
    # @return [Array<Hash>] Transaction data
    # @see https://docs.sleeper.com/#get-transactions
    def get_transactions(league_id, week)
      make_request("/v1/league/#{league_id}/transactions/#{week}")
    end

    # Get league drafts.
    #
    # @param league_id [String, Integer] League ID
    # @return [Array<Hash>] Draft data
    # @see https://docs.sleeper.com/#get-all-drafts-for-a-league
    def get_league_drafts(league_id)
      make_request("/v1/league/#{league_id}/drafts")
    end

    # Get traded draft picks for a league.
    #
    # @param league_id [String, Integer] League ID
    # @return [Array<Hash>] Traded picks
    # @see https://docs.sleeper.com/#get-traded-picks-in-a-draft
    def get_league_traded_picks(league_id)
      make_request("/v1/league/#{league_id}/traded_picks")
    end

    # Fetch draft details.
    #
    # @param draft_id [String, Integer] Draft ID
    # @return [Hash] Draft metadata
    # @see https://docs.sleeper.com/#get-a-specific-draft
    def get_draft(draft_id)
      make_request("/v1/draft/#{draft_id}")
    end

    # Get draft picks.
    #
    # @param draft_id [String, Integer] Draft ID
    # @return [Array<Hash>] Pick data
    # @see https://docs.sleeper.com/#get-all-picks-in-a-draft
    def get_draft_picks(draft_id)
      make_request("/v1/draft/#{draft_id}/picks")
    end

    # Get traded draft picks for a draft.
    #
    # @param draft_id [String, Integer] Draft ID
    # @return [Array<Hash>] Traded picks
    # @see https://docs.sleeper.com/#get-traded-picks-in-a-draft
    def get_draft_traded_picks(draft_id)
      make_request("/v1/draft/#{draft_id}/traded_picks")
    end

    # Get NFL state (week, season status).
    #
    # @param sport [String] Sport code (default: "nfl")
    # @return [Hash] State data
    # @see https://docs.sleeper.com/#get-nfl-state
    def get_nfl_state(sport = "nfl")
      nfl_state = make_request("/v1/state/#{sport}")
      nfl_state.each_with_object({}) do |(k, v), result|
        key = k.is_a?(String) ? k.to_sym : k
        result[key] = v
      end
    end

    # Get per-player statistics for one week, or for a whole season.
    #
    # Undocumented. Returns an object keyed by player id — plus `TEAM_XXX` keys
    # for team-level rows — each holding raw counting stats (`rec`, `rush_yd`,
    # `off_snp`, `rec_rz_tgt`…) alongside Sleeper's three canned point totals
    # `pts_ppr` / `pts_half_ppr` / `pts_std`. 228 distinct fields were observed
    # across one week of 2025.
    #
    # **Nothing here 404s.** An unplayed week, a week out of range, and an
    # unrecognised season type all answer 200 with `{}`, so an empty result is
    # a legitimate answer and is indistinguishable from a typo. Validate the
    # arguments before you trust an empty body.
    #
    # **A week still being played answers with a partial set, and says nothing
    # about being partial.** Mid-week-1 of 2026 this returned 301 rows with
    # only 42 carrying a `pts_ppr` — the two teams whose games had finished or
    # started. A caller that treats "the week's stats" as the whole week gets a
    # half-filled answer for as long as the week is in progress, which for a
    # regular-season week is most of five days. #schedule's per-game `status`
    # is the only thing that can tell a missing row from a scoreless one.
    #
    # Omitting `week` requests season totals, which is a different resource at
    # a shorter path rather than a default of week 1.
    #
    # `pre` and `post` restart week numbering at 1, exactly as #schedule does,
    # so rows from different season types must never be pooled.
    #
    # @param season [Integer, String] Season year, e.g. 2025
    # @param week [Integer, String, nil] Week number, or nil for season totals
    # @param season_type [String] "regular" (default), "pre", or "post"
    # @param sport [String] Sport code (default: "nfl")
    # @return [HTTParty::Response] Player id to stats mapping
    def stats(season, week: nil, season_type: "regular", sport: "nfl")
      make_request(weekly_path("stats", sport, season_type, season, week))
    end

    # Get per-player projections for one week, or for a whole season.
    #
    # Same shape and same caveats as #stats, with one of its own: for a season
    # Sleeper has not projected, this still returns a full set of entries —
    # 9,386 of them for 2030 — every one holding only `{"adp_dd_ppr" => 1000.0}`
    # and no `pts_ppr` at all. **A row count is not evidence of a projection.**
    # Filter on the field you actually want.
    #
    # `adp_dd_ppr` 1000.0 and `pos_rank_*` 999.0 are "unknown" sentinels rather
    # than values.
    #
    # ⚠️ **This is a pre-game, whole-game projection and it does not move while
    # the game is played.** Measured on 2026-09-10 across six hours spanning a
    # kickoff: five players in that night's game held the same `pts_ppr` before
    # it started and while it was in progress, to the decimal. Checked again
    # against a game that had already finished — the projection still read
    # 19.69 for a player who had scored 26.2, so it does not settle onto the
    # final either.
    #
    # That matters because it is the natural thing to reach for and the wrong
    # one: **there is no live projection here**, so nothing in this payload can
    # say whether a player is on pace. A player on 8 points of a projected 12
    # in the first quarter is ahead of schedule, and this endpoint will report
    # 12 all afternoon.
    #
    # @param season [Integer, String] Season year, e.g. 2026
    # @param week [Integer, String, nil] Week number, or nil for season totals
    # @param season_type [String] "regular" (default), "pre", or "post"
    # @param sport [String] Sport code (default: "nfl")
    # @return [HTTParty::Response] Player id to projections mapping
    def projections(season, week: nil, season_type: "regular", sport: "nfl")
      make_request(weekly_path("projections", sport, season_type, season, week))
    end

    # Get one week's stat lines **with the context of the week they were played
    # in** — the player's team *that week*, their opponent, the game and its
    # date. Probed 2026-09-08, re-probed 2026-09-14.
    #
    # ⚠️ **A different host: `api.sleeper.com`, not `api.sleeper.app`.** The
    # `.app` endpoint #stats calls returns the *same stat lines with none of
    # this metadata*, which is why it can be there for years without anyone
    # finding it. Same sport and season in the path, but no `/v1` and the
    # season type is a query parameter rather than a segment.
    #
    # **What is genuinely per-week, measured** over the 2,275 players present in
    # both week 1 and week 16 of 2021: `team` differs on **164** of them (a
    # midseason trade is a real change of team) and `opponent` on **2,262**. So
    # both are history rather than today's catalog.
    #
    # ⚠️ **The nested `player` object is NOT history.** It is the current
    # catalog record stapled on — `player.team` is null inside it, and
    # `injury_status` differed on 1 of the 204 rows carrying one across fifteen
    # weeks, which is the signature of a field that does not vary by week at
    # all. A 2021 row reporting "Questionable" is reporting that he is
    # questionable *now*. The top-level `status` is null on every row seen.
    #
    # ⚠️ **Pass a week.** Dropping it answers season totals — 8,251 rows for
    # 2021 — with `week` and `opponent` null on every one, so the season form
    # carries none of the context this endpoint exists for.
    #
    # Shares #stats' traps: nothing 404s (an unplayed 2026 week, a week out of
    # range, a season before Sleeper's history and a garbage season type all
    # answer `200` with `[]`), and `pre`/`post` restart week numbering — 2021
    # `post` week 1 is the wildcard round, played 2022-01-15.
    #
    # **An array, not a hash.** #stats keys by player id; this returns a list of
    # rows each carrying `player_id`, so a caller indexing it must build its own
    # map. `/projections/nfl/{season}/{week}` on the same host answers the same
    # shape (9,420 rows for 2021 week 16) and has no wrapper here yet.
    #
    # @param season [Integer, String] Season year, e.g. 2021
    # @param week [Integer, String] Week number — required, see above
    # @param season_type [String] "regular" (default), "pre", or "post"
    # @param sport [String] Sport code (default: "nfl")
    # @return [HTTParty::Response] Array of stat lines, each with `team`,
    #   `opponent`, `game_id`, `date`, `week`, `season` and a nested `player`
    def stats_with_context(season, week, season_type: "regular", sport: "nfl")
      segments = [sport, season, week].map { |segment| ERB::Util.url_encode(segment.to_s) }
      query = ERB::Util.url_encode(season_type.to_s)

      make_request("/stats/#{segments.join("/")}?season_type=#{query}", host: WEB_HOST)
    end

    # Get games with their kickoff times — undocumented, on the web host.
    #
    # **The only kickoff time Sleeper publishes.** #schedule carries a `date`
    # and nothing finer; each game here has `start_time`, epoch milliseconds —
    # 2026's Thursday opener of week 3, ATL @ GB, is 1790295300000, which is
    # 2026-09-25T00:15Z and agrees with `metadata.date_time` on every game.
    # Measured 2026-09-25, the morning after that game.
    #
    # `metadata` is the live game: `quarter`, `time_remaining`, the score by
    # quarter, `is_in_progress`, `is_over`, plus the TV `channel`, the spread and
    # a forecast. Its `status` is a different vocabulary from the top level's —
    # `scheduled`/`closed` against `pre_game`/`complete` — and neither value a
    # live game carries has been read here yet. Match with a fallback.
    #
    # **Leave the week off for the whole season** — all 272 games of 2026 in one
    # call, ~610 KB (~93 KB gzipped), against ~57 KB a week. Unlike
    # #stats_with_context, the season form is useful.
    #
    # The season type is a **path segment**, not a query parameter —
    # `/scores/nfl/2026/3?season_type=regular` answers 200 with nothing. Shares
    # the host's traps: nothing 404s (week 19, a garbage season type all answer
    # `200` with `[]`), and `pre`/`post` restart week numbering.
    #
    # @param season [Integer, String] Season year, e.g. 2026
    # @param week [Integer, String, nil] Week number; nil for the whole season
    # @param season_type [String] "regular" (default), "pre", or "post"
    # @param sport [String] Sport code (default: "nfl")
    # @return [HTTParty::Response] Array of games, each with `game_id`, `week`,
    #   `status`, `start_time`, `date` and a nested `metadata`
    def scores(season, week = nil, season_type: "regular", sport: "nfl")
      segments = [sport, season_type, season, week].compact.map do |segment|
        ERB::Util.url_encode(segment.to_s)
      end

      make_request("/scores/#{segments.join("/")}", host: WEB_HOST)
    end

    # Get a season's game schedule.
    #
    # Undocumented, and served from the host root rather than /v1 — hence the
    # version living in the paths rather than in base_uri.
    #
    # Returns a flat array of games, each `{status, date, home, away, week,
    # game_id}`. A team's bye week is the week it appears in no game; that
    # derives exactly, but only within one season type — `pre` (weeks 1-3) and
    # `post` (weeks 1-4) restart week numbering, so games from different season
    # types must never be pooled.
    #
    # **`status` is `pre_game`, `in_game`, `complete` or `canceled`**, observed
    # across the 2025 and 2026 regular seasons. `in_game` was read off a live
    # game on 2026-09-10; the other three come from the published schedule. It
    # is the only per-game signal of whether a game has been played — there is
    # no kickoff time anywhere in this payload, only `date`, so a caller can
    # know that a game is under way but never how far into it.
    #
    # **A week is not one event, and a caller reasoning from `date` alone will
    # get that wrong.** Week 1 of 2026 held all three live states at the same
    # moment: one `complete`, one `in_game`, fourteen `pre_game`.
    #
    # Treat the four as an open vocabulary. A postponement or a suspension
    # would be a fifth value and none has been seen, so match with a fallback
    # rather than a whitelist.
    #
    # **A team can carry two games in one week.** 2026 lists a canceled DAL/SEA
    # in week 6 that was superseded rather than called off, and both teams play
    # someone else that week. Order by status before picking one, or you will
    # hand a team a bye it does not have.
    #
    # A season Sleeper has not scheduled yet answers 200 with an empty array
    # rather than 404, so an empty result is a legitimate answer and not an
    # error.
    #
    # @param season [Integer, String] Season year, e.g. 2026
    # @param season_type [String] "regular" (default), "pre", or "post"
    # @param sport [String] Sport code (default: "nfl")
    # @return [HTTParty::Response] Array of games
    def schedule(season, season_type: "regular", sport: "nfl")
      make_request("/schedule/#{sport}/#{season_type}/#{season}")
    end

    # Get trending players.
    #
    # @param sport [String] Sport code (default: "nfl")
    # @param type [String] Trend type ("add" or "drop", default: "add")
    # @param lookback_hours [Integer] Hours to look back (default: 24)
    # @param limit [Integer] Max results (default: 25)
    # @return [Array<Hash>] Trending players
    # @see https://docs.sleeper.com/#trending-players
    def trending_players(sport = "nfl", type: "add", lookback_hours: 24, limit: 25)
      make_request("/v1/players/#{sport}/trending/#{type}?lookback_hours=#{lookback_hours}&limit=#{limit}")
    end

    # Get all player data (cached for 24 hours).
    #
    # @param sport [String] Sport code (default: "nfl")
    # @return [Hash{String => Hash}] Player ID to player data mapping
    # @see https://docs.sleeper.com/#fetch-all-players
    def get_players(sport = "nfl")
      return @players_cache if @players_cache && @cache_timestamp && (Time.now - @cache_timestamp) < (3600 * 24)

      response = make_request("/v1/players/#{sport}")
      @players_cache = response.parsed_response
      @cache_timestamp = Time.now

      @players_cache
    end

    # Get a specific player by ID.
    #
    # @param player_id [String] Player ID
    # @param sport [String] Sport code (default: "nfl")
    # @return [Hash, nil] Player data or nil if not found
    # @see #get_players
    def get_player_by_id(player_id, sport = "nfl")
      get_players(sport)[player_id]
    end

    private

    # Path for #stats and #projections. Segments are escaped because they are
    # interpolated into a URI path: an unescaped one can walk out of the
    # endpoint entirely, which is the bug the consuming app had to work around
    # for #get_user.
    #
    # A nil week drops the segment rather than defaulting, because the shorter
    # path is season totals.
    def weekly_path(resource, sport, season_type, season, week)
      segments = [resource, sport, season_type, season, week].compact
      escaped = segments.map { |segment| ERB::Util.url_encode(segment.to_s) }

      "/v1/#{escaped.join("/")}"
    end

    # Make an HTTP request with retry logic and logging.
    #
    # ⚠️ **`host:` cannot be done by passing an absolute URL instead.** HTTParty
    # 0.24 raises `UnsafeURIError` for any URL whose host differs from the
    # configured `base_uri` — "this request could send credentials to an
    # unintended server" — so a second host has to arrive as its own
    # `base_uri`, which is a per-request option it supports.
    #
    # **The error and the log name the host whenever it is not the default.**
    # `/stats/nfl/2021/16` is a real path on both hosts and they return
    # different things, so a message quoting the path alone cannot say which
    # one failed. Paths on the default host quote exactly as they always have.
    #
    # @param path [String] API endpoint path
    # @param host [String, nil] a different host, e.g. WEB_HOST
    # @return [HTTParty::Response]
    # @raise [SleeperApi::Error] On HTTP errors or timeouts
    def make_request(path, host: nil)
      named = host ? "#{host}#{path}" : path
      options = { timeout: @config.timeout }
      options[:base_uri] = host if host

      @config.logger&.info("Making request to #{host || self.class.base_uri}#{path}")
      retries = 0
      begin
        response = self.class.get(path, **options)
        if response.success?
          @config.logger&.info("Successful response for #{named}")
          response
        else
          @config.logger&.error("Failed to fetch #{named}: #{response.code}")
          raise SleeperApi::Error, "Failed to fetch #{named}: #{response.code}"
        end
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        retries += 1
        if retries <= @config.retries
          @config.logger&.warn("Retrying #{named} (attempt #{retries}/#{@config.retries}) due to #{e}")
          sleep(1)
          retry
        else
          @config.logger&.error("Request timed out for #{named} after #{retries} retries")
          raise SleeperApi::Error, "Request timed out after #{retries} retries"
        end
      rescue *CONNECTION_ERRORS => e
        # No retry: these fail at once, and the caller's backoff is the one
        # that can wait long enough to matter.
        @config.logger&.error("Could not reach #{named}: #{e.message}")
        raise SleeperApi::Error, "Could not reach #{named}: #{e.message}"
      end
    end
  end
end
