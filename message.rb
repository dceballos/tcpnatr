# Message types:
# 0: Data
# 1: Finished (Fin)
# 2: Finished Acknowledgement (FinAck)

class Message
  attr_reader :type, :data, :size

  def initialize type = 0
    @size = nil
    @type = type
    @data = ""
  end

  def read_from_peer(socket)
    if @size.nil?
      @data << socket.read_nonblock(4)
      if @data.size >= 4
        @size = @data[0..2].unpack("n")[0]
        @type = @data[2..4].unpack("n")[0]
        $stderr.puts("peer message header read.  size is #{@size} and type is #{@type}")
        return if fin?
      end
    else
      raise "wtf size" if @size < 4
      @data << socket.read_nonblock([4096,@size - @data.size].min)
      $stderr.puts "reading from peer. data size is #{@data.size}"
    end
    socket.flush
  end

  def read_complete?
    @size == @data.size
  end

  def fin?
    @type != 0 ? true : false
  end

  def write_to_client(socket)
    socket.write(@data[4..-1])
    socket.flush
    $stderr.puts("#{@data[4..-1].size} bytes written to client")
  rescue Errno::EPIPE => e
    $stderr.puts("error writing to client")
    raise e
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
    @size = @data.size + 4 if @size.nil?
    $stderr.puts("writing size #{@size} to peer")
    socket.write([@size].pack("n") + [@type].pack("n") + @data)
    $stderr.puts("wrote size #{@size} and type #{@type} to peer")
    socket.flush
  end
end

