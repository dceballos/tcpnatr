require 'peer_server'

class GatewayServer
  attr_reader(:port, :stunt_socket, :server)

  def initialize(port)
    @port = port
  end

  def start
    $stderr.puts "staring stunt procedure\n"
    start_stunt

    @server = TCPServer.new(port)
    $stderr.puts "starting gateway server on port #{port}\n"

    while (socket = server.accept)
      handle_accept(socket)
    end
  end

  def start_stunt
    port_client   = PortClient.new("blastmefy.net:2000")
    @stunt_socket = PeerServer.new(port_client).start("testy", 2008)
  end

  def handle_accept(socket)
    @stunt_socket.write(socket.read)
    socket.write(@stunt_socket.read)
    @stunt_socket.flush
    socket.flush
    socket.close
  end
end

if $0 == __FILE__
  GatewayServer.new(8080).start
end
