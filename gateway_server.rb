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
    $stderr.puts "starting stunt procedure\n"
    start_stunt

    @server = TCPServer.new(port)
    $stderr.puts "starting gateway server on port #{port}\n"

    $stderr.puts "handling accept"
    while (@client_socket = server.accept)
      handle_accept
    end
  end

  def handle_accept
    begin
      while (sockets = IO.select([@peer_socket, @client_socket]))
        rsock, _, _ = sockets
        timeout(1) do
          rsock.each do |socket|                                                   
            if socket == @client_socket
              @writemsg = Message.new
              @writemsg.read_from_client(@client_socket)
              @writemsg.write_to_peer(@peer_socket)
            else
              @readmsg ||= Message.new
              @readmsg.read_from_peer(@peer_socket)
              if @readmsg.read_complete?
                if @readmsg.error?
                  if @readmsg.type == 1
                    finack = Message.new(2)
                    finack.write_to_peer(@peer_socket)
                    @client_socket.close unless @client_socket.closed?
                    @readmsg = nil
                    return
                  elsif @readmsg.type == 2
                    @client_socket.close unless @client_socket.closed?
                    @readmsg = nil
                    return
                  end
                end
                $stderr.puts "reading from peer socket, writing to client"
                @readmsg.write_to_client(@client_socket)
                @readmsg = nil
              else
                $stderr.puts "@readmsg has not finished reading.  current size #{@readmsg.data.size}, expected #{@readmsg.size}"
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
    $stderr.puts "sending error message to peer"
    @errormsg = Message.new(1)
    @errormsg.write_to_peer(@peer_socket)

    loop do
      begin
        timeout(0.5) do
          sockets = IO.select([@peer_socket])
          @readmsg ||= Message.new
          @readmsg.read_from_peer(@peer_socket)
          $stderr.puts @readmsg.data.to_hex
          if @readmsg.read_complete?
            if @readmsg.error?
              if @readmsg.type == 2
                $stderr.puts "received fin+ack from peer. closing client"
                @client_socket.close unless @client_socket.closed?
                @readmsg = nil
                return
              end
            end
          end
          @readmsg = nil
        end
      rescue Timeout::Error
        $stderr.puts "timeout select"
        @client_socket.close unless @client_socket.closed?
        return
      end
    end
  end
end

if $0 == __FILE__
  GatewayServer.new(8080).start
end
