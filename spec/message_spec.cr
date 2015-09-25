require "./spec_helper"

module DDP
  describe Message do
    describe ".parse" do
      it "returns an instance of the message type passed in the json" do
        msg = Message.parse(%({"msg": "connect", "version": "1"}))
        msg.should be_a(Connect)
      end
    end
  end
end
