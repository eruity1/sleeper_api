require "spec_helper"
require "logger"

RSpec.describe SleeperApi do
  describe ".configure" do
    it "yields a configuration object" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(SleeperApi::Configuration)
    end

    it "allows configuration of timeout" do
      described_class.configure do |config|
        config.timeout = 45
      end
      
      expect(described_class.configuration.timeout).to eq(45)
    end

    it "allows configuration of retries" do
      described_class.configure do |config|
        config.retries = 2
      end
      
      expect(described_class.configuration.retries).to eq(2)
    end

    it "allows configuration of logger" do
      logger = Logger.new(STDOUT)
      described_class.configure do |config|
        config.logger = logger
      end
      
      expect(described_class.configuration.logger).to eq(logger)
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance with defaults when not configured" do
      config = described_class.configuration
      expect(config).to be_a(SleeperApi::Configuration)
      expect(config.timeout).to eq(30)
      expect(config.retries).to eq(3)
      expect(config.logger).to be_nil
    end

    it "returns the configured instance when configured" do
      described_class.configure do |config|
        config.timeout = 45
      end
      
      config = described_class.configuration
      expect(config.timeout).to eq(45)
    end
  end

  describe ".client" do
    it "returns a Client instance" do
      expect(described_class.client).to be_a(SleeperApi::Client)
    end

    it "returns the same client instance on subsequent calls" do
      client1 = described_class.client
      client2 = described_class.client
      expect(client1).to eq(client2)
    end

    it "passes configuration to client" do
      described_class.configure do |config|
        config.timeout = 45
      end
      
      client = described_class.client
      expect(client.instance_variable_get(:@config).timeout).to eq(45)
    end

    it "uses default configuration when not configured" do
      client = described_class.client
      config = client.instance_variable_get(:@config)
      expect(config.timeout).to eq(30)
      expect(config.retries).to eq(3)
    end
  end
end
