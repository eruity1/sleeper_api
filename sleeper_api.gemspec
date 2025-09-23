# frozen_string_literal: true

require_relative "lib/sleeper_api/version"

Gem::Specification.new do |spec|
  spec.name = "sleeper_api"
  spec.version = SleeperApi::VERSION
  spec.authors = ["Eruity1"]
  spec.email = ["ethanruity@icloud.com"]

  spec.summary = "Comprehensive Ruby wrapper for the Sleeper's fantasy sports API"
  spec.description = "A comprehensive Ruby gem for interacting with Sleeper's fantasy football API. Features include league management, user profiles, draft data, matchups, transactions, player data with caching, and comprehensive error handling. Built with performance and reliability in mind for production applications."
  spec.homepage = "https://github.com/eruity1/sleeper_api"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/README.md"


  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  all_files = `git ls-files`.split("\n")
  test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  ci_files = `git ls-files -- .github/*`.split("\n")

  spec.files = all_files - test_files
  spec.files += ["sig/sleeper_api.rbs"]

  spec.files -= [
    "players_cache.json",
    "coverage/",
    ".rspec_status",
  ].select { |file| File.exist?(file) }

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "httparty", "~> 0.21"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.80"
  spec.add_development_dependency "rubocop-performance", "~> 1.26"
  spec.add_development_dependency "rubocop-rspec", "~> 3.7"
  spec.add_development_dependency "simplecov", "~> 0.21"
  spec.add_development_dependency "webmock", "~> 3.14"
end
