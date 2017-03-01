require "bundler/setup"
require "rack"
require "rack/handler/puma"
require "faye/websocket"

class PollerResponse
  def self.start
    Thread.new do
      sleep 5
      "Done"
    end
  end
end

class FakeEM
  def self.run
    proxy = Proxy.new
    Thread.new do
      res = yield
      proxy.resolve(res)
    end
    proxy
  end

  class Proxy
    include MonitorMixin

    def initialize
      @handlers = []
      @res = nil
      @done = false
      super()
    end

    def then(&block)
      synchronize do
        if @done
          block.call(@res)
        else
          @handlers << block
        end
      end
    end

    def resolve(res)
      synchronize do
        @res = res
        @done = true
        @handlers.each do |hand|
          hand.call(res)
        end
      end
    end
  end
end

def handle_ws(env)
  ws = Faye::WebSocket.new(env)

  ws.on :open do |event|
    sleep 2
    ws.send("ping")
  end


  ws.on :message do |event|
    sleep 2
    ws.send("pong")
  end

  ws.on :close do |event|
    p [:close, event.code, event.reason]
    ws = nil
  end

  ws.rack_response
end

def handle_http(env)
  case env["PATH_INFO"]
  when "/poller.html"
    ['200', {'Content-Type' => 'text/html'}, [File.read("poller.html")]]
  when "/poll"
    @work ||= PollerResponse.start
    body = @work.alive? ? "Not done" : "Done"
    ['200', {'Content-Type' => 'application/text'}, [body]]
  when "/long_poller.html"
    ['200', {'Content-Type' => 'text/html'}, [File.read("long_poller.html")]]
  when "/long_poll"
    q = Queue.new
    em = FakeEM.run { PollerResponse.start.value }
    em.then { |res| q.enq(res) }
    # I'd have to do something trickier to hold the connection properly,
    # so let's just sleep
    body = q.deq
    ['200', {'Content-Type' => 'application/text'}, [body]]
  when "/websocket.html"
    ['200', {'Content-Type' => 'text/html'}, [File.read("websocket.html")]]
  end
end

app = Proc.new do |env|
  if Faye::WebSocket.websocket?(env)
    handle_ws(env)
  else
    handle_http(env)
  end
end

Rack::Handler::Puma.run app, Port: 10011
