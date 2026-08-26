require "spec_helper"

RSpec.describe SleeperApi::Client do
  let(:config) { SleeperApi::Configuration.new }
  let(:client) { described_class.new(config) }
  let(:base_url) { "https://api.sleeper.app/v1" }

  describe "#initialize" do
    it "stores the configuration" do
      expect(client.instance_variable_get(:@config)).to eq(config)
    end
  end

  describe "#league" do
    let(:mock_league_data) { { "name" => "Test League", "league_id" => "12345" } }

    before do
      stub_request(:get, "#{base_url}/league/12345").to_return(
        status: 200,
        body: JSON.generate(mock_league_data),
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "returns a League instance" do
      league = client.league("12345")
      expect(league).to be_a(SleeperApi::League)
      expect(league.league_id).to eq("12345")
    end

    it "passes the client to the league" do
      league = client.league("12345")
      expect(league.instance_variable_get(:@client)).to eq(client)
    end
  end

  describe "#user" do
    let(:mock_user_data) { { "user_id" => "testuser", "display_name" => "Test User" } }

    before do
      stub_request(:get, "#{base_url}/user/testuser").to_return(
        status: 200,
        body: JSON.generate(mock_user_data),
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "returns a User instance" do
      user = client.user("testuser")
      expect(user).to be_a(SleeperApi::User)
    end
  end

  describe "#draft" do
    let(:mock_draft_data) { { "draft_id" => "12345", "status" => "complete" } }

    before do
      stub_request(:get, "#{base_url}/draft/12345").to_return(
        status: 200,
        body: JSON.generate(mock_draft_data),
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "returns a Draft instance" do
      draft = client.draft("12345")
      expect(draft).to be_a(SleeperApi::Draft)
    end
  end

  describe "API methods" do
    let(:mock_response) { { "test" => "data" } }

    before do
      stub_request(:get, /#{base_url}.*/).to_return(
        status: 200,
        body: JSON.generate(mock_response),
        headers: { "Content-Type" => "application/json" }
      )
    end

    describe "#get_user" do
      it "makes request to correct endpoint" do
        client.get_user("testuser")

        expect(WebMock).to have_requested(:get, "#{base_url}/user/testuser")
      end

      it "returns the response" do
        response = client.get_user("testuser")
        expect(response.parsed_response).to eq(mock_response)
      end
    end

    describe "#get_league" do
      it "makes request to correct endpoint" do
        client.get_league("12345")

        expect(WebMock).to have_requested(:get, "#{base_url}/league/12345")
      end
    end

    describe "endpoint paths" do
      # Each of these is a thin passthrough to make_request; the contract that
      # matters is the URL it builds.
      {
        "get_user_leagues" => ["/user/u1/leagues/nfl/2024", ["u1", { season: 2024 }]],
        "get_user_drafts" => ["/user/u1/drafts/nfl/2024", ["u1", { season: 2024 }]],
        "get_league_rosters" => ["/league/l1/rosters", ["l1"]],
        "get_league_users" => ["/league/l1/users", ["l1"]],
        "get_league_matchups" => ["/league/l1/matchups/3", %w[l1 3]],
        "get_playoff_bracket" => ["/league/l1/winners_bracket", ["l1"]],
        "get_toilet_bowl" => ["/league/l1/losers_bracket", ["l1"]],
        "get_transactions" => ["/league/l1/transactions/3", %w[l1 3]],
        "get_league_drafts" => ["/league/l1/drafts", ["l1"]],
        "get_league_traded_picks" => ["/league/l1/traded_picks", ["l1"]],
        "get_draft_picks" => ["/draft/d1/picks", ["d1"]],
        "get_draft_traded_picks" => ["/draft/d1/traded_picks", ["d1"]]
      }.each do |method, (path, args)|
        it "#{method} requests #{path}" do
          stub_request(:get, "#{base_url}#{path}").to_return(
            status: 200, body: JSON.generate([]), headers: { "Content-Type" => "application/json" }
          )

          positional = args.grep_v(Hash)
          keywords = args.find { |a| a.is_a?(Hash) } || {}
          keywords.empty? ? client.public_send(method, *positional) : client.public_send(method, *positional, **keywords)

          expect(WebMock).to have_requested(:get, "#{base_url}#{path}")
        end
      end

      it "get_user_leagues defaults to the current year" do
        path = "/user/u1/leagues/nfl/#{Time.now.year}"
        stub_request(:get, "#{base_url}#{path}").to_return(
          status: 200, body: JSON.generate([]), headers: { "Content-Type" => "application/json" }
        )

        client.get_user_leagues("u1")

        expect(WebMock).to have_requested(:get, "#{base_url}#{path}")
      end
    end

    describe "#get_nfl_state" do
      before do
        stub_request(:get, "#{base_url}/state/nfl").to_return(
          status: 200,
          body: JSON.generate({ "week" => 5, "season" => "2024" }),
          headers: { "Content-Type" => "application/json" }
        )
      end

      it "symbolizes the top-level keys" do
        expect(client.get_nfl_state).to eq({ week: 5, season: "2024" })
      end
    end

    describe "#trending_players" do
      it "passes lookback and limit as query params" do
        path = "/players/nfl/trending/add?lookback_hours=48&limit=10"
        stub_request(:get, "#{base_url}#{path}").to_return(
          status: 200, body: JSON.generate([]), headers: { "Content-Type" => "application/json" }
        )

        client.trending_players(type: "add", lookback_hours: 48, limit: 10)

        expect(WebMock).to have_requested(:get, "#{base_url}#{path}")
      end

      it "defaults to add over 24 hours with a limit of 25" do
        path = "/players/nfl/trending/add?lookback_hours=24&limit=25"
        stub_request(:get, "#{base_url}#{path}").to_return(
          status: 200, body: JSON.generate([]), headers: { "Content-Type" => "application/json" }
        )

        client.trending_players

        expect(WebMock).to have_requested(:get, "#{base_url}#{path}")
      end
    end

    # The schedule lives at the host root, NOT under /v1. Before this existed,
    # base_uri carried the version and every path was relative to it, so this
    # endpoint was unreachable from the gem at any path you could pass in.
    #
    # `host_url` rather than `base_url` on purpose: a spec that built this URL
    # off base_url would be asserting the bug.
    # Undocumented, found by probing on 2026-08-27 while the consuming app's
    # backlog still recorded "Sleeper has no projections endpoint and no
    # player-stats endpoint". Both exist, both under /v1.
    #
    # The important shared property: **nothing here 404s.** An unplayed week, a
    # week out of range, and an unrecognised season type all answer 200 with
    # `{}`. A caller cannot tell a typo from a legitimately empty week, so the
    # gem returns what it got and the caller decides.
    describe "#stats and #projections" do
      let(:v1) { "https://api.sleeper.app/v1" }
      let(:stats) do
        { "4046" => { "pts_ppr" => 21.4, "rec" => 6.0, "off_snp" => 58.0 } }
      end

      it "fetches one week of stats" do
        stub_request(:get, "#{v1}/stats/nfl/regular/2025/1").to_return(
          status: 200, body: JSON.generate(stats),
          headers: { "Content-Type" => "application/json" }
        )

        expect(client.stats(2025, week: 1).parsed_response).to eq(stats)
      end

      it "fetches one week of projections" do
        stub_request(:get, "#{v1}/projections/nfl/regular/2026/1").to_return(
          status: 200, body: JSON.generate(stats),
          headers: { "Content-Type" => "application/json" }
        )

        expect(client.projections(2026, week: 1).parsed_response).to eq(stats)
      end

      # Dropping the week segment gives season totals — a different resource at
      # a shorter path, not a default of week 1.
      it "fetches season totals when no week is given" do
        stub_request(:get, "#{v1}/stats/nfl/regular/2025").to_return(
          status: 200, body: JSON.generate(stats),
          headers: { "Content-Type" => "application/json" }
        )

        client.stats(2025)

        expect(WebMock).to have_requested(:get, "#{v1}/stats/nfl/regular/2025")
      end

      it "takes a season type, because pre and post restart week numbering" do
        stub_request(:get, "#{v1}/stats/nfl/post/2024/1").to_return(
          status: 200, body: "{}", headers: { "Content-Type" => "application/json" }
        )

        client.stats(2024, week: 1, season_type: "post")

        expect(WebMock).to have_requested(:get, "#{v1}/stats/nfl/post/2024/1")
      end

      # Confirmed live on 2026-08-27: regular/2026/1 answers `{}` because the
      # season has not been played. Empty is a result, not an error.
      it "treats an unplayed week as a result rather than an error" do
        stub_request(:get, "#{v1}/stats/nfl/regular/2026/1").to_return(
          status: 200, body: "{}", headers: { "Content-Type" => "application/json" }
        )

        expect(client.stats(2026, week: 1).parsed_response).to eq({})
      end

      it "escapes a season type that would otherwise traverse out of the path" do
        stub_request(:get, "#{v1}/stats/nfl/..%2F..%2Fplayers%2Fnfl/2025/1").to_return(
          status: 200, body: "{}", headers: { "Content-Type" => "application/json" }
        )

        client.stats(2025, week: 1, season_type: "../../players/nfl")

        expect(WebMock).to have_requested(
          :get, "#{v1}/stats/nfl/..%2F..%2Fplayers%2Fnfl/2025/1"
        )
      end
    end

    describe "#schedule" do
      let(:host_url) { "https://api.sleeper.app" }
      let(:games) do
        [{ "status" => "pre_game", "date" => "2026-10-18", "home" => "GB",
           "away" => "DAL", "week" => 6, "game_id" => "202610612" }]
      end

      it "fetches the regular season schedule from outside /v1" do
        stub_request(:get, "#{host_url}/schedule/nfl/regular/2026").to_return(
          status: 200, body: JSON.generate(games),
          headers: { "Content-Type" => "application/json" }
        )

        expect(client.schedule(2026).parsed_response).to eq(games)
      end

      it "takes a season type, because pre and post restart week numbering" do
        stub_request(:get, "#{host_url}/schedule/nfl/post/2025").to_return(
          status: 200, body: JSON.generate([]),
          headers: { "Content-Type" => "application/json" }
        )

        client.schedule(2025, season_type: "post")

        expect(WebMock).to have_requested(:get, "#{host_url}/schedule/nfl/post/2025")
      end

      # A season Sleeper has not scheduled yet answers 200 with [], not 404.
      # Confirmed live against post/2026 on 2026-08-23.
      it "treats an empty schedule as a result rather than an error" do
        stub_request(:get, "#{host_url}/schedule/nfl/post/2026").to_return(
          status: 200, body: "[]", headers: { "Content-Type" => "application/json" }
        )

        expect(client.schedule(2026, season_type: "post").parsed_response).to eq([])
      end
    end

    describe "#get_players" do
      before do
        FileUtils.rm_f("players_cache.json")
      end

      it "makes request to correct endpoint" do
        client.get_players

        expect(WebMock).to have_requested(:get, "#{base_url}/players/nfl")
      end

      it "returns parsed response" do
        result = client.get_players
        expect(result).to eq(mock_response)
      end
    end

    describe "#get_player_by_id" do
      let(:players_data) { { "123" => { "name" => "Test Player" } } }

      before do
        allow(client).to receive(:get_players).and_return(players_data)
      end

      it "returns the player data for valid id" do
        result = client.get_player_by_id("123")
        expect(result).to eq({ "name" => "Test Player" })
      end

      it "returns nil for invalid id" do
        result = client.get_player_by_id("999")
        expect(result).to be_nil
      end
    end
  end

  describe "error handling" do
    context "when API returns error status" do
      before do
        stub_request(:get, /#{base_url}.*/).to_return(
          status: 404,
          body: "Not Found"
        )
      end

      # The path carries the API version now that base_uri does not, and the
      # error message quotes the path — so this string changed with it.
      it "raises SleeperApi::Error" do
        expect { client.get_user("nonexistent") }
          .to raise_error(SleeperApi::Error, "Failed to fetch /v1/user/nonexistent: 404")
      end
    end

    context "when request times out" do
      let(:config) do
        config = SleeperApi::Configuration.new
        config.retries = 1
        config
      end

      before do
        stub_request(:get, /#{base_url}.*/).to_timeout
      end

      it "retries the request" do
        expect { client.get_user("testuser") }.to raise_error(SleeperApi::Error)

        expect(WebMock).to have_requested(:get, "#{base_url}/user/testuser").times(2)
      end

      it "raises error after exhausting retries" do
        expect { client.get_user("testuser") }.to raise_error(SleeperApi::Error, "Request timed out after 2 retries")
      end

      it "logs each retry when a logger is configured" do
        logger = instance_spy(Logger)
        config.logger = logger

        expect { client.get_user("testuser") }.to raise_error(SleeperApi::Error, /timed out/)
        expect(logger).to have_received(:warn).with(%r{attempt 1/1})
      end
    end
  end
end
