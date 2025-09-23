require_relative "sleeper_api/version"
require_relative "sleeper_api/helpers"
require_relative "sleeper_api/client"
require_relative "sleeper_api/league"
require_relative "sleeper_api/user"
require_relative "sleeper_api/draft"

module SleeperApi
  class Error < StandardError; end

  class << self
    attr_writer :configuration
  end

  # Configure the gem globally.
  #
  # @yieldparam [SleeperApi::Configuration] config
  # @example
  #   SleeperApi.configure do |config|
  #     config.timeout = 20
  #     config.retries = 5
  #     config.logger = Logger.new('sleeper.log')
  #   end
  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  # Get the configured client instance.
  #
  # @return [SleeperApi::Client]
  def self.client
    @client ||= Client.new(configuration)
  end

  # Get the global configuration.
  #
  # @return [SleeperApi::Configuration]
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Configuration for SleeperApi client behavior.
  #
  # @attr timeout [Integer] HTTP request timeout (10-60 seconds)
  # @attr retries [Integer] Maximum retry attempts (0-5)
  # @attr logger [Logger, nil] Logger for debugging requests
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

    # Set HTTP timeout with validation.
    #
    # @param value [Integer] Timeout in seconds
    # @raise [SleeperApi::Error] If outside valid range
    def timeout=(value)
      unless value.between?(MIN_TIMEOUT, MAX_TIMEOUT)
        raise SleeperApi::Error, "Timeout must be between #{MIN_TIMEOUT} and #{MAX_TIMEOUT} seconds"
      end

      @timeout = value
    end

    # Set retry count with validation.
    #
    # @param value [Integer] Number of retries
    # @raise [SleeperApi::Error] If outside valid range
    def retries=(value)
      unless value.between?(MIN_RETRIES, MAX_RETRIES)
        raise SleeperApi::Error, "Retries must be between #{MIN_RETRIES} and #{MAX_RETRIES}"
      end

      @retries = value
    end
  end
end
