require "spec_helper"

RSpec.describe SleeperApi::Draft do
  let(:client) { instance_double(SleeperApi::Client) }
  let(:draft_id) { "12345" }
  let(:draft_data) do
    {
      "draft_id" => draft_id,
      "league_id" => "league123",
      "status" => "in_progress",
      "season" => "2024",
      "type" => "snake",
      "settings" => { "teams" => 12, "rounds" => 15 },
      "metadata" => { "name" => "Test Draft" },
      "sport" => "nfl"
    }
  end

  let(:picks_data) do
    [
      {
        "pick_no" => 1,
        "player_id" => "1234",
        "picked_by" => "user1",
        "roster_id" => 1,
        "round" => 1,
        "metadata" => { "first_name" => "John", "last_name" => "Doe", "position" => "QB" }
      },
      {
        "pick_no" => 2,
        "player_id" => "5678",
        "picked_by" => "user2",
        "roster_id" => 2,
        "round" => 1,
        "metadata" => { "first_name" => "Jane", "last_name" => "Smith", "position" => "RB" }
      }
    ]
  end

  let(:traded_picks_data) do
    [
      {
        "roster_id" => 1,
        "previous_owner_id" => 2,
        "owner_id" => 3,
        "round" => 5,
        "season" => "2024"
      }
    ]
  end

  before do
    allow(client).to receive_messages(
      get_draft: draft_data,
      get_draft_picks: picks_data,
      get_draft_traded_picks: traded_picks_data
    )
  end

  describe "#initialize" do
    it "sets draft_id" do
      draft = described_class.new(draft_id, client)
      expect(draft.draft_id).to eq(draft_id)
    end

    it "fetches draft data on initialization" do
      described_class.new(draft_id, client)
      expect(client).to have_received(:get_draft)
    end

    it "raises error for invalid draft_id" do
      expect { described_class.new("", client) }.to raise_error(ArgumentError, "draft_id must be a non-empty string")
      expect { described_class.new(nil, client) }.to raise_error(ArgumentError, "draft_id must be a non-empty string")
    end
  end

  describe "dynamic attributes" do
    let(:draft) { described_class.new(draft_id, client) }

    it "responds to draft attributes" do
      expect(draft.league_id).to eq("league123")
      expect(draft.status).to eq("in_progress")
      expect(draft.season).to eq("2024")
      expect(draft.type).to eq("snake")
      expect(draft.sport).to eq("nfl")
    end

    it "returns nil for missing attributes" do
      allow(client).to receive(:get_draft).and_return({})
      draft = described_class.new(draft_id, client)
      expect(draft.status).to be_nil
    end
  end

  describe "#picks" do
    let(:draft) { described_class.new(draft_id, client) }

    it "fetches picks on first call" do
      expect(draft.picks.length).to eq(2)
      expect(client).to have_received(:get_draft_picks)
    end

    it "caches picks for subsequent calls" do
      draft.picks
      draft.picks
      expect(client).to have_received(:get_draft_picks).once
    end

    it "filters by round" do
      result = draft.picks(round: 1)
      expect(result.length).to eq(2)
      expect(result.all? { |pick| pick[:round] == 1 }).to be true
    end

    it "filters by roster_id" do
      result = draft.picks(roster_id: 1)
      expect(result.length).to eq(1)
      expect(result.first[:roster_id]).to eq(1)
    end

    it "filters by both round and roster_id" do
      result = draft.picks(round: 1, roster_id: 1)
      expect(result.length).to eq(1)
      expect(result.first[:round]).to eq(1)
      expect(result.first[:roster_id]).to eq(1)
    end
  end

  describe "#traded_picks" do
    let(:draft) { described_class.new(draft_id, client) }

    it "fetches traded picks on first call" do
      expect(draft.traded_picks.length).to eq(1)
      expect(client).to have_received(:get_draft_traded_picks)
    end

    it "caches traded picks for subsequent calls" do
      draft.traded_picks
      draft.traded_picks
      expect(client).to have_received(:get_draft_traded_picks).once
    end

    it "filters by original_owner_id" do
      result = draft.traded_picks(original_owner_id: 1)
      expect(result.length).to eq(1)
      expect(result.first[:roster_id]).to eq(1)
    end

    it "filters by previous_owner_id" do
      result = draft.traded_picks(previous_owner_id: 2)
      expect(result.length).to eq(1)
      expect(result.first[:previous_owner_id]).to eq(2)
    end

    it "filters by current_owner_id" do
      result = draft.traded_picks(current_owner_id: 3)
      expect(result.length).to eq(1)
      expect(result.first[:owner_id]).to eq(3)
    end
  end

  describe "#league" do
    let(:draft) { described_class.new(draft_id, client) }
    let(:mock_league) { instance_double(SleeperApi::League) }

    before do
      allow(client).to receive(:league).and_return(mock_league)
    end

    it "returns the associated league" do
      result = draft.league
      expect(client).to have_received(:league).with("league123")
      expect(result).to eq(mock_league)
    end
  end

  describe "#picked_by" do
    let(:draft) { described_class.new(draft_id, client) }
    let(:mock_league) { instance_double(SleeperApi::League) }

    before do
      allow(client).to receive(:league).and_return(mock_league)
      allow(mock_league).to receive(:users).and_return([
                                                         { user_id: "user1", display_name: "User One" },
                                                         { user_id: "user2", display_name: "User Two" }
                                                       ])
    end

    it "returns the user who picked a player" do
      expect(draft.picked_by("1234")).to eq({ user_id: "user1", display_name: "User One" })
    end

    it "returns nil for unpicked player" do
      expect(draft.picked_by("9999")).to be_nil
    end
  end

  describe "#next_pick" do
    context "when draft is in progress" do
      let(:draft) { described_class.new(draft_id, client) }

      it "calculates the next pick" do
        result = draft.next_pick
        expect(result[:pick_no]).to eq(3)
        expect(result[:round]).to eq(1)
        expect(result[:draft_slot]).to eq(3)
      end
    end

    context "when draft is complete" do
      let(:draft_data) { super().merge("status" => "complete") }

      it "returns nil" do
        draft = described_class.new(draft_id, client)
        expect(draft.next_pick).to be_nil
      end
    end

    context "when no picks have been made" do
      let(:picks_data) { [] }

      it "returns first pick" do
        draft = described_class.new(draft_id, client)
        result = draft.next_pick
        expect(result[:pick_no]).to eq(1)
        expect(result[:round]).to eq(1)
        expect(result[:draft_slot]).to eq(1)
      end
    end
  end

  describe "#summary" do
    let(:draft) { described_class.new(draft_id, client) }

    it "returns draft summary" do
      result = draft.summary
      expect(result[:draft_id]).to eq(draft_id)
      expect(result[:type]).to eq("snake")
      expect(result[:season]).to eq("2024")
      expect(result[:total_picks]).to eq(2)
      expect(result[:total_rounds]).to eq(15)
      expect(result[:top_picks].length).to eq(2)
    end

    it "formats top picks correctly" do
      first_pick = draft.summary[:top_picks].first
      expect(first_pick[:player_id]).to eq("1234")
      expect(first_pick[:player_name]).to eq("John Doe")
      expect(first_pick[:position]).to eq("QB")
      expect(first_pick[:picked_by]).to eq("user1")
    end
  end

  describe "#rounds" do
    let(:draft) { described_class.new(draft_id, client) }

    it "groups picks by round" do
      result = draft.rounds

      expect(result).to be_a(Hash)
      expect(result.keys).to include(1)
      expect(result[1].length).to eq(2)
      expect(result[1].all? { |pick| pick[:round] == 1 }).to be true
    end

    it "returns empty hash when no picks" do
      allow(client).to receive(:get_draft_picks).and_return([])

      draft = described_class.new(draft_id, client)
      expect(draft.rounds).to eq({})
    end
  end

  describe "#team_picks" do
    let(:draft) { described_class.new(draft_id, client) }

    it "groups picks by roster_id" do
      result = draft.team_picks

      expect(result).to be_a(Hash)
      expect(result.keys).to include(1, 2)
      expect(result[1].length).to eq(1)
      expect(result[2].length).to eq(1)
    end

    it "returns empty hash when no picks" do
      allow(client).to receive(:get_draft_picks).and_return([])

      draft = described_class.new(draft_id, client)
      expect(draft.team_picks).to eq({})
    end
  end
end
