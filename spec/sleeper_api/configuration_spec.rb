require "spec_helper"

RSpec.describe SleeperApi::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "sets default timeout" do
      expect(config.timeout).to eq(30)
    end

    it "sets default retries" do
      expect(config.retries).to eq(3)
    end

    it "sets default logger to nil" do
      expect(config.logger).to be_nil
    end
  end

  describe "#timeout=" do
    context "with valid timeout values" do
      it "accepts minimum timeout" do
        config.timeout = 10
        expect(config.timeout).to eq(10)
      end

      it "accepts maximum timeout" do
        config.timeout = 60
        expect(config.timeout).to eq(60)
      end

      it "accepts values within range" do
        config.timeout = 45
        expect(config.timeout).to eq(45)
      end
    end

    context "with invalid timeout values" do
      it "raises error for timeout too low" do
        expect { config.timeout = 5 }.to raise_error(SleeperApi::Error, 
          "Timeout must be between 10 and 60 seconds")
      end

      it "raises error for timeout too high" do
        expect { config.timeout = 120 }.to raise_error(SleeperApi::Error, 
          "Timeout must be between 10 and 60 seconds")
      end
    end
  end

  describe "#retries=" do
    context "with valid retry values" do
      it "accepts minimum retries" do
        config.retries = 0
        expect(config.retries).to eq(0)
      end

      it "accepts maximum retries" do
        config.retries = 5
        expect(config.retries).to eq(5)
      end

      it "accepts values within range" do
        config.retries = 2
        expect(config.retries).to eq(2)
      end
    end

    context "with invalid retry values" do
      it "raises error for retries too low" do
        expect { config.retries = -1 }.to raise_error(SleeperApi::Error, 
          "Retries must be between 0 and 5")
      end

      it "raises error for retries too high" do
        expect { config.retries = 10 }.to raise_error(SleeperApi::Error, 
          "Retries must be between 0 and 5")
      end
    end
  end

  describe "#logger=" do
    it "accepts logger assignment" do
      logger = Logger.new(STDOUT)
      config.logger = logger
      expect(config.logger).to eq(logger)
    end

    it "accepts nil logger" do
      config.logger = nil
      expect(config.logger).to be_nil
    end
  end
end
