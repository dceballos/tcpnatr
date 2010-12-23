require 'peer_server'

class GatewayServer
  attr_reader(:port, :peer_socket, :server)

  def initialize(port)
    @port = port
  end

  def start_stunt
    port_client  = PortClient.new("blastmefy.net:2000")
    @peer_socket = PeerServer.new(port_client).start("testy", 2001)
  end

  def start
    $stderr.puts "staring stunt procedure\n"
    start_stunt

    @server = TCPServer.new(port)
    $stderr.puts "starting gateway server on port #{port}\n"

    while (socket = server.accept)
      begin
        $stderr.puts "handling accept"
        handle_accept(socket)
        $stderr.puts "done handling accept"
      rescue Exception => e
        socket.close
        puts e.message
      end
    end
  end

  def handle_accept(client_socket)
    while true
      begin
        sockets, dummy, dummy = IO.select([client_socket, @peer_socket])
        sockets.each do |socket|
          data = socket.readpartial(512)
          if socket == client_socket
            $stderr.puts "reading from client socket, writing to peer"
            @peer_socket.write data
            @peer_socket.flush
          else
            $stderr.puts "reading from peer socket, writing to client"
            client_socket.write data
            client_socket.flush
          end
        end 
      rescue EOFError
        $stderr.puts "closing client socket"
        client_socket.close
        @peer_socket.flush
        break
      end
    end
  end
end

if $0 == __FILE__
  GatewayServer.new(8080).start
end
