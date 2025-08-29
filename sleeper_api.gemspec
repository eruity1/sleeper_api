# frozen_string_literal: true

require_relative "lib/sleeper_api/version"

Gem::Specification.new do |spec|
  spec.name = "sleeper_api"
  spec.version = SleeperApi::VERSION
  spec.authors = ["Eruity1"]
  spec.email = ["ethanruity@icloud.com"]

  spec.summary = "Ruby wrapper for the Sleeper fantast sports API"
  spec.description = "A comprehensive Ruby gem for interacting with Sleeper's fantasy football API, including leagues, users, drafts, and matchups."
  spec.homepage = "https://github.com/eruity1/sleeper_api"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/eruity1/sleeper_api"
  spec.metadata["changelog_uri"] = "https://github.com/eruity1/sleeper_api/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  all_files = `git ls-files`.split("\n")
  test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  spec.files = all_files - test_files

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
