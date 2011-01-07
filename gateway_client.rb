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

class GatewayClient
  attr_reader(:port, :host, :peer_socket, :client)

  def initialize(host, port)
    @host = host
    @port = port
  end

  def start_stunt
    port_client   = PortClient.new("blastmefy.net:2000")
    @peer_socket  = PeerServer.new(port_client).start("testy", 2002)
  end

  def start
    $stderr.puts "staring stunt procedure"
    start_stunt

    while (true)
      @client_socket = TCPSocket.new(host, port)
      handle_accept
    end
  end

  def handle_accept
    begin
      $stderr.puts("handling accept...")
      while (sockets = IO.select([@peer_socket, @client_socket]))
        $stderr.puts("accepted #{sockets[0].size} sockets")
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
                $stderr.puts "read not complete"
              end
            end
          end
        end
      end
    rescue EOFError, Errno::ECONNRESET, IOError, Errno::EAGAIN, Timeout::Error => e
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
              $stderr.puts "received fin from peer. closing client"
              @client_socket.close unless @client_socket.closed?
              @readmsg = nil
              return
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
  GatewayClient.new('localhost', 3001).start
end
