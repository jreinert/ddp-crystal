require "../message"
require "./connected"
require "./failed"

module DDP
  class Connect < Message
    alias Response = Connected | Failed

    json_mapping({
      type: { key: "msg", type: String },
      session: { type: String, nilable: true },
      version: String,
      support: { type: Array(String), nilable: true }
    }, true)

    def initialize(@session = nil, @version = "1", @support = nil : Array(String)?)
      super("connect")
    end
  end
end
