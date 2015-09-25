require "../message"

module DDP
  class Connected < Message
    json_mapping({
      type: { key: "msg", type: String },
      session: String
    }, true)
  end
end
