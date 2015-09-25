require "../message"

module DDP
  class Connect < Message
    json_mapping({
      type: { key: "msg", type: String },
      session_key: { key: "session", type: String, nilable: true },
      version: { type: String },
      support: { type: Array(String), nilable: true }
    }, true)

    def initialize(@session_key = nil, @version = "1", @support = nil : Array(String)?)
      super("connect")
    end
  end
end
