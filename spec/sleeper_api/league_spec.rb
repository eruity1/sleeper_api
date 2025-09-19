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
end
