require 'peer'
require 'peer_server'
require 'timeout'
require 'message'

class String
  def to_hex
    ret = ""
    each_byte do |byte|
      ret << byte.to_s(16)
    end
    ret.scan(/.{0,16}/).join("\n")
  end
end

class GatewayServer
  attr_reader(:port, :peer_socket, :server)

  def initialize(port)
    @port = port
  end

  def start_stunt
    port_client  = PortClient.new("blastmefy.net:2000")
    @peer_socket = Peer.new(port_client).start("testy", 2005)
  end

  def start
    $stderr.puts("starting stunt procedure")
    start_stunt
    @server = TCPServer.new(port)

    $stderr.puts("starting gateway server on port #{port}")
    $stderr.puts("waiting for connections")

    while (@client_socket = server.accept)
      handle_accept
    end
  end

  def handle_accept
    begin
      while (sockets = IO.select([@peer_socket, @client_socket]))
        timeout(1) do
          sockets[0].each do |socket|
            if socket == @client_socket
              @writemsg = Message.new
              @writemsg.read_from_client(@client_socket)
              @writemsg.write_to_peer(@peer_socket)
            else
              @readmsg ||= Message.new
              @readmsg.read_from_peer(@peer_socket)
              if @readmsg.read_complete?
                if @readmsg.fin?
                  if @readmsg.type == 1
                    $stderr.puts("received fin sending finack")
                    finack = Message.new(2)
                    finack.write_to_peer(@peer_socket)
                    @client_socket.close unless @client_socket.closed?
                    @readmsg = nil
                    return
                  elsif @readmsg.type == 2
                    $stderr.puts("received finack")
                    @client_socket.close unless @client_socket.closed?
                    @readmsg = nil
                    return
                  end
                end
                $stderr.puts("reading from peer socket, writing to client")
                @readmsg.write_to_client(@client_socket)
                @readmsg = nil
              end
            end
          end
        end
      end
    rescue EOFError, Errno::ECONNRESET, Errno::EPIPE, IOError, Errno::EAGAIN, Timeout::Error => e
      $stderr.puts e.message
      finish
    end
  end

  def finish
    $stderr.puts("sending fin")
    fin = Message.new(1)
    fin.write_to_peer(@peer_socket)

    loop do
      begin
        timeout(0.5) do
          sockets = IO.select([@peer_socket])
          @readmsg ||= Message.new
          @readmsg.read_from_peer(@peer_socket)
          if @readmsg.read_complete?
            if @readmsg.fin?
              if @readmsg.type == 2
                $stderr.puts("received finack")
                @client_socket.close unless @client_socket.closed?
                @readmsg = nil
                return
              end
            end
          end
          @readmsg = nil
        end
      rescue Timeout::Error
        $stderr.puts("timeout cleaning socket")
        @client_socket.close unless @client_socket.closed?
        return
      end
    end
  end
end

if $0 == __FILE__
  GatewayServer.new(8080).start
end
