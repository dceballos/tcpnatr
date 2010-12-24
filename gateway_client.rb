require 'peer'
require 'peer_server'
require 'timeout'

class GatewayClient
  attr_reader(:port, :host, :peer_socket, :client)

  def initialize(host, port)
    @host = host
    @port = port
  end

  def start_stunt
    port_client   = PortClient.new("blastmefy.net:2000")
    @peer_socket  = Peer.new(port_client).start("testy", 2001)
  end

  def start
    $stderr.puts "staring stunt procedure\n"
    start_stunt

    while (IO.select([@peer_socket]))
      handle_accept
    end
  end

  def handle_accept
    begin
      @client_socket = TCPSocket.new(host, port)
      while (sockets = IO.select([@peer_socket, @client_socket]))
        timeout(10) do
          sockets[0].each do |socket|                                                   
            data = socket.readpartial(4096)
            if socket == @client_socket
              $stderr.puts "reading from client socket, writing to peer"
              @peer_socket.write data
              $stderr.puts data
              @peer_socket.flush
            else
              $stderr.puts "reading from peer socket, writing to client"
              @client_socket.write data
              $stderr.puts data
              @client_socket.flush
            end
          end
        end
      end
    rescue EOFError, Timeout::Error => e
      $stderr.puts e.message
      @peer_socket.flush
      @client_socket.flush
      @client_socket.close
    rescue IOError, Errno::ECONNRESET => e
      $stderr.puts e.message
      @peer_socket.flush
      @client_socket.close
    end
  end
end

if $0 == __FILE__
  GatewayClient.new('localhost', 3001).start
end
