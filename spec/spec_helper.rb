require 'bundler/setup'
require 'sleeper_api'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    SleeperApi.instance_variable_set(:@client, nil)
    SleeperApi.instance_variable_set(:@configuration, nil)
  end
end
