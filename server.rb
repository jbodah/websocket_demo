require "rack"

class PollerResponse
  def self.start
    Thread.new do
      sleep 10
      "Done"
    end
  end
end

app = Proc.new do |env|
  case env["PATH_INFO"]
  when "/poll"
    @work ||= PollerResponse.start
    body = @work.alive? ? "Not done" : "Done"
    ['200', {'Content-Type' => 'application/text'}, [body]]
  when "/poller.html"
    ['200', {'Content-Type' => 'text/html'}, [File.read("poller.html")]]
  end
end

Rack::Handler::WEBrick.run app, Port: 10011
