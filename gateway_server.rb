require 'peer_server'
require 'timeout'

class GatewayServer
  attr_reader(:port, :peer_socket, :server)

  def initialize(port)
    @port = port
  end

  def start_stunt
    port_client  = PortClient.new("blastmefy.net:2000")
    @peer_socket = PeerServer.new(port_client).start("testy", 2005)
  end

  def start
    $stderr.puts "staring stunt procedure\n"
    start_stunt

    @server = TCPServer.new(port)
    $stderr.puts "starting gateway server on port #{port}\n"

    while (@client_socket = server.accept)
      $stderr.puts "handling accept"
      handle_accept
      $stderr.puts "done handling accept"
    end
  end

  def handle_accept
    begin
      timeout(10) do
        while(sockets = IO.select([@client_socket, @peer_socket]))
          sockets[0].each do |socket|
            data = socket.readpartial(512)
            if socket == @client_socket
              $stderr.puts "reading from client socket, writing to peer"
              @peer_socket.write data
              @peer_socket.flush
            else
              $stderr.puts "reading from peer socket, writing to client"
              @client_socket.write data
              @client_socket.flush
            end
          end
        end
      end 
    rescue Timeout::Error
      $stderr.puts "timeout. closing client socket"
      @client_socket.close
      @peer_socket.flush
      retry
    rescue IOError, Errno::ECONNRESET => e
      $stderr.puts e.message
      @peer_socket.flush
    rescue EOFError
      $stderr.puts "eof. closing client socket"
      @client_socket.close
      @peer_socket.flush
    end
  end
end

if $0 == __FILE__
  GatewayServer.new(8080).start
end
