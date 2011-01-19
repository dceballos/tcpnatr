require 'timeout'
require 'peer'
require 'gateway_common'
require 'gateway_client'

module Gateway
  class Server
    include Gateway::Common
    attr_reader(:port, :peer_socket, :server)

    def initialize(port)
      @port = port
      @transactions = {}
    end

    def start_stunt
      port_client  = PortClient.new("blastmefy.net:2000")
      @peer_socket = Peer.new(port_client).start("testy", 2003)
    end

    def start
      $stderr.puts("starting nat traversal")
      start_stunt

      @server = TCPServer.new(port)
      $stderr.puts("gateway server started on port #{port}")

      Thread.new do
        handle_peer
      end

      loop do
        begin
          timeout(KEEPALIVE_TIMEOUT) do
            $stderr.puts("waiting for connections")
            client_socket = server.accept
            @transactions[new_transaction_id] = client_socket
            $stderr.puts("@transactions #{@transactions.inspect}")
            Thread.new do
              handle_client(client_socket)
            end
          end
        rescue Timeout::Error
          $stderr.puts("sending keepalive")                                     
          keepalive
          retry
        end
      end
    end

    def new_transaction_id
      loop do
        nid = rand(256)
        return nid unless @transactions.has_key?(nid)
      end
    end
  end
end

if $0 == __FILE__
  Gateway::Server.new(8080).start
end
