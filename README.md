# SleeperApi

A comprehensive Ruby gem for interacting with [Sleeper's fantasy football API](https://docs.sleeper.com/). Built with performance, reliability, and developer experience in mind.

## Features

- Complete API Coverage - Users, leagues, drafts, players, matchups, transactions

- Performance Optimized - Smart caching, connection pooling, rate limiting

- Robust Error Handling - Automatic retries, timeout management, detailed error messages

- Well Tested - 90%+ test coverage with RSpec

- Highly Configurable - Custom timeouts, retries, logging

- Production Ready - Type signatures, CI/CD, code quality tools

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sleeper_api'
```

## Quick Start

```ruby
require 'sleeper_api'

# Basic usage with default configuration
client = SleeperApi.client
league = client.league("123456789012345678")

# Access league information
puts league.name          # "My Fantasy League"
puts league.total_rosters # 12
puts league.status        # "in_season"

# Get rosters
rosters = league.rosters
rosters.each do |roster|
  puts "#{roster[:owner_display_name]}: #{roster[:wins]}-#{roster[:losses]}"
end
```

## Configuration

Customize the gem's behavior:

```ruby
SleeperApi.configure do |config|
  config.timeout = 45    # Request timeout in seconds (10-60)
  config.retries = 5     # Number of retries on failure (0-5)
  config.logger = Logger.new(STDOUT)  # Custom logger
end

# Configuration is applied to all subsequent client instances
client = SleeperApi.client
```

## API Coverage

### Users

Get user information and their leagues/drafts:

```ruby
# Find a user by username
user = SleeperApi.client.user('johndoe')

# Basic profile
user.username                  # => "johndoe"
user.display_name              # => "John Doe"
user.avatar_url                # => "https://sleepercdn.com/avatars/abc123"
user.is_bot                    # => false

# All leagues for current season
leagues = user.leagues
leagues.each do |league|
  status = league[:status] == "finished" ? "🏆" : league[:status]
  puts "#{status} #{league[:name]} (#{league[:total_rosters]} teams)"
end

# Specific season
old_leagues = user.leagues(2023)
championships = old_leagues.select { |l| l[:status] == "finished" }

# Get all my rosters across all leagues
rosters = user.rosters
rosters.each do |roster|
  puts "#{roster[:league_name]}: #{roster[:team_name]} (#{roster[:wins]}-#{roster[:losses]})"
end

# Best performing team this season
best_roster = user.rosters.max_by { |r| r[:wins].to_i - r[:losses].to_i }
puts "Top team: #{best_roster[:team_name]} (#{best_roster[:wins]}-#{best_roster[:losses]})"

# All drafts with enhanced info
drafts = user.drafts(2024)
drafts.each do |draft|
  status = draft[:status] == "complete" ? "✅" : draft[:status]
  puts "#{status} #{draft[:league_name]} - #{draft[:type]} (#{draft[:total_teams]} teams)"
end

# Live drafts only
live_drafts = user.drafts.select { |d| d[:status] == "live" }

# Season summary
summary = user.summary
puts "#{summary[:total_leagues]} leagues this season"
puts "Winning record in #{summary[:winning_record].length} leagues"
puts "Overall: #{summary[:total_wins]}-#{summary[:total_losses]}"
```

### Leagues

Access league data, rosters, matchups, and transactions:

```ruby
league = SleeperApi.client.league("123456")

# Basic league info
league.name                    # => "My Fantasy League"
league.season                  # => "2024"
league.total_rosters           # => 12
league.status                  # => "regular"
league.avatar_url              # => "https://sleepercdn.com/avatars/abc123"

# Formatted rosters (with team names and records)
rosters = league.rosters
roster = rosters.first
roster[:owner_display_name]    # => "John Doe"
roster[:team_name]             # => "Gridiron Gang"
roster[:wins]                  # => 7
roster[:losses]                # => 2
roster[:remaining_faab]        # => 45
roster[:starters]              # => ["player_id_1", "player_id_2", ...]
roster[:bench]                 # => ["player_id_4", "player_id_5", ...]

# My roster only
my_roster = league.rosters(user_id: my_user_id)

# Week-specific matchups
matchups = league.matchups_by_week(week: 5)
matchup = matchups.first
team = matchup[:rosters].first
team[:points]                  # => 142.5
team[:starter_points]          # => [{ "player_id" => 18.2 }, ...]

# Transactions
transactions = league.transactions(week: 5)
tx = transactions.first
tx[:type]                      # => "tr"
tx[:adds]                      # => [{ player_id: "123", roster_id: 1 }]
tx[:drops]                     # => [{ player_id: "456", roster_id: 1 }]
tx[:waiver_bid]                # => 12

# Users
users = league.users
user = users.find { |u| u[:commissioner] }
user[:display_name]            # => "Commish McGee"
user[:team_name]               # => "Champions"

# Playoffs
playoff_matchups = league.playoff_bracket
matchup = playoff_matchups.first
matchup[:team1_owner]          # => "Team Alpha"
matchup[:winner_owner]         # => "Team Alpha"

# Tourlet Bowl / Losers Bracket
toilet_bowl_matchups = league.toilet_bowl
matchup = toilet_bowl_matchups.first
matchup[:team1_owner]          # => "Team Beta"
matchup[:winner_owner]         # => "Team Beta"
```

### Drafts

Access draft information, picks, and traded picks:

```ruby
# Get a specific draft
draft = SleeperApi.client.draft("draft_123456")

# Basic draft info
draft.type                     # => "snake" or "auction"
draft.status                   # => "pre_draft", "live", "complete"
draft.season                   # => "2024"
draft.start_time              # => "2024-08-27T20:00:00.000Z"
draft.league.name             # => "My Fantasy League"

# All picks (180 picks for 15-round, 12-team draft)
picks = draft.picks
puts "#{picks.length} total picks made"

# Filter picks
round_1 = draft.picks(round: 1)
team_3_picks = draft.picks(roster_id: 3)

round_1.each do |pick|
  player = SleeperApi.client.get_player_by_id(pick[:player_id])
  puts "#{pick[:pick_no]}. #{player['full_name']} (#{player['position']}) - Team #{pick[:roster_id]}"
end

# Who drafted a specific player?
picker = draft.picked_by("4036") # User 1

# Traded picks
trades = draft.traded_picks
team_3_trades = draft.traded_picks(original_owner_id: 3)

team_3_trades.each do |trade|
  puts "Team 3 traded away #{trade[:round]}.#{trade[:draft_slot]} to Team #{trade[:owner_id]}"
end

# Live draft - next pick info
if draft.status == "live"
  next_pick = draft.next_pick
  puts "Next up: Round #{next_pick[:round]}, Pick #{next_pick[:pick_no]} (slot #{next_pick[:draft_slot]})"
end

# Quick summary with top picks
summary = draft.summary
puts "#{summary[:total_picks]} picks in #{summary[:total_rounds]} rounds"
summary[:top_picks].each do |pick|
  puts "#{pick[:pick_no]}. #{pick[:player_name]} (#{pick[:position]}, #{pick[:team]}) - #{pick[:roster_id]}"
end

# Grouped views
rounds = draft.rounds # { 1 => [picks], 2 => [picks], ... }
team_3_rounds = draft.team_picks[3] # Team 3's picks by round
```

### Players

Access player data with automatic caching:

```ruby
# Get all players (cached for 24 hours)
players = client.get_players

# Find specific player
player = client.get_player_by_id("1234")
puts "#{player['first_name']} #{player['last_name']} - #{player['position']}"

# Get trending players
trending_adds = client.trending_players(type: "add", limit: 10)
trending_drops = client.trending_players(type: "drop", limit: 10)
```

### Player Helper

All resource classes (`League`, `User`, `Draft`) include a `player_details` helper method that returns formatted Sleeper player data. This eliminates repetitive player lookups and ensures consistent symbolization.

```ruby
# In any resource (League, User, Draft)
league = SleeperApi.client.league("123456")

# Get player details with one method call
player = league.player_details("4036") # Christian McCaffrey
if player
  puts "#{player[:full_name]} (#{player[:position]}, #{player[:team]})"
  puts "Bye week: #{player[:bye]} | Injury status: #{player[:injury_status]}"
end

# Works in matchups
matchups = league.matchups_by_week(week: 5)
matchup = matchups.first
team = matchup[:rosters].first

# Get starter names and positions
team[:starters].each do |player_id|
  player = league.player_details(player_id)
  if player
    puts "#{player[:full_name]} (#{player[:position]}) - #{team[:starter_points].find { |p| p.keys.first == player_id }&.values&.first || 0} pts"
  end
end

# Works in rosters
roster = league.rosters.first
roster[:starters].each_with_index do |player_id, index|
  player = league.player_details(player_id)
  position = player ? player[:position] : "?"
  points = roster[:starter_points]&.dig(index, player_id) || 0
  puts "#{position}: #{player ? player[:full_name] : 'Unknown'} (#{points} pts)"
end

# Works in drafts
draft = SleeperApi.client.draft("draft_123")
round_1 = draft.picks(round: 1)

round_1.each do |pick|
  player = draft.player_details(pick[:player_id])
  if player
    puts "#{pick[:pick_no]}. #{player[:full_name]} (#{player[:position]}, #{player[:team]})"
  end
end

# Works across user's leagues
user = SleeperApi.client.user('johndoe')
rosters = user.rosters

rosters.each do |roster|
  puts "\n#{roster[:team_name]} starters:"
  roster[:starters].each do |player_id|
    player = roster.player_details(player_id) # Note: uses the League instance under the hood
    puts "  • #{player ? player[:full_name] : 'Unknown'} (#{player[:position] if player})"
  end
end
```

### Additional Endpoints

```ruby
# Get NFL state
state = client.get_nfl_state
puts "Current week: #{state['week']}"

# Get playoff brackets
winners_bracket = client.get_league_playoff_bracket("league_id")
losers_bracket = client.get_league_toilet_bowl("league_id")

# Get league drafts
league_drafts = client.get_league_drafts("league_id")

# Get traded picks
traded_picks = client.get_league_traded_picks("league_id")
```

## Error Handling

The gem provides comprehensive error handling:

```ruby
begin
  league = client.league("invalid_id")
  # Process league data
rescue SleeperApi::Error => e
  puts "API Error: #{e.message}"
rescue ArgumentError => e
  puts "Invalid parameter: #{e.message}"
end
```

### Error Types

- SleeperApi::Error - API-related errors (404, 500, timeouts, etc.)

- ArgumentError - Invalid parameters passed to methods

## Performance Considerations

### Caching

- Player data is cached for 24 hours to reduce API calls

- League/User/Draft data is cached per instance

- Cache files are stored in the current working directory

### Rate Limiting

- Be mindful of Sleeper's rate limits: stay under 1000 API calls per minute

- The gem automatically handles timeouts and retries

- Consider caching frequently accessed data in your application

### Memory Usage

- Large datasets (like all players) are cached to disk

- League rosters and matchups are fetched lazily

- Use no_data: true when initializing leagues if you don't need immediate data

## Testing

The gem includes comprehensive tests:

```shellscript
# Run all tests
bundle exec rspec
# Run with coverage
bundle exec rspec --coverage
# Run specific test file
bundle exec rspec spec/sleeper_api/client_spec.rb
```

### Setup

```shellscript
git clone https://github.com/eruity1/sleeper_api.git
cd sleeper_api
bundle install
```

### Code Quality

```shellscript
# Run all checks (tests + linting)
bundle exec rake ci

# Run RuboCop
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -a
```

### Contributing

1.  Fork the repository

1.  Create a feature branch (git checkout -b feature/amazing-feature)

1.  Commit your changes (git commit -m 'Add amazing feature')

1.  Push to the branch (git push origin feature/amazing-feature)

1.  Open a Pull Request

### Development Dependencies

- rspec - Testing framework

- rubocop - Code style and quality

- simplecov - Test coverage

- webmock - HTTP request mocking

## Requirements

- Ruby 2.6.0 or higher

- No external dependencies (HTTParty is bundled)

## License

The gem is available as open source under the terms of the MIT License.

## Changelog

See CHANGELOG.md for version history and updates.
