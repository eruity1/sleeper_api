require "json"

module SleeperApi
  class Cache
    def initialize
      @file_path = "players_cache.json"
      @ttl = 24 * 60 * 60
      @cache = nil
    end

    def read
      return @cache if @cache && !expired?

      return nil unless File.exist?(@file_path)
      return nil if expired?

      @cache = JSON.parse(File.read(@file_path))
      @cache
    rescue JSON::ParserError
      nil
    end

    def write(data)
      File.write(@file_path, JSON.pretty_generate(data))
    end

    private

    def expired?
      File.mtime(@file_path) < Time.now - @ttl
    end
  end
end
