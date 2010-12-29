require 'peer'
require 'peer_server'
require 'timeout'
require 'fcntl'

class GatewayServer
  attr_reader(:port, :peer_socket, :server)

  def initialize(port)
    @port = port
  end

  def start_stunt
    port_client  = PortClient.new("blastmefy.net:2000")
    @peer_socket = Peer.new(port_client).start("testy", 2005)
    @peer_socket.fcntl(8, Process.pid)
  end

  def start
    $stderr.puts "starting stunt procedure\n"
    start_stunt

    @server = TCPServer.new(port)
    $stderr.puts "starting gateway server on port #{port}\n"

    trap("URG") do
      raise Sigurg
    end

    begin
      while (@client_socket = server.accept)
        handle_accept
      end
    rescue Sigurg
      clean_state
      retry
    end
  end

  def handle_accept
    begin
      $stderr.puts "before first select"
      while(sockets = IO.select([@client_socket, @peer_socket]))
        timeout(1) do
          sockets[0].each do |socket|
            data = socket.readpartial(4096)
            if socket == @client_socket
              $stderr.puts "reading from client socket, writing to peer"
              @peer_socket.write data
              @peer_socket.flush
              $stderr.puts data
            else
              $stderr.puts "reading from peer socket, writing to client"
              @client_socket.write data
              @client_socket.flush
              $stderr.puts data
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
    $stderr.puts "handling sigurg"
    begin
      timeout(1) do
        while (socket = IO.select([@peer_socket]))
          data = socket[0][0].readpartial(4096)
          $stderr.puts "FLUSHING #{data}"
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
  GatewayServer.new(8080).start
end
