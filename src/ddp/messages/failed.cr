require "../message"

module DDP
  class Failed < Message
    json_mapping({
      type: { key: "msg", type: String },
      version: String
    }, true)
  end
end
