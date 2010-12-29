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

  class Message
    def initialize size = nil
      @size = size
      @data = ""
    end

    def read_from_peer(socket)
      if @size.nil?
        @data << socket.read_nonblock(4096)
        if @data.size >= 4
          @size = @data[0..4].unpack("N")[0]
          $stderr.puts("read size #@size from peer")
        end
      else
        @data << socket.read_nonblock([4096,@size].min)
      end
    end
    def read_complete?
      @size == @data.size
    end

    def write_to_client(socket)
      socket.write(@data[4..-1])
      socket.flush
    end

    def read_from_client(socket)
      @data = socket.read_nonblock(4096)
      @size = @data.size
    end
    def write_to_peer(socket)
      $stderr.puts("writing size #@size to peer")
      socket.write([@size].pack("N"))
      socket.write(@data)
      socket.flush
    end
  end

  def to_hex(str)
    ret = ""
    str.each_byte do |byte|
      ret << byte.to_s(16)
    end
    ret.scan(/.{0,16}/).join("\n")
  end

  def handle_accept
    begin
      @client_socket = TCPSocket.new(host, port)
      while (sockets = IO.select([@peer_socket, @client_socket]))
        timeout(1) do
          sockets[0].each do |socket|                                                   
            if socket == @client_socket
              @writemsg = Message.new
              @writemsg.read_from_client(@client_socket)
              @writemsg.write_to_peer(@client_socket)
            else
              @readmsg ||= Message.new
              @readmsg.read_from_peer(@peer_socket)
              if @readmsg.read_complete?
                @readmsg.write_to_client(@client_socket)
                @readmsg = nil
                $stderr.puts "reading from peer socket, writing to client"
              end
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
    if @readmsg
      while !@readmsg.read_complete? && (socket = IO.select([@peer_socket]))
        @readmsg.read_from_peer(@peer_socket)
      end
      @readmsg = nil
    end
    @client_socket.close unless @client_socket.closed?
  end
end

class Sigurg < Exception
end

if $0 == __FILE__
  GatewayClient.new('localhost', 3001).start
end
