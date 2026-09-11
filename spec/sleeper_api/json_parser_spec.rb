# frozen_string_literal: true

RSpec.describe SleeperApi::JsonParser do
  describe "the shapes Sleeper actually sends" do
    it "parses an object" do
      expect(described_class.call('{"user_id":"123"}', :json)).to eq("user_id" => "123")
    end

    it "parses an array, which /schedule answers with" do
      expect(described_class.call('[{"week":1}]', :json)).to eq([{ "week" => 1 }])
    end

    # The case `quirks_mode: true` was there for, and the reason dropping it
    # needed checking rather than assuming: Sleeper answers an unknown username
    # with a literal `null` rather than a 404. Both json majors parse it
    # correctly without the flag.
    it "parses the bare null an unknown username answers with" do
      expect(described_class.call("null", :json)).to be_nil
    end

    # Inherited from HTTParty::Parser, and the reason this is a subclass rather
    # than a lambda: a blank body never reaches #json at all.
    it "leaves an empty body to the superclass" do
      expect(described_class.call("", :json)).to be_nil
    end
  end

  # The actual regression, and the only assertion here that can fail on a json
  # that still accepts the flag. Everything above passes on json 2 whether or
  # not this fix is present — the crash only exists from json 3.0 — so a
  # behavioural test would be green on the very version the bug is absent from
  # and prove nothing. This watches the call instead.
  it "does not pass quirks_mode, which json 3.0 removed" do
    allow(JSON).to receive(:parse).and_call_original

    described_class.call('{"a":1}', :json)

    expect(JSON).to have_received(:parse).with('{"a":1}', allow_nan: true)
  end

  # Without this the class is correct and unused, which is the same outcome as
  # not having written it.
  it "is the parser the client parses with" do
    expect(SleeperApi::Client.parser).to eq(described_class)
  end
end
