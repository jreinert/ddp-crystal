require "json"

module DDP
  abstract class Message
    def initialize(@type)
    end

    macro def self.parse(json) : Message
      hash = JSON.parse(json)
      raise "malformed json: #{json}" unless hash.is_a?(Hash)
      type = hash["msg"]?
      raise "malformed message: #{json}" unless type
      case(type)
      {% for subclass in @type.subclasses %}
      when {{subclass.name.split("::").last.underscore}}
        {{subclass}}.from_json(json)
      {% end %}
      else raise "unknown message type: #{type}"
      end
    end

    def on_response
    end
  end
end
