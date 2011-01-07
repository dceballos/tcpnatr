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
              $stderr.puts "b4 writing to peer"
              @writemsg.write_to_peer(@peer_socket)
              $stderr.puts "b4 writing to peer"
            else
              @readmsg ||= Message.new
              @readmsg.read_from_peer(@peer_socket)
              if @readmsg.read_complete?
                if @readmsg.error?
                  $stderr.puts "readmsg error, cleaning peer socket"
                  clean_peer
                  break
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
    rescue EOFError
      $stderr.puts "EOF error!"
      clean_peer
    rescue Errno::ECONNRESET, Errno::EPIPE, IOError, Errno::EAGAIN, Timeout::Error => e
      $stderr.puts e.message
      clean_peer
    end
  end

  def clean_peer
    $stderr.puts "sending error message to peer"
    @errormsg = Message.new(1)
    @errormsg.write_to_peer(@peer_socket)

    while (true)
      begin
        timeout(1) do
          sockets = IO.select([@peer_socket])
          @readmsg ||= Message.new
          $stderr.puts "peer still sending"
          @readmsg.read_from_peer(@peer_socket)
          $stderr.puts @readmsg.data.to_hex
          if @readmsg.read_complete?
            $stderr.puts "flushing peer socket"
            if @readmsg.error?
              $stderr.puts "received fin from peer. closing client"
              @client_socket.close
              @readmsg = nil
              break
            end
          end
          @readmsg = nil
        end
      rescue Timeout::Error
        $stderr.puts "timeout error cleaning"
        break
      end
    end
  end
end

if $0 == __FILE__
  GatewayServer.new(8080).start
end
