require "bundler/setup"
require "simplecov"

# SimpleCov must start before the library is required, otherwise none of
# lib/ is instrumented and coverage is reported as 0/0 lines.
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/bin/"

  minimum_coverage 90
  maximum_coverage_drop 2
end

require "logger"
require "sleeper_api"
require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    SleeperApi.instance_variable_set(:@client, nil)
    SleeperApi.instance_variable_set(:@configuration, nil)
  end
end
