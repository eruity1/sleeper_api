# frozen_string_literal: true

module SleeperApi
  class League
    include Helpers

    ATTRIBUTES = %w[name league_id total_rosters status sport settings season_type season scoring_settings
                    roster_positions previous_league_id draft_id bracket_id bracket_overrides_id loser_bracket_id
                    loser_bracket_overrides_id group_id avatar company_id shard last_message_id last_author_avatar
                    last_author_display_name last_author_id last_author_is_bot last_message_attachment
                    last_message_text_map last_message_time last_pinned_message_id last_read_id metadata].freeze

    attr_reader :league_id, :weeks

    def initialize(league_id, client, no_data: false)
      raise ArgumentError, "league_id must be a non-empty string" if league_id.to_s.empty?

      @league_id = league_id
      @client = client
      @weeks = 1..17
      @league_data = nil
      @league_rosters = nil
      @league_users = nil
      @matchups = nil
      @transactions = nil
      @playoff_bracket = nil
      @toilet_bowl = nil

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
      roster_id = @league_data&.dig("metadata", "latest_league_winner_roster_id")
      return nil unless roster_id

      roster_id = roster_id.to_i
      rosters(roster_id: roster_id)
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

      format_rosters(roster_id: roster_id, user_id: user_id)
    end

    def matchups_by_week(week: nil)
      raise ArgumentError, "Week must be between 1 and 17" unless @weeks.include?(week)

      fetch_matchups([week]) unless @matchups&.key?(week)
      format_matchups(week)
    end

    def users
      fetch_users unless @fetch_users
      format_users
    end

    def transactions(week: nil)
      raise ArgumentError, "Week must be between 1 and 17" unless @weeks.include?(week)

      fetch_transactions([week]) unless @transactions&.key?(week)
      format_transactions(week)
    end

    def playoff_bracket
      fetch_playoff_bracket unless @playoff_bracket
      @playoff_bracket
    end

    def toilet_bowl
      fetch_toilet_bowl unless @toilet_bowl
      @toilet_bowl
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

    def fetch_playoff_bracket
      return @playoff_bracket if @playoff_bracket

      response = @client.get_playoff_bracket(@league_id)
      @playoff_bracket = response.parsed_response.map do |matchup|
        deep_symbolize_keys(matchup).merge(
          team1_owner: users.find do |user|
            user[:user_id] == rosters(roster_id: matchup["t1"])&.first&.dig(:owner_id)
          end&.dig(:team_name),
          team2_owner: users.find do |user|
            user[:user_id] == rosters(roster_id: matchup["t2"])&.first&.dig(:owner_id)
          end&.dig(:team_name),
          winner_owner: if matchup["w"]
                          users.find do |user|
                            user[:user_id] == rosters(roster_id: matchup["w"])&.first&.dig(:owner_id)
                          end&.dig(:team_name)
                        end,
          loser_owner: if matchup["l"]
                         users.find do |user|
                           user[:user_id] == rosters(roster_id: matchup["l"])&.first&.dig(:owner_id)
                         end&.dig(:team_name)
                       end
        )
      end
      @playoff_bracket
    end

    def fetch_toilet_bowl
      return @toilet_bowl if @toilet_bowl

      response = @client.get_toilet_bowl(@league_id)
      @toilet_bowl = response.parsed_response.map do |matchup|
        deep_symbolize_keys(matchup).merge(
          team1_owner: users.find do |u|
            u[:user_id] == rosters(roster_id: matchup["t1"])&.first&.dig(:owner_id)
          end&.dig(:team_name),
          team2_owner: users.find do |u|
            u[:user_id] == rosters(roster_id: matchup["t2"])&.first&.dig(:owner_id)
          end&.dig(:team_name),
          winner_owner: if matchup["w"]
                          users.find do |u|
                            u[:user_id] == rosters(roster_id: matchup["w"])&.first&.dig(:owner_id)
                          end&.dig(:team_name)
                        end,
          loser_owner: if matchup["l"]
                         users.find do |u|
                           u[:user_id] == rosters(roster_id: matchup["l"])&.first&.dig(:owner_id)
                         end&.dig(:team_name)
                       end
        )
      end
      @toilet_bowl
    end

    def format_rosters(roster_id: nil, user_id: nil)
      rosters = @league_rosters

      rosters = rosters.select { |roster| roster["roster_id"] == roster_id } if roster_id

      rosters = rosters.select { |roster| roster["owner_id"] == user_id } if user_id

      rosters.map do |roster|
        user = @league_users.find { |user| user["user_id"] == roster["owner_id"] }
        roster_metadata = roster["metadata"]
        roster_settings = roster["settings"]

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
          total_points: roster_settings&.dig("fpts"),
          wins: roster_settings&.dig("wins"),
          ties: roster_settings&.dig("ties"),
          losses: roster_settings&.dig("losses"),
          remaining_faab: (@league_data&.dig("settings",
                                             "waiver_budget") || 0) - (roster_settings&.dig("waiver_budget_used") || 0),
          faab_used: roster_settings&.dig("waiver_budget_used"),
          waiver_position: roster_settings&.dig("waiver_position"),
          streak: roster_metadata&.dig("streak"),
          co_owners: roster["co_owner"],
          keepers: roster["keepers"],
          players_map: roster["player_map"],
          players: roster["players"],
          metadata: roster_metadata.is_a?(Hash) ? roster_metadata.transform_keys(&:to_sym) : roster_metadata,
          settings: roster_settings.is_a?(Hash) ? roster_settings.transform_keys(&:to_sym) : roster_settings
        }
      end
    end

    def format_matchups(week)
      week_matchups = @matchups[week] || []
      return [] if week_matchups.empty?

      week_matchups.group_by { |match| match["matchup_id"] }.map do |matchup_id, matchup_entries|
        next unless matchup_id

        {
          matchup_id: matchup_id,
          rosters: matchup_entries.map do |roster|
            starters = roster["starters"]

            bench = roster["players"] - starters
            {
              roster_id: roster["roster_id"],
              points: roster["points"],
              custom_points: roster["custom_points"],
              total_points: roster["points"] + (roster["custom_points"] || 0),
              starters: starters,
              bench: bench,
              starter_points: (starters || []).map do |starter_id|
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

    def format_users
      (@league_users || []).map do |user|
        user_settings = user["settings"]
        user_metadata = user["metadata"]

        {
          user_id: user["user_id"],
          username: user["username"],
          display_name: user["display_name"],
          avatar_id: user["avatar"],
          team_name: user_metadata["team_name"],
          commissioner: user["is_owner"],
          is_bot: user["is_bot"],
          metadata: user_metadata.is_a?(Hash) ? user_metadata.transform_keys(&:to_sym) : user_metadata,
          settings: user_settings.is_a?(Hash) ? user_settings.transform_keys(&:to_sym) : user_settings
        }
      end
    end

    def format_transactions(week)
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

        transaction_metadata = transaction["metadata"]

        {
          week: week,
          transaction_id: transaction["transaction_id"],
          status: transaction["status"],
          type: transaction["type"],
          created_at: transaction["created"],
          status_updated_at: transaction["status_updated"],
          roster_ids: transaction["roster_ids"] || [],
          adds: transaction["adds"]&.map do |player_id, roster_id|
            { player_id: player_id, roster_id: roster_id }
          end || [],
          drops: transaction["drops"]&.map do |player_id, roster_id|
            { player_id: player_id, roster_id: roster_id }
          end || [],
          waiver_bid: transaction["settings"]&.dig("waiver_bid"),
          waiver_order: transaction["settings"]&.dig("seq"),
          draft_picks: draft_picks,
          waiver_budget: waiver_budget,
          metadata: transaction_metadata.is_a?(Hash) ? transaction_metadata.transform_keys(&:to_sym) : transaction_metadata,
          created_by_user_id: transaction["creator"]
        }
      end
    end
  end
end
