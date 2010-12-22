require 'peer'

class GatewayClient
  attr_reader(:port, :stunt_socket, :client)

  def initialize(port)
    @port = port
  end

  def start
    $stderr.puts "staring stunt procedure\n"
    start_stunt

    while (request = @stunt_socket.read)
      client = TCPSocket.open("localhost", port)
      client.write(request)
      @stunt_socket.write(client.read)
      @stunt_socket.flush
      client.flush
      client.close
    end
  end

  def start_stunt
    port_client   = PortClient.new("blastmefy.net:2000")
    @stunt_socket = PeerServer.new(port_client).start("testy", 2008)
  end
end

if $0 == __FILE__
  GatewayClient.new(3001).start
end
