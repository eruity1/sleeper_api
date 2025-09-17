require "spec_helper"

RSpec.describe SleeperApi::Helpers do
  let(:dummy_class) do
    Class.new do
      include SleeperApi::Helpers

      def initialize(client = nil)
        @client = client
      end
    end
  end

  let(:helper) { dummy_class.new }

  describe "#deep_symbolize_keys" do
    it "converts string keys to symbols in a hash" do
      input = { "name" => "John", "age" => 30 }
      expected = { name: "John", age: 30 }

      expect(helper.deep_symbolize_keys(input)).to eq(expected)
    end

    it "handles nested hashes" do
      input = {
        "user" => {
          "name" => "John",
          "profile" => {
            "age" => 30,
            "city" => "NYC"
          }
        }
      }

      expected = {
        user: {
          name: "John",
          profile: {
            age: 30,
            city: "NYC"
          }
        }
      }

      expect(helper.deep_symbolize_keys(input)).to eq(expected)
    end

    it "handles arrays of hashes" do
      input = [
        { "name" => "John", "age" => 30 },
        { "name" => "Jane", "age" => 25 }
      ]

      expected = [
        { name: "John", age: 30 },
        { name: "Jane", age: 25 }
      ]

      expect(helper.deep_symbolize_keys(input)).to eq(expected)
    end

    it "handles mixed data types" do
      input = {
        "string" => "text",
        "number" => 42,
        "boolean" => true,
        "null" => nil,
        "array" => [1, 2, { "nested" => "value" }],
        "hash" => { "key" => "value" }
      }

      expected = {
        string: "text",
        number: 42,
        boolean: true,
        null: nil,
        array: [1, 2, { nested: "value" }],
        hash: { key: "value" }
      }

      expect(helper.deep_symbolize_keys(input)).to eq(expected)
    end

    it "handles empty hash" do
      input = {}
      expect(helper.deep_symbolize_keys(input)).to eq({})
    end

    it "handles empty array" do
      input = []
      expect(helper.deep_symbolize_keys(input)).to eq([])
    end

    it "leaves symbol keys unchanged" do
      input = { name: "John", "age" => 30 }
      expected = { name: "John", age: 30 }

      expect(helper.deep_symbolize_keys(input)).to eq(expected)
    end

    it "leaves non-hash/array values unchanged" do
      expect(helper.deep_symbolize_keys("string")).to eq("string")
      expect(helper.deep_symbolize_keys(42)).to eq(42)
      expect(helper.deep_symbolize_keys(true)).to eq(true)
      expect(helper.deep_symbolize_keys(nil)).to eq(nil)
    end
  end

  describe "#player_details" do
    let(:client) { instance_double(SleeperApi::Client) }
    let(:helper) { dummy_class.new(client) }

    context "when player exists" do
      let(:player_data) do
        {
          "player_id" => "1234",
          "first_name" => "John",
          "last_name" => "Doe",
          "position" => "QB",
          "team" => "TB"
        }
      end

      before do
        allow(client).to receive(:get_player_by_id).and_return(player_data)
      end

      it "returns symbolized player data" do
        expected = {
          player_id: "1234",
          first_name: "John",
          last_name: "Doe",
          position: "QB",
          team: "TB"
        }

        expect(helper.player_details("1234")).to eq(expected)
      end
    end

    context "when player does not exist" do
      before do
        allow(client).to receive(:get_player_by_id).and_return(nil)
      end

      it "returns nil" do
        expect(helper.player_details("9999")).to be_nil
      end
    end

    context "when client is not available" do
      let(:helper) { dummy_class.new(nil) }

      it "raises NoMethodError when trying to call client method" do
        expect { helper.player_details("1234") }.to raise_error(NoMethodError)
      end
    end
  end
end
