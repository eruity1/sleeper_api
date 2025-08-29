# frozen_string_literal: true
require_relative "sleeper_api/version"
require_relative "sleeper_api/client"
require_relative "sleeper_api/league"
require_relative "sleeper_api/user"
require_relative "sleeper_api/draft"

module SleeperApi
  class Error < StandardError; end
  
  class << self
    attr_accessor :configuration
  end

  def self.configuration
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  def self.client
    @client ||= Client.new(configuration)
  end

  class Configuration
    attr_accessor :timeout, :retries, :logger

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
      if value >= MIN_TIMEOUT && value <= MAX_TIMEOUT
        @timeout = value
      else
        raise SleeperApi::Error, "Timeout must be between #{MIN_TIMEOUT} and #{MAX_TIMEOUT} seconds"
      end
    end

    def retries=(value)
      if value >= MIN_RETRIES && value <= MAX_RETRIES
        @retries = value
      else
        raise SleeperApi::Error, "Retries must be between #{MIN_RETRIES} and #{MAX_RETRIES}"
      end
    end

    def logger=(value)
      @logger = value
    end
  end
end
