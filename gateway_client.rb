require 'peer'
require 'timeout'

class GatewayClient
  attr_reader(:port, :host, :peer_socket, :client)

  def initialize(host, port)
    @host = host
    @port = port
  end

  def start
    $stderr.puts "staring stunt procedure\n"
    start_stunt
    handle_accept
  end

  def handle_accept
    begin
      @client_socket = TCPSocket.new(host, port)
      timeout(10) do
        while (sockets = IO.select([@peer_socket, @client_socket]))
          sockets = sockets[0]
          sockets.each do |socket|                                                   
            data = socket.readpartial(512)
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
    rescue IOError, Errno::ECONNRESET => e
      $stderr.puts e.message
      retry
    rescue EOFError
      $stderr.puts "eof. closing client socket"
      @client_socket.close
      @peer_socket.flush
      retry
    rescue Timeout::Error
      $stderr.puts "timeout. closing client socket"
      @client_socket.close
      @peer_socket.flush
      retry
    end

  end

  def start_stunt
    port_client   = PortClient.new("blastmefy.net:2000")
    @peer_socket  = Peer.new(port_client).start("testy", 2005)
  end
end

if $0 == __FILE__
  GatewayClient.new('localhost', 3001).start
end
