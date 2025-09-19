require "spec_helper"

RSpec.describe SleeperApi::Cache do
  let(:cache) { described_class.new }
  let(:test_data) { { "player1" => { "name" => "Test Player" } } }
  let(:cache_file) { "players_cache.json" }

  before do
    FileUtils.rm_f(cache_file)
  end

  after do
    FileUtils.rm_f(cache_file)
  end

  describe "#initialize" do
    it "sets default file path" do
      expect(cache.instance_variable_get(:@file_path)).to eq("players_cache.json")
    end

    it "sets default TTL" do
      expect(cache.instance_variable_get(:@ttl)).to eq(24 * 60 * 60)
    end
  end

  describe "#read" do
    context "when cache file does not exist" do
      it "returns nil" do
        expect(cache.read).to be_nil
      end
    end

    context "when cache file exists and is not expired" do
      before do
        File.write(cache_file, JSON.generate(test_data))
        File.utime(Time.now, Time.now, cache_file)
      end

      it "returns the cached data" do
        expect(cache.read).to eq(test_data)
      end

      it "caches the data in memory" do
        cache.read
        expect(cache.instance_variable_get(:@cache)).to eq(test_data)
      end

      it "returns cached data from memory on subsequent calls" do
        cache.read
        File.write(cache_file, JSON.generate({ "modified" => true }))
        expect(cache.read).to eq(test_data)
      end
    end

    context "when cache file exists but is expired" do
      before do
        File.write(cache_file, JSON.generate(test_data))
        old_time = Time.now - (25 * 60 * 60)
        File.utime(old_time, old_time, cache_file)
      end

      it "returns nil" do
        expect(cache.read).to be_nil
      end
    end

    context "when cache file contains invalid JSON" do
      before do
        File.write(cache_file, "invalid json")
        File.utime(Time.now, Time.now, cache_file)
      end

      it "returns nil" do
        expect(cache.read).to be_nil
      end
    end
  end

  describe "#write" do
    it "writes data to cache file" do
      cache.write(test_data)
      expect(File.exist?(cache_file)).to be true
      expect(JSON.parse(File.read(cache_file))).to eq(test_data)
    end

    it "creates valid JSON" do
      cache.write(test_data)
      expect { JSON.parse(File.read(cache_file)) }.not_to raise_error
    end
  end
end
