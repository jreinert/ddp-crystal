require "../spec_helper"
require "http"

class WebSocketMock
  alias PacketInfo = HTTP::WebSocket::PacketInfo
  alias Opcode = HTTP::WebSocket::Opcode

  record Response, payload, opcode
  record Request, payload, masked, opcode

  getter requests

  def initialize(*responses : String)
    initialize(responses.map { |payload| Response.new(payload, Opcode::TEXT) }.to_a)
  end

  def initialize(*responses : Response)
    initialize(responses.to_a)
  end

  def initialize(@responses : Array(Response))
    @requests = [] of Request
  end

  def send(message : String, masked = false)
    send(message.to_slice, Opcode::TEXT, masked)
  end

  def send(message : Slice(UInt8), masked = false)
    send(message, Opcode::BINARY, masked)
  end

  def send(message : Slice(UInt8), opcode : Opcode, masked = false)
    @requests << Request.new(String.new(message), masked, opcode)
  end

  def receive(buffer : Slice(UInt8))
    response = @responses.shift
    slice = response.payload.to_slice
    buffer.copy_from(slice.pointer(slice.size), slice.size)
    PacketInfo.new(response.opcode, slice.size, true)
  end
end

private def connecting_websocket
  WebSocketMock.new(%({"msg":"connected","session":"foobar"}))
end

private def failing_websocket
  WebSocketMock.new(%({"msg":"failed","version":"2"}))
end

private def failing_websocket_v1
  WebSocketMock.new(
    %({"msg":"failed","version":"1"}),
    %({"msg":"connected","session":"foo"})
  )
end

private def pinging_websocket
  WebSocketMock.new(
    %({"msg":"connected","session":"foobar"}),
    %({"msg":"ping"}),
    %({"msg":"ping","id":"foobar"})
  )
end

private def raw_pinging_websocket
  WebSocketMock.new(
    WebSocketMock::Response.new(%({"msg":"connected","session":"foobar"}), WebSocketMock::Opcode::TEXT),
    WebSocketMock::Response.new("", WebSocketMock::Opcode::PING),
    WebSocketMock::Response.new("test", WebSocketMock::Opcode::PING),
    WebSocketMock::Response.new(%({"msg":"foo"}), WebSocketMock::Opcode::TEXT),
  )
end

private def method_websocket
  WebSocketMock.new(
    %({"msg":"connected","session":"foobar"}),
    %({"msg":"result", "result": "foobar"}),
    %({"msg":"result","error": {"error": "some_error_id", "reason": "some reason", "details": "some details"}})
  )
end

module DDP
  describe Connection do
    describe ".new" do
      it "sends a connect message to the websocket" do
        ws = connecting_websocket
        Connection.new(ws)
        request = ws.requests.last
        request.opcode.should eq(WebSocketMock::Opcode::TEXT)
        JSON.parse(request.payload).should eq(
          {"msg": "connect", "version": "1", "support": ["1"]}
        )
      end

      it "sets the session id" do
        ws = connecting_websocket
        connection = Connection.new(ws)
        connection.session.should eq("foobar")
      end

      it "raises if receives a failed message" do
        ws = failing_websocket
        expect_raises Connection::Error, "failed connecting - unsupported version 2" do
          Connection.new(ws)
        end
      end

      it "connects with a version returned by failed if it's supported" do
        ws = failing_websocket_v1
        connection = Connection.new(ws)
        request = ws.requests.last
        JSON.parse(request.payload).should eq(
          {"msg": "connect", "version": "1", "support": ["1"]}
        )
        connection.session.should eq("foo")
      end
    end

    describe "send" do
      it "masks all messages" do
        ws = pinging_websocket
        Connection.new(ws)
        ws.requests.each do |request|
          request.masked.should be_true
        end
      end
    end

    describe "receive" do
      it "handles ping messages correctly" do
        ws = pinging_websocket
        connection = Connection.new(ws)
        connection.receive
        pong = ws.requests.last
        JSON.parse(pong.payload).should eq(
          {"msg": "pong"}
        )

        connection.receive
        pong = ws.requests.last
        JSON.parse(pong.payload).should eq(
          {"msg": "pong", "id": "foobar"}
        )
      end

      it "handles raw ping messages correctly" do
        ws = raw_pinging_websocket
        connection = Connection.new(ws)
        connection.receive
        pongs = ws.requests[1..2]
        pongs[0].payload.empty?.should be_true
        pongs[0].opcode.should eq(WebSocketMock::Opcode::PONG)
        pongs[1].payload.should eq("test")
        pongs[1].opcode.should eq(WebSocketMock::Opcode::PONG)
      end
    end

    describe "call" do
      it "sends a method message to the websocket" do
        ws = method_websocket
        connection = Connection.new(ws)
        connection.call("foobar", "foo", 1, ["baz"]) do |result|
          result.should eq("foobar")
        end
        JSON.parse(ws.requests.last.payload).should eq(
          { "msg": "method", "method": "foobar", "params": ["foo", 1, ["baz"]] }
        )
      end

      it "raises if the response has an error" do
        ws = method_websocket
        connection = Connection.new(ws)
        connection.call("foobar", "foo", "bar", "baz") {}
        expect_raises DDP::Error, "some_error_id - some reason (some details)" do
          connection.call("foobar", "foo", "bar", "baz") {}
        end
      end
    end

    describe "subscribe" do
      it "sends a sub message to the websocket" do
        ws = connecting_websocket
        connection = Connection.new(ws)
        id = connection.subscribe("foobar", "foo", 1, ["baz"])
        JSON.parse(ws.requests.last.payload).should eq(
          { "msg": "sub", "name": "foobar", "params": ["foo", 1, ["baz"]], "id": id }
        )
      end
    end

    describe "unsubscribe" do
      it "sends a unsub message to the websocket" do
        ws = connecting_websocket
        connection = Connection.new(ws)
        id = connection.subscribe("foobar", "foo", 1, ["baz"])
        connection.unsubscribe(id)
        JSON.parse(ws.requests.last.payload).should eq(
          { "msg": "unsub", "id": id }
        )
      end
    end
  end
end
