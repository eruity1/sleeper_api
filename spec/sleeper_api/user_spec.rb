require "spec_helper"

RSpec.describe SleeperApi::User do
  let(:client) { instance_double(SleeperApi::Client) }
  let(:identifier) { "testuser" }
  let(:user_data) do
    {
      "user_id" => "user123",
      "username" => "testuser",
      "display_name" => "Test User",
      "avatar" => "avatar123",
      "email" => "test@example.com",
      "metadata" => { "team_name" => "Test Team" }
    }
  end

  let(:leagues_data) do
    [
      {
        "league_id" => "league1",
        "name" => "League One",
        "season" => "2024",
        "total_rosters" => 12
      },
      {
        "league_id" => "league2",
        "name" => "League Two",
        "season" => "2024",
        "total_rosters" => 10
      }
    ]
  end

  let(:drafts_data) do
    [
      {
        "draft_id" => "draft1",
        "league_id" => "league1",
        "season" => Time.now.year,
        "status" => "complete",
        "metadata" => { "name" => "Test Draft", "scoring_type" => "PPR" },
        "settings" => { "teams" => 12, "rounds" => 15 }
      }
    ]
  end

  let(:rosters_data) do
    [
      {
        "roster_id" => 1,
        "owner_id" => "user123",
        "wins" => 8,
        "losses" => 4
      }
    ]
  end

  before do
    allow(client).to receive_messages(
      get_user: user_data,
      get_user_leagues: leagues_data,
      get_user_drafts: drafts_data
    )
  end

  describe "#initialize" do
    it "sets identifier and user_id" do
      user = described_class.new(identifier, client)
      expect(user.identifier).to eq(identifier)
      expect(user.instance_variable_get(:@user_id)).to eq("user123")
    end

    it "fetches user data on initialization" do
      described_class.new(identifier, client)
      expect(client).to have_received(:get_user)
    end

    it "raises error for invalid identifier" do
      expect { described_class.new("", client) }.to raise_error(ArgumentError, "identifier must be a non-empty string")
      expect { described_class.new(nil, client) }.to raise_error(ArgumentError, "identifier must be a non-empty string")
    end

    it "raises error when user data is invalid" do
      allow(client).to receive(:get_user).and_return({ "invalid" => "data" })
      expect { described_class.new(identifier, client) }.to raise_error(SleeperApi::Error, "Invalid user data: user_id not found")
    end
  end

  describe "dynamic attributes" do
    let(:user) { described_class.new(identifier, client) }

    it "responds to user attributes" do
      expect(user.username).to eq("testuser")
      expect(user.display_name).to eq("Test User")
      expect(user.avatar).to eq("avatar123")
      expect(user.email).to eq("test@example.com")
    end

    it "returns nil for missing attributes" do
      allow(client).to receive(:get_user).and_return({ "user_id" => "user123" })
      user = described_class.new(identifier, client)
      expect(user.email).to be_nil
    end
  end

  describe "#avatar_url" do
    let(:user) { described_class.new(identifier, client) }

    context "when avatar is present" do
      it "returns the full avatar URL" do
        expect(user.avatar_url).to eq("https://sleepercdn.com/avatars/avatar123")
      end
    end

    context "when avatar is nil" do
      let(:user_data) { super().merge("avatar" => nil) }

      it "returns nil" do
        user = described_class.new(identifier, client)
        expect(user.avatar_url).to be_nil
      end
    end
  end

  describe "#leagues" do
    let(:user) { described_class.new(identifier, client) }

    it "fetches leagues on first call" do
      result = user.leagues
      expect(result.length).to eq(2)
      expect(result.first[:league_id]).to eq("league1")
      expect(client).to have_received(:get_user_leagues).with("user123", season: Time.now.year)
    end

    it "caches leagues for subsequent calls" do
      user.leagues
      user.leagues
      expect(client).to have_received(:get_user_leagues).once
    end

    it "accepts custom season parameter" do
      user.leagues(2023)
      expect(client).to have_received(:get_user_leagues).with("user123", season: 2023)
    end

    it "raises error for invalid season" do
      expect { user.leagues("invalid") }.to raise_error(ArgumentError, "season must be a valid year")
    end

    it "handles nil leagues response" do
      allow(client).to receive(:get_user_leagues).and_return(nil)
      expect(user.leagues).to eq([])
    end
  end

  describe "#rosters" do
    let(:user) { described_class.new(identifier, client) }
    let(:mock_league) { instance_double(SleeperApi::League) }

    before do
      allow(SleeperApi::League).to receive(:new).and_return(mock_league)
      allow(mock_league).to receive(:rosters).and_return(rosters_data)
    end

    it "returns user rosters from all leagues" do
      expect(user.rosters.length).to eq(2)
    end

    it "passes user_id to league rosters method" do
      user.rosters
      expect(mock_league).to have_received(:rosters).with(user_id: "user123").twice
    end

    it "accepts custom season parameter" do
      user.rosters(2023)
      expect(client).to have_received(:get_user_leagues).with("user123", season: 2023)
    end

    it "raises error for invalid season" do
      expect { user.rosters("invalid") }.to raise_error(ArgumentError, "season must be a valid year")
    end
  end

  describe "#drafts" do
    let(:user) { described_class.new(identifier, client) }

    it "fetches drafts on first call" do
      expect(user.drafts.length).to eq(1)
      expect(client).to have_received(:get_user_drafts).with("user123", season: Time.now.year)
    end

    it "caches drafts for subsequent calls" do
      user.drafts
      user.drafts
      expect(client).to have_received(:get_user_drafts).once
    end

    it "formats draft data with additional fields" do
      draft = user.drafts.first
      expect(draft[:league_name]).to eq("Test Draft")
      expect(draft[:scoring_type]).to eq("PPR")
      expect(draft[:total_teams]).to eq(12)
      expect(draft[:rounds]).to eq(15)
    end

    it "accepts custom season parameter" do
      user.drafts(2023)
      expect(client).to have_received(:get_user_drafts).with("user123", season: 2023)
    end

    it "raises error for invalid season" do
      expect { user.drafts("invalid") }.to raise_error(ArgumentError, "season must be a valid year")
    end

    it "handles nil drafts response" do
      allow(client).to receive(:get_user_drafts).and_return(nil)
      expect(user.drafts).to eq([])
    end
  end

  describe "#summary" do
    let(:user) { described_class.new(identifier, client) }
    let(:rosters_data) do
      [
        { wins: 8, losses: 4, ties: 0 },
        { wins: 6, losses: 6, ties: 0 }
      ]
    end

    before do
      allow(user).to receive_messages(
        leagues: leagues_data,
        rosters: rosters_data
      )
    end

    it "returns season summary statistics" do
      result = user.summary(2024)

      expect(result[:season]).to eq(2024)
      expect(result[:total_leagues]).to eq(2)
      expect(result[:total_wins]).to eq(14)
      expect(result[:total_losses]).to eq(10)
      expect(result[:total_ties]).to eq(0)
    end

    it "calculates winning records" do
      result = user.summary
      expect(result[:winning_record].length).to eq(1)
    end

    it "calculates average record" do
      result = user.summary

      expect(result[:avg_record][:wins]).to eq(7.0)
      expect(result[:avg_record][:losses]).to eq(5.0)
      expect(result[:avg_record][:ties]).to eq(0.0)
    end

    it "identifies best and worst teams" do
      result = user.summary

      expect(result[:best_team][:wins]).to eq(8)
      expect(result[:worst_team][:wins]).to eq(6)
    end

    it "accepts custom season parameter" do
      user.summary(2023)

      expect(user).to have_received(:leagues).with(2023)
      expect(user).to have_received(:rosters).with(2023)
    end
  end
end
