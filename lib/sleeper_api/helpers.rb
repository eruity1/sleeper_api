module SleeperApi
  module Helpers
    def deep_symbolize_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), result|
          key = k.is_a?(String) ? k.to_sym : k
          result[key] = deep_symbolize_keys(v)
        end
      when Array
        obj.map { |el| deep_symbolize_keys(el) }
      else
        obj
      end
    end

    def player_details(player_id)
      player = @client.get_player_by_id(player_id)
      return nil unless player

      deep_symbolize_keys(player)
    end
  end
end
