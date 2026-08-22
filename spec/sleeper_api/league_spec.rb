require "spec_helper"

RSpec.describe SleeperApi::League do
  let(:client) { instance_double(SleeperApi::Client) }
  let(:league_id) { "12345" }
  let(:league_data) do
    {
      "name" => "Test League",
      "league_id" => league_id,
      "total_rosters" => 12,
      "status" => "in_season",
      "sport" => "nfl",
      "settings" => {},
      "season_type" => "regular",
      "season" => "2024",
      "scoring_settings" => {},
      "roster_positions" => %w[QB RB WR TE FLEX],
      "metadata" => { "latest_league_winner_roster_id" => "1" }
    }
  end

  let(:rosters_data) { [{ "roster_id" => 1, "owner_id" => "user1" }] }
  let(:users_data) { [{ "user_id" => "user1", "display_name" => "Test User" }] }

  before do
    allow(client).to receive_messages(
      get_league: league_data,
      get_league_rosters: rosters_data,
      get_league_users: users_data
    )
  end

  describe "#initialize" do
    context "with valid league_id" do
      it "sets league_id" do
        league = described_class.new(league_id, client)
        expect(league.league_id).to eq(league_id)
      end

      it "sets default weeks range" do
        league = described_class.new(league_id, client)
        expect(league.weeks).to eq(1..17)
      end

      it "fetches league data by default" do
        described_class.new(league_id, client)
        expect(client).to have_received(:get_league)
      end
    end

    context "with no_data flag" do
      it "does not fetch league data" do
        described_class.new(league_id, client, no_data: true)
        expect(client).not_to have_received(:get_league)
      end
    end

    context "with invalid league_id" do
      it "raises ArgumentError for empty string" do
        expect { described_class.new("", client) }.to raise_error(ArgumentError,
                                                                  "league_id must be a non-empty string")
      end

      it "raises ArgumentError for nil" do
        expect { described_class.new(nil, client) }.to raise_error(ArgumentError,
                                                                   "league_id must be a non-empty string")
      end
    end
  end

  describe "dynamic attributes" do
    let(:league) { described_class.new(league_id, client) }

    it "responds to league attributes" do
      expect(league.name).to eq("Test League")
      expect(league.total_rosters).to eq(12)
      expect(league.status).to eq("in_season")
      expect(league.sport).to eq("nfl")
    end

    it "returns nil for missing attributes" do
      allow(client).to receive(:get_league).and_return({})

      league = described_class.new(league_id, client)
      expect(league.name).to be_nil
    end
  end

  describe "#avatar_url" do
    let(:league) { described_class.new(league_id, client) }

    context "when avatar is present" do
      let(:league_data) { super().merge("avatar" => "test-avatar-id") }

      it "returns the full avatar URL" do
        expect(league.avatar_url).to eq("https://sleepercdn.com/avatars/test-avatar-id")
      end
    end

    context "when avatar is nil" do
      let(:league_data) { super().merge("avatar" => nil) }

      it "returns nil" do
        expect(league.avatar_url).to be_nil
      end
    end
  end

  describe "#reigning_champ" do
    let(:league) { described_class.new(league_id, client) }

    context "when winner roster exists" do
      let(:rosters_data) { { "roster_id" => 1, "owner_id" => "user1", "wins" => 10 } }

      it "returns the winning roster" do
        allow(league).to receive(:rosters).and_return(rosters_data)
        expect(league.reigning_champ).to eq(rosters_data)
      end
    end

    context "when no winner roster exists" do
      let(:league_data) { super().merge("metadata" => {}) }

      it "returns nil" do
        expect(league.reigning_champ).to be_nil
      end
    end
  end

  describe "#league_rosters" do
    let(:league) { described_class.new(league_id, client, no_data: true) }

    it "fetches rosters on first call" do
      expect(league.league_rosters).to eq(rosters_data)
      expect(client).to have_received(:get_league_rosters)
    end

    it "caches rosters for subsequent calls" do
      league.league_rosters
      league.league_rosters

      expect(client).to have_received(:get_league_rosters).once
    end
  end

  describe "#league_users" do
    let(:league) { described_class.new(league_id, client, no_data: true) }

    it "fetches users on first call" do
      expect(league.league_users).to eq(users_data)
      expect(client).to have_received(:get_league_users)
    end

    it "caches users for subsequent calls" do
      league.league_users
      league.league_users

      expect(client).to have_received(:get_league_users).once
    end
  end

  describe "#users" do
    let(:league) { described_class.new(league_id, client, no_data: true) }

    it "returns formatted users" do
      expect(league.users.first).to include(user_id: "user1", display_name: "Test User")
    end

    it "returns the same data when called more than once" do
      first = league.users
      expect(league.users).to eq(first)
    end

    it "fetches from the client only once" do
      league.users
      league.users
      expect(client).to have_received(:get_league_users).once
    end

    context "when a user has no metadata" do
      let(:users_data) { [{ "user_id" => "user1", "display_name" => "Test User" }] }

      it "does not raise and leaves team_name nil" do
        expect(league.users.first[:team_name]).to be_nil
      end
    end

    context "when a user has metadata" do
      let(:users_data) do
        [{ "user_id" => "user1", "display_name" => "Test User", "metadata" => { "team_name" => "Squad" } }]
      end

      it "extracts the team name" do
        expect(league.users.first[:team_name]).to eq("Squad")
      end
    end
  end

  describe "#rosters" do
    let(:league) { described_class.new(league_id, client) }
    let(:league_data) { super().merge("settings" => { "waiver_budget" => 100 }) }
    let(:rosters_data) do
      [
        {
          "roster_id" => 1,
          "league_id" => league_id,
          "owner_id" => "user1",
          "starters" => %w[p1 p2],
          "players" => %w[p1 p2 p3 p4 p5],
          "reserve" => %w[p4],
          "taxi" => %w[p5],
          "metadata" => { "streak" => "3W" },
          "settings" => {
            "fpts" => 120, "wins" => 8, "losses" => 4, "ties" => 1,
            "waiver_budget_used" => 25, "waiver_position" => 3
          }
        },
        { "roster_id" => 2, "owner_id" => "orphan", "starters" => [], "players" => [], "settings" => {} }
      ]
    end
    let(:users_data) do
      [{ "user_id" => "user1", "display_name" => "Test User",
         "metadata" => { "team_name" => "Squad", "avatar" => "a1" } }]
    end

    it "returns every roster by default" do
      expect(league.rosters.length).to eq(2)
    end

    it "maps owner and team details from league users" do
      roster = league.rosters.first
      expect(roster).to include(
        roster_id: 1, owner_id: "user1", owner_display_name: "Test User",
        team_name: "Squad", team_icon: "a1"
      )
    end

    it "computes bench as players minus starters, reserve and taxi" do
      expect(league.rosters.first[:bench]).to eq(["p3"])
    end

    it "surfaces record and points from roster settings" do
      expect(league.rosters.first).to include(wins: 8, losses: 4, ties: 1, total_points: 120)
    end

    # Sleeper splits a score across two integer fields: fpts 1617 with
    # fpts_decimal 78 is 1617.78. Reading fpts alone truncates every score in
    # the league, and the loss is invisible because the result is still a
    # plausible number.
    it "combines fpts with fpts_decimal into a real score" do
      rosters_data.first["settings"].merge!("fpts" => 1617, "fpts_decimal" => 78)

      expect(league.rosters.first[:total_points]).to eq(1617.78)
    end

    it "combines fpts_against with fpts_against_decimal" do
      rosters_data.first["settings"].merge!("fpts_against" => 1670, "fpts_against_decimal" => 32)

      expect(league.rosters.first[:points_against]).to eq(1670.32)
    end

    it "treats a missing decimal half as zero rather than dropping the score" do
      rosters_data.first["settings"].merge!("fpts" => 99, "fpts_against" => 88)
      rosters_data.first["settings"].delete("fpts_decimal")

      roster = league.rosters.first
      expect(roster[:total_points]).to eq(99)
      expect(roster[:points_against]).to eq(88)
    end

    it "leaves points nil when the roster has no settings at all" do
      orphan = league.rosters.last

      expect(orphan[:total_points]).to be_nil
      expect(orphan[:points_against]).to be_nil
    end

    # Sleeper's documented roster object carries no co-owner field, but the
    # docs are demonstrably partial (the league settings object is rendered as
    # "{ settings object }"), so this reads the plural spelling the API would
    # use and yields nil when it is absent. It previously read "co_owner",
    # singular, which no payload has ever contained.
    it "reads co-owners under the plural key the API uses" do
      rosters_data.first["co_owners"] = %w[user2 user3]

      expect(league.rosters.first[:co_owners]).to eq(%w[user2 user3])
    end

    it "yields nil co-owners when the field is absent" do
      expect(league.rosters.first[:co_owners]).to be_nil
    end

    it "computes remaining faab from the league waiver budget" do
      expect(league.rosters.first).to include(remaining_faab: 75, faab_used: 25, waiver_position: 3)
    end

    it "reads the streak from roster metadata" do
      expect(league.rosters.first[:streak]).to eq("3W")
    end

    it "symbolizes nested metadata and settings keys" do
      roster = league.rosters.first
      expect(roster[:metadata]).to eq({ streak: "3W" })
      expect(roster[:settings]).to include(wins: 8)
    end

    it "falls back to Unknown when the owner is not in league users" do
      orphan = league.rosters.last
      expect(orphan).to include(owner_display_name: "Unknown", team_name: "Unknown")
    end

    it "gives a roster that has spent nothing the full budget" do
      expect(league.rosters.last[:remaining_faab]).to eq(100)
    end

    context "when the league has no waiver budget configured" do
      let(:league_data) { super().merge("settings" => {}) }

      it "treats the budget as zero" do
        expect(league.rosters.first[:remaining_faab]).to eq(-25)
      end
    end

    it "filters by roster_id" do
      expect(league.rosters(roster_id: 1).map { |r| r[:roster_id] }).to eq([1])
    end

    it "filters by user_id" do
      expect(league.rosters(user_id: "user1").map { |r| r[:owner_id] }).to eq(["user1"])
    end
  end

  describe "#matchups_by_week" do
    let(:league) { described_class.new(league_id, client) }
    let(:matchups_data) do
      [
        {
          "matchup_id" => 1, "roster_id" => 1, "points" => 110.5, "custom_points" => nil,
          "starters" => %w[p1 p2], "players" => %w[p1 p2 p3],
          "players_points" => { "p1" => 20.0, "p2" => 15.5, "p3" => 5.0 }
        },
        {
          "matchup_id" => 1, "roster_id" => 2, "points" => 95.0, "custom_points" => 2.5,
          "starters" => %w[p4], "players" => %w[p4 p5],
          "players_points" => { "p4" => 30.0, "p5" => 1.0 }
        }
      ]
    end

    before { allow(client).to receive(:get_league_matchups).and_return(matchups_data) }

    it "groups entries by matchup_id" do
      result = league.matchups_by_week(week: 3)
      expect(result.length).to eq(1)
      expect(result.first[:matchup_id]).to eq(1)
      expect(result.first[:rosters].length).to eq(2)
    end

    it "requests the given week" do
      league.matchups_by_week(week: 3)
      expect(client).to have_received(:get_league_matchups).with(league_id, 3)
    end

    it "adds custom points into the total" do
      rosters = league.matchups_by_week(week: 3).first[:rosters]
      expect(rosters.first[:total_points]).to eq(110.5)
      expect(rosters.last[:total_points]).to eq(97.5)
    end

    it "splits starter and bench points" do
      roster = league.matchups_by_week(week: 3).first[:rosters].first
      expect(roster[:bench]).to eq(["p3"])
      expect(roster[:starter_points]).to eq([{ "p1" => 20.0 }, { "p2" => 15.5 }])
      expect(roster[:bench_points]).to eq([{ "p3" => 5.0 }])
    end

    it "caches the week rather than refetching" do
      league.matchups_by_week(week: 3)
      league.matchups_by_week(week: 3)
      expect(client).to have_received(:get_league_matchups).once
    end

    it "skips entries with no matchup_id instead of returning nil" do
      allow(client).to receive(:get_league_matchups).and_return(
        [{ "matchup_id" => nil, "roster_id" => 9, "points" => 0, "starters" => [], "players" => [] },
         *matchups_data]
      )

      result = league.matchups_by_week(week: 3)

      expect(result).not_to include(nil)
      expect(result.length).to eq(1)
    end

    it "tolerates a roster with no players or points" do
      allow(client).to receive(:get_league_matchups).and_return(
        [{ "matchup_id" => 1, "roster_id" => 1, "starters" => nil, "players" => nil }]
      )

      roster = league.matchups_by_week(week: 3).first[:rosters].first

      expect(roster).to include(starters: [], bench: [], total_points: 0)
    end

    it "returns an empty array when the week has no matchups" do
      allow(client).to receive(:get_league_matchups).and_return([])
      expect(league.matchups_by_week(week: 3)).to eq([])
    end

    it "raises ArgumentError for a week outside 1..17" do
      expect { league.matchups_by_week(week: 0) }.to raise_error(ArgumentError, "Week must be between 1 and 17")
      expect { league.matchups_by_week(week: 18) }.to raise_error(ArgumentError, "Week must be between 1 and 17")
    end

    it "raises ArgumentError when no week is given" do
      expect { league.matchups_by_week }.to raise_error(ArgumentError, "Week must be between 1 and 17")
    end
  end

  describe "#matchups" do
    let(:league) { described_class.new(league_id, client) }

    before { allow(client).to receive(:get_league_matchups).and_return([]) }

    it "fetches every week in the range" do
      expect(league.matchups.keys).to eq((1..17).to_a)
      expect(client).to have_received(:get_league_matchups).exactly(17).times
    end
  end

  describe "#transactions" do
    let(:league) { described_class.new(league_id, client) }
    let(:transactions_data) do
      [
        {
          "transaction_id" => "t1", "status" => "complete", "type" => "waiver",
          "created" => 1_700_000_000, "status_updated" => 1_700_000_100,
          "roster_ids" => [1], "creator" => "user1",
          "adds" => { "p1" => 1 }, "drops" => { "p2" => 1 },
          "settings" => { "waiver_bid" => 17, "seq" => 2 },
          "metadata" => { "notes" => "ok" },
          "draft_picks" => [{ "season" => "2025", "round" => 2, "owner_id" => 1, "previous_owner_id" => 2 }],
          "waiver_budget" => [{ "amount" => 5, "receiver" => 1, "sender" => 2 }]
        }
      ]
    end

    before { allow(client).to receive(:get_transactions).and_return(transactions_data) }

    it "flattens adds and drops into player/roster pairs" do
      tx = league.transactions(week: 3).first
      expect(tx[:adds]).to eq([{ player_id: "p1", roster_id: 1 }])
      expect(tx[:drops]).to eq([{ player_id: "p2", roster_id: 1 }])
    end

    it "surfaces waiver bid and order from settings" do
      tx = league.transactions(week: 3).first
      expect(tx).to include(waiver_bid: 17, waiver_order: 2, week: 3, type: "waiver")
    end

    it "maps traded draft picks" do
      expect(league.transactions(week: 3).first[:draft_picks]).to eq(
        [{ season: "2025", round: 2, original_roster_id: 1, previous_roster_id: 2, new_roster_id: 1 }]
      )
    end

    it "maps faab transfers" do
      expect(league.transactions(week: 3).first[:waiver_budget]).to eq(
        [{ amount: 5, receiving_roster: 1, sending_roster: 2 }]
      )
    end

    it "defaults collections to empty arrays when absent" do
      allow(client).to receive(:get_transactions).and_return([{ "transaction_id" => "t2" }])
      tx = league.transactions(week: 3).first
      expect(tx[:adds]).to eq([])
      expect(tx[:drops]).to eq([])
      expect(tx[:draft_picks]).to eq([])
      expect(tx[:waiver_budget]).to eq([])
    end

    it "caches the week rather than refetching" do
      league.transactions(week: 3)
      league.transactions(week: 3)
      expect(client).to have_received(:get_transactions).once
    end

    it "raises ArgumentError for a week outside 1..17" do
      expect { league.transactions(week: 99) }.to raise_error(ArgumentError, "Week must be between 1 and 17")
    end
  end

  describe "playoff brackets" do
    let(:league) { described_class.new(league_id, client) }
    let(:rosters_data) do
      [
        { "roster_id" => 1, "owner_id" => "user1", "starters" => [], "players" => [], "settings" => {} },
        { "roster_id" => 2, "owner_id" => "user2", "starters" => [], "players" => [], "settings" => {} }
      ]
    end
    let(:users_data) do
      [
        { "user_id" => "user1", "display_name" => "One", "metadata" => { "team_name" => "Team One" } },
        { "user_id" => "user2", "display_name" => "Two", "metadata" => { "team_name" => "Team Two" } }
      ]
    end
    let(:bracket_data) { [{ "r" => 1, "m" => 1, "t1" => 1, "t2" => 2, "w" => 1, "l" => 2 }] }
    let(:bracket_response) { instance_double(HTTParty::Response, parsed_response: bracket_data) }

    describe "#playoff_bracket" do
      before { allow(client).to receive(:get_playoff_bracket).and_return(bracket_response) }

      it "annotates each matchup with team names" do
        matchup = league.playoff_bracket.first
        expect(matchup).to include(
          team1_owner: "Team One", team2_owner: "Team Two",
          winner_owner: "Team One", loser_owner: "Team Two"
        )
      end

      it "preserves the raw bracket fields as symbols" do
        expect(league.playoff_bracket.first).to include(r: 1, m: 1, t1: 1, t2: 2)
      end

      it "leaves winner and loser nil while the matchup is unplayed" do
        allow(client).to receive(:get_playoff_bracket).and_return(
          instance_double(HTTParty::Response, parsed_response: [{ "r" => 1, "t1" => 1, "t2" => 2 }])
        )
        expect(league.playoff_bracket.first).to include(winner_owner: nil, loser_owner: nil)
      end

      it "caches the bracket" do
        league.playoff_bracket
        league.playoff_bracket
        expect(client).to have_received(:get_playoff_bracket).once
      end
    end

    describe "#toilet_bowl" do
      before { allow(client).to receive(:get_toilet_bowl).and_return(bracket_response) }

      it "annotates each matchup with team names" do
        expect(league.toilet_bowl.first).to include(team1_owner: "Team One", winner_owner: "Team One")
      end

      it "caches the bracket" do
        league.toilet_bowl
        league.toilet_bowl
        expect(client).to have_received(:get_toilet_bowl).once
      end
    end
  end
end
