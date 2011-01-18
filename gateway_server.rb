require 'timeout'
require 'peer'
require 'gateway_common'

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

      loop do
        begin
          timeout(KEEPALIVE_TIMEOUT) do
            $stderr.puts("waiting for connections")
            @transactions[new_transaction_id] = server.accept
            $stderr.puts("@transactions #{@transactions.inspect}")
          end
        rescue Timeout::Error
          $stderr.puts("sending keepalive")                                     
          keepalive
          retry
        end
        handle_accept
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
