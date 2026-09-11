require "httparty"
require "json"

module SleeperApi
  # HTTParty's JSON parser, minus the one argument that stops it working.
  #
  # HTTParty 0.24.2 parses with `JSON.parse(body, quirks_mode: true,
  # allow_nan: true)`. **json 3.0 removed `quirks_mode`**, so every response
  # this gem parses raises `ArgumentError: unknown keyword: quirks_mode` the
  # moment a consumer resolves json 3 — which is total breakage, not a
  # degradation, and it arrives through a transitive bump nobody asked for.
  # httparty 0.24.2 is the newest release and has no fix.
  #
  # **Dropping the option rather than pinning json is what keeps this the
  # gem's problem instead of its consumers'.** A `json < 3` constraint in the
  # gemspec would fix the same crash by forbidding every app that uses this
  # gem from upgrading json at all, for a flag none of them asked for.
  #
  # `quirks_mode: true` allowed a bare scalar at the top level. That is not
  # academic here — Sleeper answers an unknown username with a literal `null`.
  # Both majors parse that correctly without the flag, checked on 2026-09-11:
  # `JSON.parse("null")` is `nil` under json 2.21.2 and under 3.0.2. The flag
  # has been doing nothing for this gem for some time.
  #
  # A subclass rather than a `parser` lambda, because everything else in
  # `HTTParty::Parser#parse` still applies — the blank-body guard, the format
  # detection, the supported-format table. One method is wrong; one method is
  # overridden.
  class JsonParser < HTTParty::Parser
    def json
      JSON.parse(body, allow_nan: true)
    end
  end
end
