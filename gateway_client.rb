require 'peer'
require 'peer_server'
require 'timeout'
require 'fcntl'

class GatewayClient
  attr_reader(:port, :host, :peer_socket, :client)

  def initialize(host, port)
    @host = host
    @port = port
  end

  def start_stunt
    port_client   = PortClient.new("blastmefy.net:2000")
    @peer_socket  = PeerServer.new(port_client).start("testy", 2002)
    @peer_socket.fcntl(6, Process.pid)
  end

  def start
    $stderr.puts "staring stunt procedure\n"
    start_stunt

    trap("URG") do
      raise Sigurg
    end

    while (true)
      handle_accept
    end
  end

  def handle_accept
    begin
      @client_socket = TCPSocket.new(host, port)
      while (sockets = IO.select([@peer_socket, @client_socket]))
        timeout(1) do
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
    rescue IOError, Errno::ECONNRESET, Timeout::Error => e
      $stderr.puts e.message
      clean_state
      @peer_socket.send("e", Socket::MSG_OOB)
    rescue Sigurg
      clean_state
    end
  end

  def clean_state
    $stderr.puts "handling sirgurg"
    begin
      $stderr.puts "before first select"
      timeout(0.5) do
        while (socket = IO.select([@peer_socket]))
          data = socket[0][0].readpartial(4096)
          $stderr.puts "FLUSHING #{data}"
          @peer_socket.flush
        end
      end
    rescue Timeout::Error => e
      $stderr.puts e.message
    rescue EOFError, Errno::EPIPE => e
      $stderr.puts e.message
      retry
    ensure
      @client_socket.close unless @client_socket.closed?
      @peer_socket.flush
    end
  end
end

class Sigurg < Exception
end

if $0 == __FILE__
  GatewayClient.new('localhost', 3001).start
end
