require "../spec_helper.cr"

module DDP
  describe Connect do
    describe "#to_json" do
      it "returns a correct json representation for a default connect" do
        msg = Connect.new
        JSON.parse(msg.to_json).should eq({
          "msg" => "connect",
          "version" => "1"
        })
      end

      it "returns a correct json representation for set options" do
        msg = Connect.new(session: "foo", version: "2", support: ["2", "1"])
        JSON.parse(msg.to_json).should eq({
          "msg" => "connect",
          "session" => "foo",
          "version" => "2",
          "support" => ["2", "1"]
        })
      end
    end
  end
end
