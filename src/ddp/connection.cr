require "./error"
require "./base_connection"

class DDP::Connection < DDP::BaseConnection
  on :ping do
    id = message["id"]? as String?
    id ? send("pong", { id: id }) : send("pong")
  end
end
