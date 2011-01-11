require 'timeout'
require 'peer'
require 'message'
require 'gateway_common'

class GatewayServer
  include GatewayCommon
  attr_reader(:port, :peer_socket, :server)

  def initialize(port)
    @port = port
  end

  def start_stunt
    port_client  = PortClient.new("blastmefy.net:2000")
    @peer_socket = Peer.new(port_client).start("testy", 2005)
  end

  def start
    $stderr.puts("starting stunt procedure")
    start_stunt
    @server = TCPServer.new(port)

    $stderr.puts("starting gateway server on port #{port}")
    $stderr.puts("waiting for connections")

    while (@client_socket = server.accept)
      handle_accept
    end
  end
end

if $0 == __FILE__
  GatewayServer.new(8080).start
end
