module SleeperApi
  class User
    include Helpers

    ATTRIBUTES = %w[username user_id display_name avatar email cookies created currencies data_updated deleted is_bot metadata notifications pending phone real_name solicitable summoner_name summoner_region token verification].freeze

    attr_reader :identifier, :leagues, :drafts

    def initialize(identifier, client)
      raise ArgumentError, "identifier must be a non-empty string" if identifier.to_s.empty?

      @identifier = identifier
      @client = client
      @user_data = nil
      @leagues = nil
      @drafts = nil

      fetch_user_data
      @user_id = @user_data["user_id"] || raise(SleeperApi::Error, "Invalid user data: user_id not found")
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
      raise ArgumentError, "season must be a valid year" unless season.is_a?(Integer)

      fetch_leagues(season) unless @leagues
    end

    def rosters(season = Time.now.year)
      raise ArgumentError, "season must be a valid year" unless season.is_a?(Integer)

      fetch_leagues(season) unless @leagues
      (@leagues || []).map do |league|
        league_instance = League.new(league[:league_id], @client, no_data: true)
        league_instance.rosters(user_id: @user_id)
      end
    end

    def drafts(season = Time.now.year)
      raise ArgumentError, "season must be a valid year" unless season.is_a?(Integer)

      fetch_drafts(season) unless @drafts
      format_drafts
    end

    private

    def fetch_user_data
      @user_data ||= @client.get_user(@identifier)
    end

    def fetch_leagues(season)
      @leagues ||= (@client.get_user_leagues(@user_id, season: season) || []).map { |league| deep_symbolize_keys(league) }
    end

    def fetch_drafts(season)
      @drafts ||= (@client.get_user_drafts(@user_id, season: season) || []).map { |draft| deep_symbolize_keys(draft) }
    end

    def format_drafts
      (@drafts || []).map do |draft|
        draft.merge(
          league_name: draft.dig(:metadata, :name),
          scoring_type: draft.dig(:metadata, :scoring_type),
          total_teams: draft.dig(:settings, :teams),
          rounds: draft.dig(:settings, :rounds)
        )
      end
    end
  end
end
