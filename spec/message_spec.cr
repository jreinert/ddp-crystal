require "./spec_helper"

module DDP
  class TestMessage < Message
    json_mapping({
      foo: String
      bar: String
    })
  end

  describe Message do
    describe ".parse" do
      it "returns an instance of the message type passed in the json" do
        msg = Message.parse(%({"msg": "test_message", "foo": "bar", "bar": "baz"}))
        msg.should be_a(TestMessage)
        raise "foo" unless msg.is_a?(TestMessage)
        msg.foo.should eq("bar")
        msg.bar.should eq("baz")
      end
    end
  end
end
