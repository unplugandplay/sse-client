require "./sse-client.cr"
p "ici"


es = SSE::EventSource.new("127.0.0.1:8888")
p es.inspect
es.on("message") do |data|
  p "found a message event #{data}"
end

con = es.start