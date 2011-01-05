require 'peer'
require 'peer_server'
require 'timeout'
require 'fcntl'

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
    @peer_socket  = PeerServer.new(port_client).start("testy", 2004)
  end

  def start
    $stderr.puts "staring stunt procedure"
    start_stunt

    while (true)
      @client_socket = TCPSocket.new(host, port)
      handle_accept
    end
  end

  # Message types:
  # 0: Data
  # 1: Error

  class Message
    def initialize type = 0, size = nil
      @size = size
      @type = type
      @data = ""
    end

    def read_from_peer(socket)
      if @size.nil?
        @data << socket.read_nonblock(4)
        if @data.size >= 4
          @size = @data[0..2].unpack("N")[0]
          @type = @data[2..4].unpack("N")[0]
          $stderr.puts("read size #@size from peer")
        end
      else
        raise "wtf" if @size < 4
        @data << socket.read_nonblock([4096,@size - @data.size].min)
      end
      socket.flush
    end

    def read_complete?
      @size == @data.size
    end

    def error?
      @type == 1 ? true : false
    end

    def write_to_client(socket)
      socket.write(@data[4..-1])
      socket.flush
      $stderr.puts("#{@data[4..-1].size} bytes written to client")
    end

    def read_from_client(socket)
      @data = socket.read_nonblock(4096)
      @size = @data.size + 4
      $stderr.puts("#{@data.size} bytes read from client")
    rescue Errno::ECONNRESET => e
      $stderr.puts("client closed")
      raise e
    end

    def write_to_peer(socket)
      $stderr.puts("writing size #{@size} to peer")
      socket.write([@size].pack("N") + @data)
      $stderr.puts("wrote size #{@size} to peer")
      socket.flush
    end
  end

  def handle_accept
    begin
      $stderr.puts("handling accept...")
      while (sockets = IO.select([@peer_socket, @client_socket]))
        $stderr.puts("accepted #{sockets[0].size} sockets")
        $stderr.flush
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
                  $stderr.puts "error in socket, aborting client write"
                  @client_socket.close unless @client_socket.eof?
                  @readmsg = nil
                  break
                end
                $stderr.puts "reading from peer socket, writing to client"
                @readmsg.write_to_client(@client_socket)
                @readmsg = nil
              end
            end
          end
        end
      end
    rescue IOError, Errno::ECONNRESET, Timeout::Error => e
      $stderr.puts e.message
      if @client_socket.eof?
        $stderr.puts "sending error message to peer"
        @errormsg = Message.new(1)
        @errormsg.write_to_peer(@peer_socket)
      end
    end
  end
end

if $0 == __FILE__
  GatewayClient.new('localhost', 3001).start
end
