module SleeperApi
  class League
    ATTRIBUTES = %w[name league_id total_rosters status sport settings season_type season scoring_settings roster_positions previous_league_id draft_id bracket_id bracket_overrides_id loser_bracket_id loser_bracket_overrides_id group_id avatar company_id shard last_message_id last_author_avatar last_author_display_name last_author_id last_author_is_bot last_message_attachment last_message_text_map last_message_time last_pinned_message_id last_read_id metadata].freeze

    attr_reader :league_id, :weeks, :league_rosters, :league_users, :matchups, :transactions

    def initialize(league_id, client, no_data: false)
      @league_id = league_id
      @client = client
      @weeks = 1..17
      @league_data = nil
      @league_rosters = nil
      @league_users = nil
      @matchups = nil
      @transactions = nil

      fetch_league_data unless no_data
    end

    ATTRIBUTES.each do |attr|
      define_method(attr) do
        @league_data[attr]
      end
    end

    def avatar_url
      avatar ? "https://sleepercdn.com/avatars/#{avatar}" : nil
    end

    def reigning_champ
      puts @league_data&.dig("metadata", "latest_league_winner_roster_id").to_i
      rosters(roster_id: @league_data&.dig("metadata", "latest_league_winner_roster_id").to_i)
    end

    def league_rosters
      fetch_rosters unless @league_rosters
      @league_rosters
    end

    def league_users
      fetch_users unless @league_users
      @league_users
    end

    def matchups
      fetch_matchups unless @matchups&.keys&.sort == @weeks.to_a.sort
      @matchups
    end

    def rosters(roster_id: nil, user_id: nil)
      fetch_rosters unless @league_rosters
      fetch_users unless @league_users

      rosters = roster_id ? @league_rosters.select { |roster| roster["roster_id"] == roster_id } : @league_rosters
  
      return rosters.find { |roster| roster["owner_id"] == user_id } if user_id

      rosters.map do |roster|
        user = @league_users.find { |user| user["user_id"] == roster["owner_id"] }
        {
          roster_id: roster["roster_id"],
          league_id: roster["league_id"],
          owner_id: roster["owner_id"],
          owner_display_name: user&.dig("display_name") || "Unknown",
          team_name: user&.dig("metadata", "team_name") || "Unknown",
          team_icon: user&.dig("metadata", "avatar"),
          starters: roster["starters"] || [],
          injured_reserve: roster["reserve"] || [],
          taxi: roster["taxi"] || [],
          bench: (roster["players"] || []) - (roster["starters"] || []) - (roster["reserve"] || []) - (roster["taxi"] || []),
          total_points: roster["settings"]&.dig("fpts"),
          wins: roster["settings"]&.dig("wins"),
          ties: roster["settings"]&.dig("ties"),
          losses: roster["settings"]&.dig("losses"),
          remaining_faab: (@league_data&.dig("settings", "waiver_budget") || 0) - (roster["settings"]&.dig("waiver_budget_used") || 0),
          faab_used: roster["settings"]&.dig("waiver_budget_used"),
          waiver_position: roster["settings"]&.dig("waiver_position")
        }
      end
    end

    def matchups_by_week(week)
      raise ArgumentError, "Week must be between 1 and 17" unless (@weeks).include?(week)

      fetch_matchups([week]) unless @matchups&.key?(week)
      week_matchups = @matchups[week] || []
      return [] if week_matchups.empty?

      week_matchups.group_by { |match| match["matchup_id"] }.map do |matchup_id, matchup_entries|
        next unless matchup_id

        {
          matchup_id: matchup_id,
          rosters: matchup_entries.map do |roster|
            bench = roster["players"] - roster["starters"]
            { 
              roster_id: roster["roster_id"], 
              points: roster["points"],
              custom_points: roster["custom_points"],
              total_points: roster["points"] + (roster["custom_points"] || 0),
              starters: roster["starters"],
              bench: bench,
              starter_points: (roster["starters"] || []).map do |starter_id|
                { starter_id => roster["players_points"]&.dig(starter_id) || 0 }
              end,
              bench_points: bench.map do |bench_player_id|
                { bench_player_id => roster["players_points"]&.dig(bench_player_id) || 0 }
              end
            } 
          end
        }
      end
    end

    def users
      fetch_users unless @fetch_users

      @league_users.map do |user|
        {
          user_id: user["user_id"],
          username: user["username"],
          display_name: user["display_name"],
          avatar_id: user["avatar"],
          team_name: user["metadata"]["team_name"],
          commissioner: user["is_owner"],
          is_bot: user["is_bot"],
          metadata: user["metadata"].transform_keys(&:to_sym),
          settings: user["settings"].is_a?(Hash) ? user["settings"].transform_keys(&:to_sym) : user["settings"]
        }
      end
    end

    def transactions(week)
      raise ArgumentError, "Week must be between 1 and 17" unless (@weeks).include?(week)
      
      fetch_transactions([week]) unless @transactions&.key?(week)
      (@transactions[week] || []).map do |transaction|
        draft_picks = transaction["draft_picks"]&.map do |pick|
          {
            season: pick["season"],
            round: pick["round"],
            original_roster_id: pick["owner_id"],
            previous_roster_id: pick["previous_owner_id"],
            new_roster_id: pick["owner_id"]
          }
        end || []
        waiver_budget = transaction["waiver_budget"]&.map do |budget|
          {
            amount: budget["amount"],
            receiving_roster: budget["receiver"],
            sending_roster: budget["sender"]
          }
        end || []
        
        {
          week: week,
          transaction_id: transaction["transaction_id"],
          status: transaction["status"],
          type: transaction["type"],
          created_at: transaction["created"],
          status_updated_at: transaction["status_updated"],
          roster_ids: transaction["roster_ids"] || [],
          adds: transaction["adds"]&.map { |player_id, roster_id| { player_id: player_id, roster_id: roster_id } } || [],
          drops: transaction["drops"]&.map { |player_id, roster_id| { player_id: player_id, roster_id: roster_id } } || [],
          waiver_bid: transaction["settings"]&.dig("waiver_bid"),
          waiver_order: transaction["settings"]&.dig("seq"),
          draft_picks: draft_picks,
          waiver_budget: waiver_budget,
          metadata: transaction["metadata"].is_a(Hash) ? transaction["metadata"].transform_keys(&:to_sym) : transaction["metadata"],
          created_by_user_id: transaction["creator"]
        }
      end
    end

    private

    def fetch_league_data
      @league_data ||= @client.get_league(@league_id)
    end

    def fetch_rosters
      @league_rosters ||= @client.get_league_rosters(@league_id)
    end

    def fetch_users
      @league_users ||= @client.get_league_users(@league_id)
    end

    def fetch_matchups(weeks = @weeks)
      @matchups ||= {}
      weeks.each do |week|
        next if @matchups[week]
        @matchups[week] = @client.get_league_matchups(@league_id, week)
      end
    end

    def fetch_transactions(weeks = @weeks)
      @transactions ||= {}
      weeks.each do |week|
        next if @transactions[week]
        @transactions[week] = @client.get_transactions(@league_id, week)
      end
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
