# frozen_string_literal: true

module SleeperApi
  class User
    include Helpers

    # User attributes from the API.
    ATTRIBUTES = %w[username user_id display_name avatar email cookies created currencies data_updated deleted is_bot
                    metadata notifications pending phone real_name solicitable summoner_name summoner_region token
                    verification].freeze

    attr_reader :identifier

    # @param identifier [String, Integer] Username or user ID
    # @param client [SleeperApi::Client] HTTP client instance
    # @raise [ArgumentError] If identifier is empty
    # @raise [SleeperApi::Error] If user data is invalid
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

    # Dynamically define attribute readers for user data.
    ATTRIBUTES.each do |attr|
      define_method(attr) do
        @user_data[attr]
      end
    end

    # Generate avatar URL from ID.
    #
    # @return [String, nil] Full avatar URL or nil if no avatar
    def avatar_url
      avatar ? "https://sleepercdn.com/avatars/#{avatar}" : nil
    end

    # Get all leagues for a specific season.
    #
    # @param season [Integer] Season year (default: current year)
    # @return [Array<Hash>] Formatted league objects
    # @raise [ArgumentError] If season is not an integer
    def leagues(season = Time.now.year)
      raise ArgumentError, "season must be a valid year" unless season.is_a?(Integer)

      fetch_leagues(season) unless @leagues
    end

    # Get all rosters for this user across all leagues in a season.
    #
    # @param season [Integer] Season year (default: current year)
    # @return [Array<Hash>] Formatted roster objects from all leagues
    # @raise [ArgumentError] If season is not an integer
    def rosters(season = Time.now.year)
      raise ArgumentError, "season must be a valid year" unless season.is_a?(Integer)

      fetch_leagues(season) unless @leagues
      (@leagues || []).flat_map do |league|
        league_instance = League.new(league[:league_id], @client, no_data: true)
        league_instance.rosters(user_id: @user_id)
      end
    end

    # Get all drafts for a specific season with enhanced metadata.
    #
    # @param season [Integer] Season year (default: current year)
    # @return [Array<Hash>] Formatted draft objects with league info
    # @raise [ArgumentError] If season is not an integer
    def drafts(season = Time.now.year)
      raise ArgumentError, "season must be a valid year" unless season.is_a?(Integer)

      fetch_drafts(season) unless @drafts
      format_drafts
    end

    # Get a summary of user's league participation.
    #
    # @param season [Integer] Season year (default: current year)
    # @return [Hash] Summary statistics
    def summary(season = Time.now.year)
      leagues_data = leagues(season)
      rosters_data = rosters(season)

      {
        season: season,
        total_leagues: leagues_data.length,
        winning_record: rosters_data.select { |r| r[:wins] > r[:losses] },
        total_wins: rosters_data.sum { |r| r[:wins] },
        total_losses: rosters_data.sum { |r| r[:losses] },
        total_ties: rosters_data.sum { |r| r[:ties] },
        avg_record: if rosters_data.any?
                      {
                        wins: rosters_data.sum { |r| r[:wins].to_f } / rosters_data.length,
                        losses: rosters_data.sum { |r| r[:losses].to_f } / rosters_data.length,
                        ties: rosters_data.sum { |r| r[:ties].to_f } / rosters_data.length
                      }
                    end,
        best_team: rosters_data.max_by { |r| r[:wins].to_i - r[:losses].to_i },
        worst_team: rosters_data.min_by { |r| r[:wins].to_i - r[:losses].to_i }
      }
    end

    private

    def fetch_user_data
      @user_data ||= @client.get_user(@identifier)
    end

    def fetch_leagues(season)
      @leagues ||= (@client.get_user_leagues(@user_id, season: season) || []).map do |league|
        deep_symbolize_keys(league)
      end
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
