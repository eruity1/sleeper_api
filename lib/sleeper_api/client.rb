require "httparty"
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
    # @param season [Integer, String] Season year, e.g. 2026
    # @param week [Integer, String, nil] Week number, or nil for season totals
    # @param season_type [String] "regular" (default), "pre", or "post"
    # @param sport [String] Sport code (default: "nfl")
    # @return [HTTParty::Response] Player id to projections mapping
    def projections(season, week: nil, season_type: "regular", sport: "nfl")
      make_request(weekly_path("projections", sport, season_type, season, week))
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
    # @param path [String] API endpoint path
    # @return [HTTParty::Response]
    # @raise [SleeperApi::Error] On HTTP errors or timeouts
    def make_request(path)
      @config.logger&.info("Making request to #{self.class.base_uri}#{path}")
      retries = 0
      begin
        response = self.class.get(path, timeout: @config.timeout)
        if response.success?
          @config.logger&.info("Successful response for #{path}")
          response
        else
          @config.logger&.error("Failed to fetch #{path}: #{response.code}")
          raise SleeperApi::Error, "Failed to fetch #{path}: #{response.code}"
        end
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        retries += 1
        if retries <= @config.retries
          @config.logger&.warn("Retrying #{path} (attempt #{retries}/#{@config.retries}) due to #{e}")
          sleep(1)
          retry
        else
          @config.logger&.error("Request timed out for #{path} after #{retries} retries")
          raise SleeperApi::Error, "Request timed out after #{retries} retries"
        end
      end
    end
  end
end
