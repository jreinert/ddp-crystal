require "../spec_helper"
require "http"
require "json"

METEOR_HOST = "localhost"
METEOR_PORT = 3000
RECORDS_URL = "http://#{METEOR_HOST}:#{METEOR_PORT}/records"
HEADERS = HTTP::Headers{"Content-Type": "application/json"}

private def create_record(attributes)
  HTTP::Client.post(RECORDS_URL, HEADERS, { record: attributes }.to_json)
end

private def update_record(id, attributes)
  HTTP::Client.put(RECORDS_URL, HEADERS, { id: id, record: attributes }.to_json)
end

private def delete_record(id)
  HTTP::Client.delete(RECORDS_URL, HEADERS, { id: id }.to_json)
end

private def clear_records(id)
  HTTP::Client.post(RECORDS_URL + "/clear", HEADERS)
end

module DDP
  describe Connection do
    describe ".open" do
      it "establishes a connection with meteor" do
        connection = Connection.open(METEOR_HOST, port: METEOR_PORT)
        connection.session.should_not be_nil
      end
    end
  end
end
