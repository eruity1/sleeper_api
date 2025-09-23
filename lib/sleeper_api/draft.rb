# frozen_string_literal: true

module SleeperApi
  class Draft
    include Helpers

    # Draft attributes from the API.
    ATTRIBUTES = %w[draft_id created creators draft_order last_message_id last_message_time last_picked league_id
                    settings season season_type metadata slot_to_roster_id sport start_time status type].freeze

    attr_reader :draft_id

    # @param draft_id [String] Draft identifier
    # @param client [SleeperApi::Client] HTTP client instance
    # @raise [ArgumentError] If draft_id is empty
    def initialize(draft_id, client)
      raise ArgumentError, "draft_id must be a non-empty string" if draft_id.to_s.empty?

      @draft_id = draft_id
      @client = client
      @draft_data = nil
      @picks = nil
      @traded_picks = nil

      fetch_draft_data
    end

    # Dynamically define attribute readers for draft data.
    ATTRIBUTES.each do |attr|
      define_method(attr) do
        @draft_data[attr]
      end
    end

    # Get all draft picks with optional filtering.
    #
    # @param round [Integer, nil] Filter by round number
    # @param roster_id [Integer, nil] Filter by team/roster
    # @return [Array<Hash>] Formatted pick objects
    def picks(round: nil, roster_id: nil)
      fetch_picks unless @picks
      picks = @picks
      picks = picks.select { |pick| pick[:round] == round } if round
      picks = picks.select { |pick| pick[:roster_id] == roster_id } if roster_id
      picks
    end

    # Get traded draft picks with optional filtering.
    #
    # @param original_owner_id [Integer, nil] Filter by original team
    # @param previous_owner_id [Integer, nil] Filter by previous owner
    # @param current_owner_id [Integer, nil] Filter by current owner
    # @return [Array<Hash>] Formatted traded pick objects
    def traded_picks(original_owner_id: nil, previous_owner_id: nil, current_owner_id: nil)
      fetch_traded_picks unless @traded_picks
      traded_picks = @traded_picks
      traded_picks = traded_picks.select { |pick| pick[:roster_id] == original_owner_id } if original_owner_id
      traded_picks = traded_picks.select { |pick| pick[:previous_owner_id] == previous_owner_id } if previous_owner_id
      traded_picks = traded_picks.select { |pick| pick[:owner_id] == current_owner_id } if current_owner_id
      traded_picks
    end

    # Get the associated league for this draft.
    #
    # @return [SleeperApi::League] League object
    def league
      @client.league(league_id)
    end

    # Find who picked a specific player.
    #
    # @param player_id [String, Integer] Player ID
    # @return [Hash] User data for the picker, or nil if player not drafted
    def picked_by(player_id)
      fetch_picks unless @picks
      pick = @picks.find { |pick| pick[:player_id] == player_id }
      return nil unless pick

      league_users = league.users
      league_users.find { |user| user[:user_id] == pick[:picked_by] }
    end

    # Calculate the next pick for a live draft.
    #
    # @return [Hash, nil] Next pick details or nil if draft is complete
    def next_pick
      return nil if status == "complete"

      teams_count = settings["teams"]
      last_pick_no = picks.map { |pick| pick[:pick_no] }.max || 0
      {
        pick_no: last_pick_no + 1,
        round: ((last_pick_no / (teams_count || 12)) + 1).to_i,
        draft_slot: ((last_pick_no % (teams_count || 12)) + 1)
      }
    end

    # Get a high-level draft summary.
    #
    # @return [Hash] Summary with top picks and stats
    def summary
      fetch_picks unless @picks
      {
        draft_id: draft_id,
        type: type,
        season: season,
        total_picks: picks.length,
        total_rounds: settings["rounds"] || 0,
        top_picks: picks.select { |pick| pick[:round] == 1 }.map do |pick|
          {
            player_id: pick[:player_id],
            player_name: "#{pick[:metadata][:first_name]} #{pick[:metadata][:last_name]}",
            position: pick[:metadata][:position],
            picked_by: pick[:picked_by]
          }
        end
      }
    end

    # Get picks grouped by round.
    #
    # @return [Hash{Integer => Array<Hash>}] Round number to picks mapping
    def rounds
      fetch_picks unless @picks
      @picks.group_by { |pick| pick[:round] }
    end

    # Get picks grouped by team/roster.
    #
    # @return [Hash{Integer => Array<Hash>}] Roster ID to picks mapping
    def team_picks
      fetch_picks unless @picks
      @picks.group_by { |pick| pick[:roster_id] }
    end

    private

    def fetch_draft_data
      @draft_data ||= @client.get_draft(@draft_id)
    end

    def fetch_picks
      @picks ||= (@client.get_draft_picks(@draft_id) || []).map { |pick| deep_symbolize_keys(pick) }
    end

    def fetch_traded_picks
      @traded_picks ||= (@client.get_draft_traded_picks(@draft_id) || []).map { |pick| deep_symbolize_keys(pick) }
    end
  end
end
