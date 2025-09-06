module SleeperApi
  class User
    ATTRIBUTES = %w[username user_id display_name avatar email cookies created currencies data_updated deleted is_bot metadata notifications pending phone real_name solicitable summoner_name summoner_region token verification].freeze

    attr_reader :identifier, :leagues, :drafts

    def initialize(identifier, client)
      @identifier = identifier
      @client = client
      @user_data = nil
      @leagues = nil
      @drafts = nil

      fetch_user_data
      @user_id = @user_data["user_id"]
    end

    ATTRIBUTES.each do |attr|
      define_method(attr) do
        @user_data[attr]
      end
    end

    def avatar_url
      avatar ? "https://sleepercdn.com/avatars/#{avatar}" : nil
    end

    def leagues(season = Time.now.year)
      fetch_leagues(season) unless @leagues
      @leagues.map { |league|  deep_symbolize_keys(league) }
    end

    def rosters(season = Time.now.year)
      fetch_leagues(season) unless @leagues
      @leagues.map do |league|
        league_instance = League.new(league["league_id"], @client, no_data: true)
        league_instance.rosters(user_id: @user_id)
      end
    end

    def drafts(season = Time.now.year)
      fetch_drafts(season) unless @drafts
      @drafts.map do |draft|
        deep_symbolize_keys(draft).merge(
          league_name: draft.dig("metadata", "name"),
          scoring_type: draft.dig("metadata", "scoring_type"),
          total_teams: draft.dig("settings", "teams"),
          rounds: draft.dig("settings", "rounds"),
        )
      end
    end

    private

    def fetch_user_data
      @user_data ||= @client.get_user(@identifier)
    end

    def fetch_leagues(season)
      @leagues ||= @client.get_user_leagues(@user_id, season: season)
    end

    def fetch_drafts(season)
      @drafts ||= @client.get_user_drafts(@user_id, season: season)
    end

    def deep_symbolize_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), result|
          key = k.is_a?(String) ? k.to_sym : k
          result[key] = deep_symbolize_keys(v)
        end
      when Array
        obj.map { |e| deep_symbolize_keys(e) }
      else
        obj
      end
    end
  end
end
