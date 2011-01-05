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
    socket.write([@size].pack("N") + @type.pack("N") + @data)
    $stderr.puts("wrote size #{@size} and type #{@type} to peer")
    socket.flush
  end
end
