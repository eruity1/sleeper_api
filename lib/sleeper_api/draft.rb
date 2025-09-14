module SleeperApi
  class Draft

    ATTRIBUTES = %w[draft_id created creators draft_order last_message_id last_message_time 
                    last_picked league_id settings season season_type metadata slot_to_roster_id
                    sport start_time status type].freeze

    attr_reader :draft_id, :picks, :traded_picks

    private

    def deep_symbolize_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), result|
          key = k.is_a?(String) ? k.to_sym : k
          result[key] = deep_symbolize_keys(v)
        end
      when Array
        obj.map { |e| deep_symbolize_keys(e) }
      else
        obj
      end
    end
  end
end