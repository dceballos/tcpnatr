class ClientRequest < Struct.new(:id, :socket)
  def initialize(socket)
    @id     = [socket].hash
    @socket = socket
  end
end
