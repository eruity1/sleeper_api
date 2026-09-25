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

    # ⚠️ **The other host.** `api.sleeper.com` serves the same stat lines with
    # the week's team and opponent on them; the `.app` endpoint above serves
    # them with neither. Probed 2026-09-08, re-probed 2026-09-14.
    describe "#stats_with_context" do
      let(:web) { "https://api.sleeper.com" }
      let(:rows) do
        [{ "player_id" => "2992", "team" => "TEN", "opponent" => "SF", "week" => 16,
           "game_id" => "202111634", "date" => "2021-12-23",
           "player" => { "position" => "QB", "team" => nil } }]
      end

      it "fetches a week from the web host, not the one every other call uses" do
        stub_request(:get, "#{web}/stats/nfl/2021/16?season_type=regular").to_return(
          status: 200, body: JSON.generate(rows),
          headers: { "Content-Type" => "application/json" }
        )

        expect(client.stats_with_context(2021, 16).parsed_response).to eq(rows)
      end

      # The whole reason this exists: `api.sleeper.app` must never be asked for
      # it, because it answers 200 with stat lines carrying none of the context.
      it "never reaches the api host" do
        stub_request(:get, "#{web}/stats/nfl/2021/16?season_type=regular").to_return(
          status: 200, body: "[]", headers: { "Content-Type" => "application/json" }
        )

        client.stats_with_context(2021, 16)

        expect(WebMock).not_to have_requested(:get, /api\.sleeper\.app/)
      end

      # No /v1, and the season type is a query parameter rather than a segment.
      it "takes a season type, because pre and post restart week numbering" do
        stub_request(:get, "#{web}/stats/nfl/2021/1?season_type=post").to_return(
          status: 200, body: "[]", headers: { "Content-Type" => "application/json" }
        )

        client.stats_with_context(2021, 1, season_type: "post")

        expect(WebMock).to have_requested(:get, "#{web}/stats/nfl/2021/1?season_type=post")
      end

      # Confirmed live 2026-09-14: an unplayed 2026 week, a week out of range, a
      # season before Sleeper's history and a garbage season type all answer
      # 200 with an empty array. Empty is a result, not an error.
      it "treats an unplayed week as a result rather than an error" do
        stub_request(:get, "#{web}/stats/nfl/2026/5?season_type=regular").to_return(
          status: 200, body: "[]", headers: { "Content-Type" => "application/json" }
        )

        expect(client.stats_with_context(2026, 5).parsed_response).to eq([])
      end

      it "escapes a season type that would otherwise leave the query" do
        stub_request(:get, "#{web}/stats/nfl/2021/16?season_type=regular%26sport%3Dnba")
          .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

        client.stats_with_context(2021, 16, season_type: "regular&sport=nba")

        expect(WebMock).to have_requested(
          :get, "#{web}/stats/nfl/2021/16?season_type=regular%26sport%3Dnba"
        )
      end

      it "escapes a week that would otherwise traverse out of the path" do
        stub_request(:get, "#{web}/stats/nfl/2021/..%2F..%2Fplayers%2Fnfl?season_type=regular")
          .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

        client.stats_with_context(2021, "../../players/nfl")

        expect(WebMock).to have_requested(
          :get, "#{web}/stats/nfl/2021/..%2F..%2Fplayers%2Fnfl?season_type=regular"
        )
      end

      # ⚠️ `/stats/nfl/2021/16` is a real path on BOTH hosts and they return
      # different things, so an error quoting the path alone cannot say which
      # one failed.
      it "names the host in the error, which a path alone cannot" do
        stub_request(:get, "#{web}/stats/nfl/2021/16?season_type=regular")
          .to_return(status: 503, body: "")

        expect { client.stats_with_context(2021, 16) }.to raise_error(
          SleeperApi::Error,
          "Failed to fetch #{web}/stats/nfl/2021/16?season_type=regular: 503"
        )
      end
    end

    # The only source of a kickoff time. Measured 2026-09-25, the morning after
    # ATL @ GB: #schedule carries a `date` and nothing finer.
    describe "#scores" do
      let(:web) { "https://api.sleeper.com" }
      let(:games) do
        [{ "game_id" => "202610312", "week" => 3, "status" => "complete",
           "start_time" => 1_790_295_300_000, "date" => "2026-09-24",
           "metadata" => { "home_team" => "GB", "away_team" => "ATL", "quarter" => "F" } }]
      end

      it "fetches a week's games from the web host" do
        stub_request(:get, "#{web}/scores/nfl/regular/2026/3").to_return(
          status: 200, body: JSON.generate(games),
          headers: { "Content-Type" => "application/json" }
        )

        expect(client.scores(2026, 3).parsed_response).to eq(games)
      end

      it "never reaches the api host, which has no such path" do
        stub_request(:get, "#{web}/scores/nfl/regular/2026/3").to_return(
          status: 200, body: "[]", headers: { "Content-Type" => "application/json" }
        )

        client.scores(2026, 3)

        expect(WebMock).not_to have_requested(:get, /api\.sleeper\.app/)
      end

      # Unlike #stats_with_context, the season form is useful: all 272 games of
      # 2026 in one ~610 KB call, every one with a start time.
      it "answers the whole season when no week is given" do
        stub_request(:get, "#{web}/scores/nfl/regular/2026").to_return(
          status: 200, body: JSON.generate(games), headers: { "Content-Type" => "application/json" }
        )

        expect(client.scores(2026).parsed_response).to eq(games)
      end

      # A path segment here, where #stats_with_context takes a query parameter —
      # `/scores/nfl/2026/3?season_type=regular` answers 200 with nothing.
      it "puts the season type in the path" do
        stub_request(:get, "#{web}/scores/nfl/post/2025/1").to_return(
          status: 200, body: "[]", headers: { "Content-Type" => "application/json" }
        )

        client.scores(2025, 1, season_type: "post")

        expect(WebMock).to have_requested(:get, "#{web}/scores/nfl/post/2025/1")
      end

      it "escapes a week that would otherwise traverse out of the path" do
        stub_request(:get, "#{web}/scores/nfl/regular/2026/..%2F..%2Fplayers")
          .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

        client.scores(2026, "../../players")

        expect(WebMock).to have_requested(:get, "#{web}/scores/nfl/regular/2026/..%2F..%2Fplayers")
      end

      it "names the host in the error" do
        stub_request(:get, "#{web}/scores/nfl/regular/2026/3").to_return(status: 503, body: "")

        expect { client.scores(2026, 3) }.to raise_error(
          SleeperApi::Error, "Failed to fetch #{web}/scores/nfl/regular/2026/3: 503"
        )
      end
    end

    describe "#schedule" do
      let(:host_url) { "https://api.sleeper.app" }
      # All four statuses Sleeper has been observed to send, in one fixture.
      # It carried `pre_game` alone, which is a shape live data does produce
      # but only ever on a quiet Tuesday: week 1 of 2026 held one `complete`,
      # one `in_game` and fourteen `pre_game` at the same moment, and the
      # canceled DAL/SEA in week 6 is real too. A fixture narrower than the
      # API is how a caller ends up written against a vocabulary of one.
      let(:games) do
        [{ "status" => "pre_game", "date" => "2026-10-18", "home" => "GB",
           "away" => "DAL", "week" => 6, "game_id" => "202610612" },
         { "status" => "in_game", "date" => "2026-09-10", "home" => "LAR",
           "away" => "SF", "week" => 1, "game_id" => "202610123" },
         { "status" => "complete", "date" => "2026-09-09", "home" => "SEA",
           "away" => "NE", "week" => 1, "game_id" => "202610130" },
         { "status" => "canceled", "date" => "2026-10-18", "home" => "DAL",
           "away" => "SEA", "week" => 6, "game_id" => "202610611" }]
      end

      it "fetches the regular season schedule from outside /v1" do
        stub_request(:get, "#{host_url}/schedule/nfl/regular/2026").to_return(
          status: 200, body: JSON.generate(games),
          headers: { "Content-Type" => "application/json" }
        )

        expect(client.schedule(2026).parsed_response).to eq(games)
      end

      # Untranslated and unfiltered. The status vocabulary is Sleeper's, it is
      # open, and the caller is the only one who knows what to do with a value
      # this gem has never seen — so a `canceled` game must arrive as a
      # `canceled` game rather than be tidied away as "not a real fixture".
      it "passes every status through, including ones it has no meaning for" do
        stub_request(:get, "#{host_url}/schedule/nfl/regular/2026").to_return(
          status: 200, body: JSON.generate(games),
          headers: { "Content-Type" => "application/json" }
        )

        statuses = client.schedule(2026).parsed_response.map { |game| game["status"] }

        expect(statuses).to eq(%w[pre_game in_game complete canceled])
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
