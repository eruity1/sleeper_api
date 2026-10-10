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
    # @raise [SleeperApi::UserNotFound] If no user has that identifier
    def initialize(identifier, client)
      raise ArgumentError, "identifier must be a non-empty string" if identifier.to_s.empty?

      @identifier = identifier
      @client = client
      @user_data = nil
      # Keyed by season: one instance is asked about several seasons, and a
      # single memo answered every later season with the first one's data.
      @leagues = {}
      @drafts = {}

      fetch_user_data
      @user_id = @user_data["user_id"] || raise(SleeperApi::UserNotFound, "Invalid user data: user_id not found")
    end

    # Dynamically define attribute readers for user data.
    ATTRIBUTES.each do |attr|
      define_method(attr) do
        @user_data[attr]
      end
    end

    # Generate avatar URL from ID.
    #
    # The full size was 2.2 MB of `application/octet-stream` and the thumbnail
    # 19 KB of PNG, measured 2026-10-09; a list of avatars wants the thumbnail.
    #
    # @param thumb [Boolean] The thumbnail instead of the full-size image
    # @return [String, nil] Avatar URL or nil if no avatar
    def avatar_url(thumb: false)
      return nil unless avatar

      thumb ? "https://sleepercdn.com/avatars/thumbs/#{avatar}" : "https://sleepercdn.com/avatars/#{avatar}"
    end

    # Get all leagues for a specific season.
    #
    # @param season [Integer] Season year (default: current year)
    # @param sport [String] Sport code (default: "nfl"). An unknown one answers
    #   200 with [] (measured 2026-10-09), so a typo reads as "no leagues".
    # @return [Array<Hash>] Formatted league objects
    # @raise [ArgumentError] If season is not an integer
    def leagues(season = Time.now.year, sport: "nfl")
      raise ArgumentError, "season must be a valid year" unless season.is_a?(Integer)

      fetch_leagues(season, sport)
    end

    # Get all rosters for this user across all leagues in a season.
    #
    # @param season [Integer] Season year (default: current year)
    # @param sport [String] Sport code (default: "nfl")
    # @return [Array<Hash>] Formatted roster objects from all leagues
    # @raise [ArgumentError] If season is not an integer
    def rosters(season = Time.now.year, sport: "nfl")
      raise ArgumentError, "season must be a valid year" unless season.is_a?(Integer)

      fetch_leagues(season, sport).flat_map do |league|
        league_instance = League.new(league[:league_id], @client, no_data: true)
        league_instance.rosters(user_id: @user_id)
      end
    end

    # Get all drafts for a specific season with enhanced metadata.
    #
    # @param season [Integer] Season year (default: current year)
    # @param sport [String] Sport code (default: "nfl")
    # @return [Array<Hash>] Formatted draft objects with league info
    # @raise [ArgumentError] If season is not an integer
    def drafts(season = Time.now.year, sport: "nfl")
      raise ArgumentError, "season must be a valid year" unless season.is_a?(Integer)

      format_drafts(fetch_drafts(season, sport))
    end

    # Get a summary of user's league participation.
    #
    # @param season [Integer] Season year (default: current year)
    # @param sport [String] Sport code (default: "nfl")
    # @return [Hash] Summary statistics
    def summary(season = Time.now.year, sport: "nfl")
      leagues_data = leagues(season, sport: sport)
      rosters_data = rosters(season, sport: sport)

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

    # Keyed on the sport too, or one sport's answer would serve the other's.
    def fetch_leagues(season, sport)
      @leagues[[sport, season]] ||= (@client.get_user_leagues(@user_id, sport: sport, season: season) || []).map do |league|
        deep_symbolize_keys(league)
      end
    end

    def fetch_drafts(season, sport)
      @drafts[[sport, season]] ||= (@client.get_user_drafts(@user_id, sport: sport, season: season) || []).map do |draft|
        deep_symbolize_keys(draft)
      end
    end

    def format_drafts(drafts)
      drafts.map do |draft|
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
