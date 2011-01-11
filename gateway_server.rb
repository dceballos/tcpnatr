require 'timeout'
require 'peer'
require 'message'
require 'gateway_common'

class GatewayServer
  KEEPALIVE_TIMEOUT = 20
  include GatewayCommon
  attr_reader(:port, :peer_socket, :server)

  def initialize(port)
    @port = port
  end

  def start_stunt
    port_client  = PortClient.new("blastmefy.net:2000")
    @peer_socket = Peer.new(port_client).start("testy", 2003)
  end

  def start
    $stderr.puts("starting stunt procedure")
    start_stunt
    @server = TCPServer.new(port)

    $stderr.puts("starting gateway server on port #{port}")
    $stderr.puts("waiting for connections")

    while (true)
      begin
        timeout(KEEPALIVE_TIMEOUT) do
          @client_socket = server.accept
        end
      rescue Timeout::Error => e
        $stderr.puts("sending keepalive")                                     
        keepalive
        retry
      end
      handle_accept
    end
  end
end

if $0 == __FILE__
  GatewayServer.new(8080).start
end
