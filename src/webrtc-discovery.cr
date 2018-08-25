require "env"
require "http/server"
require "http/web_socket"

APP_PORT = ENV.fetch("APP_PORT", "8000").to_i

discovery_cache = {} of String => Set(String)

ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
    ws.on_message do |str|
        # TODO this is ipv4
        ping_match = str.match /ping from (\d+\.\d+\.\d+\.\d+)/
        unless ping_match.nil?
            public_ip = ctx.request.host.as(String)
            local_ip = ping_match[1]

            puts ">> ping from #{public_ip} with #{local_ip}"
            discovery_cache[public_ip] = Set(String).new unless discovery_cache.has_key? public_ip
            discovery_cache[public_ip] << local_ip


            discovery_cache[public_ip].each do |v|
                next if v == local_ip

                ws.send "pong from #{v}"
                puts "<< pong from #{public_ip} with #{v}"
            end
        end
    end

    ws.on_close do |str|
        ping_match = str.match /bye from (\d+\.\d+\.\d+\.\d+)/
        unless ping_match.nil?
            public_ip = ctx.request.host.as(String)
            local_ip = ping_match[1]

            discovery_cache[public_ip].delete local_ip
            discovery_cache.delete(public_ip) if discovery_cache[public_ip].empty?
            puts "<< bye from #{public_ip} with #{local_ip}"
        end
    end
end

server = HTTP::Server.new [ ws_handler ]

puts "Listening on 0.0.0.0:#{APP_PORT}"
server.listen "0.0.0.0", APP_PORT
