# Message types:
# 0: Payload
# 1: Finished (Fin)
# 2: Finished Acknowledgement (FinAck)
# 3: Keepalive

class Message
  attr_reader :id, :type, :data, :size

  PAYLOAD   = 0
  FIN       = 1
  FINACK    = 2
  KEEPALIVE = 3

  def initialize(type = PAYLOAD, id = nil)
    @id   = id
    @size = nil
    @type = type
    @data = ""
  end

  def read_from_peer(socket)
    if @size.nil?
      @data << socket.read_nonblock(6)
      if @data.size >= 6
        @size = @data[0..2].unpack("n")[0]
        @type = @data[2..4].unpack("n")[0]
        @id   = @data[4..6].unpack("n")[0]
        $stderr.puts("peer message header read.  size is #{@size} and type is #{@type}")
        return unless payload?
      end
    else
      raise "wtf size" if @size < 6
      @data << socket.read_nonblock([4096,@size - @data.size].min)
      $stderr.puts "reading from peer. data size is #{@data.size}"
    end
    socket.flush
  end

  def read_complete?
    @size == @data.size
  end

  def payload?
    @type == PAYLOAD ? true : false
  end

  def fin?
    @type == FIN ? true : false
  end

  def finack?
    @type == FINACK ? true : false
  end

  def keepalive?
    @type == KEEPALIVE ? true : false
  end

  def write_to_client(socket)
    socket.write(@data[6..-1])
    socket.flush
    $stderr.puts("#{@data[6..-1].size} bytes written to client")
  rescue Errno::EPIPE => e
    $stderr.puts("error writing to client")
  end

  def read_from_client(socket)
    @data = socket.read_nonblock(4096)
    @size = @data.size + 6
    $stderr.puts("#{@data.size} bytes read from client")
  rescue Errno::ECONNRESET => e
    $stderr.puts("client closed")
  end

  def write_to_peer(socket)
    @size = @data.size + 6 if @size.nil?
    $stderr.puts("writing size #{@size} to peer")
    socket.write([@size].pack("n") + [@type].pack("n") + [@id].pack("n") + @data)
    $stderr.puts("wrote size #{@size} and type #{@type} to peer")
    socket.flush
  rescue Exception => e
    $stderr.puts "EXCEPTION WRITING TO PEER #{e.message}"
  end
end

