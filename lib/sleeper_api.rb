require_relative "sleeper_api/version"
require_relative "sleeper_api/client"
require_relative "sleeper_api/cache"
require_relative "sleeper_api/helpers"
require_relative "sleeper_api/league"
require_relative "sleeper_api/user"
require_relative "sleeper_api/draft"

module SleeperApi
  class Error < StandardError; end

  class << self
    attr_writer :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  def self.client
    @client ||= Client.new(configuration)
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  class Configuration
    attr_accessor :logger
    attr_reader :timeout, :retries

    MIN_TIMEOUT = 10
    MAX_TIMEOUT = 60
    MIN_RETRIES = 0
    MAX_RETRIES = 5

    def initialize
      @timeout = 30
      @retries = 3
      @logger = nil
    end

    def timeout=(value)
      unless value.between?(MIN_TIMEOUT, MAX_TIMEOUT)
        raise SleeperApi::Error, "Timeout must be between #{MIN_TIMEOUT} and #{MAX_TIMEOUT} seconds"
      end

      @timeout = value
    end

    def retries=(value)
      unless value.between?(MIN_RETRIES, MAX_RETRIES)
        raise SleeperApi::Error, "Retries must be between #{MIN_RETRIES} and #{MAX_RETRIES}"
      end

      @retries = value
    end
  end
end
