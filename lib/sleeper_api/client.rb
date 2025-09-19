require "httparty"
require "json"

module SleeperApi
  class Client
    include HTTParty

    base_uri "https://api.sleeper.app/v1"

    def initialize(config)
      @config = config
    end

    def league(league_id)
      League.new(league_id, self)
    end

    def user(identifier)
      User.new(identifier, self)
    end

    def draft(draft_id)
      Draft.new(draft_id, self)
    end

    def get_user(identifier)
      make_request("/user/#{identifier}")
    end

    def get_user_leagues(user_id, sport: "nfl", season: Time.now.year)
      make_request("/user/#{user_id}/leagues/#{sport}/#{season}")
    end

    def get_user_drafts(user_id, sport: "nfl", season: Time.now.year)
      make_request("/user/#{user_id}/drafts/#{sport}/#{season}")
    end

    def get_league(league_id)
      make_request("/league/#{league_id}")
    end

    def get_league_rosters(league_id)
      make_request("/league/#{league_id}/rosters")
    end

    def get_league_users(league_id)
      make_request("/league/#{league_id}/users")
    end

    def get_league_matchups(league_id, week)
      make_request("/league/#{league_id}/matchups/#{week}")
    end

    def get_playoff_bracket(league_id)
      make_request("/league/#{league_id}/winners_bracket")
    end

    def get_toilet_bowl(league_id)
      make_request("/league/#{league_id}/losers_bracket")
    end

    def get_transactions(league_id, week)
      make_request("/league/#{league_id}/transactions/#{week}")
    end

    def get_league_drafts(league_id)
      make_request("/league/#{league_id}/drafts")
    end

    def get_league_traded_picks(league_id)
      make_request("/league/#{league_id}/traded_picks")
    end

    def get_draft(draft_id)
      make_request("/draft/#{draft_id}")
    end

    def get_draft_picks(draft_id)
      make_request("/draft/#{draft_id}/picks")
    end

    def get_draft_traded_picks(draft_id)
      make_request("/draft/#{draft_id}/traded_picks")
    end

    def get_nfl_state(sport = "nfl")
      make_request("/state/#{sport}")
    end

    def trending_players(sport = "nfl", type: "add", lookback_hours: 24, limit: 25)
      make_request("/players/#{sport}/trending/#{type}?lookback_hours=#{lookback_hours}&limit=#{limit}")
    end

    def get_players(sport = "nfl")
      cache = SleeperApi::Cache.new
      cached = cache.read
      return cached if cached

      response = make_request("/players/#{sport}")
      parsed = response.parsed_response
      cache.write(parsed)
      parsed
    end

    def get_player_by_id(player_id, sport = "nfl")
      get_players(sport)[player_id]
    end

    private

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
          @config.logger&.warn("Retrying #{path} (attempt #{retries}/#{config.retries}) due to #{e}")
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
