require 'timeout'
require 'peer_server'
require 'message'
require 'gateway_common'

class GatewayClient
  include GatewayCommon

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
    $stderr.puts("staring stunt procedure")
    start_stunt

    while (true)
      @client_socket = TCPSocket.new(host, port)
      $stderr.puts("waiting for connections")
      handle_accept
    end
  end
end

if $0 == __FILE__
  GatewayClient.new('localhost', 3001).start
end
