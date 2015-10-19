require "secure_random"
require "http"
require "json"

abstract class DDP::BaseConnection
  macro inherited
    HANDLERS = {} of String => Symbol
  end

  class Error < Exception
    def initialize(message)
      super("failed connecting - #{message}")
    end
  end

  class UnexpectedResponseError < Exception
    def initialize(expected, message)
      super("unexpected response '#{message["msg"]?}', expected '#{expected}' - #{message}")
    end
  end

  class ReceiveError < Exception
    def initialize(message)
      super("failed receiving message - #{message}")
    end
  end

  alias Opcode = HTTP::WebSocket::Opcode

  SUPPORT = ["1"]

  getter session
  getter! message

  macro on(message_type)
    {% handler = "#{message_type.id}_handler_#{HANDLERS.size}".id %}
    def {{handler}}
      {{yield}}
    end

    {% HANDLERS[message_type.id.stringify] = handler.symbolize %}
  end

  def initialize(@web_socket)
    @method_callbacks = {} of String => Hash(String, JSON::Type)? ->
    connect
  end

  def self.open(host, path = "/websocket", port = nil, ssl = false)
    web_socket = HTTP::WebSocket.open(host, path, port, ssl)
    new(web_socket)
  end

  private def connect(version = SUPPORT.first, session = nil)
    fields = { version: version, support: SUPPORT }
    fields[:session] = session if session

    legacy_message_received = false
    loop do
      send("connect", fields)
      case(receive)
      when "connected"
        @session = message["session"] as String
        break
      when "failed"
        unless SUPPORT.includes?(message["version"]?)
          raise Error.new("unsupported version #{message["version"]?}")
        end
        version = message["version"]
      else
        if legacy_message_received
          raise UnexpectedResponseError.new("connected | failed", message)
        end
        # ignore legacy message
        legacy_message_received = true
      end
    end
  end

  def reconnect(version = SUPPORT.first)
    session = self.session
    raise Error.new("can't reconnect without a session id") unless session
    connect(version, session)
  end

  def call(method : String, *params)
    send("method", { method: method, params: params.to_a })
    case(receive)
    when "result"
      if error = message["error"]?
        raise DDP::Error.new(error as Hash)
      end
      yield(message["result"]?)
    else
      raise UnexpectedResponseError.new("result", message)
    end
  end

  def subscribe(name, *params)
    id = SecureRandom.uuid
    send("sub", {id: id, name: name, params: params.to_a})
    id
  end

  def unsubscribe(id)
    send("unsub", {id: id})
  end

  def receive
    io = StringIO.new
    loop do
      info = receive_frame(io)
      case info.opcode
      when Opcode::TEXT then break
      when Opcode::PING
        @web_socket.send(io.to_slice, Opcode::PONG, masked: true)
      when Opcode::CLOSE
        @web_socket.send(io.to_slice, Opcode::CLOSE, masked: true)
        raise ReceiveError.new("connection closed")
      end

      io.clear
    end
    @message = JSON.parse(io.to_s) as Hash
    message["msg"]? unless handle_message(message["msg"]?) 
  end

  macro def handle_message(type) : Bool
    case(type)
    {% for message_type, handler in HANDLERS %}
    when {{message_type}}
      {{handler.id}}
      true
    {% end %}
    else
      false
    end
  end

  private def send(message, fields)
    @web_socket.send(fields.merge({msg: message}).to_json, masked: true)
  end

  private def send(message)
    @web_socket.send({msg: message}.to_json, masked: true)
  end

  private def handle(message)
    msg = message[:msg]?
    raise ReceiveError.new("unexpected message: #{message}") unless msg
    @handlers[msg].call(message)
  end

  private def receive_frame(io)
    buffer :: UInt8[1024]
    while info = @web_socket.receive(buffer.to_slice)
      io.write(buffer.to_slice[0, info.size])
      break if info.final
    end

    info
  end
end
