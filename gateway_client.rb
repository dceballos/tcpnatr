require 'peer'

class GatewayClient
  attr_reader(:port, :stunt_socket, :client)

  def initialize(port)
    @port = port
  end

  def get_client_socket
    @client_socket = TCPSocket.new('localhost', port)
  end

  def start
    $stderr.puts "staring stunt procedure\n"
    start_stunt

    begin
      get_client_socket
      while (sockets = IO.select([@stunt_socket, @client_socket]))
        sockets = sockets[0]
        sockets.each do |socket|                                                   
          data = socket.readpartial(512)
          if socket == @client_socket
            $stderr.puts "reading from client socket, writing to peer"
            @stunt_socket.write data
            @stunt_socket.flush
          else
            $stderr.puts "reading from peer socket, writing to client"
            @client_socket.write data
            @client_socket.flush
          end
        end
      end
    rescue Exception => e
      $stderr.puts e.message
      @client_socket.close
      retry
    rescue EOFError
      $stderr.puts "closing client socket"
      @client_socket.close
      @stunt_socket.flush
      retry
    end
  end

  def start_stunt
    port_client   = PortClient.new("blastmefy.net:2000")
    @stunt_socket = Peer.new(port_client).start("testy", 2005)
  end
end

if $0 == __FILE__
  GatewayClient.new(3001).start
end
