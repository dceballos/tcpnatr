require 'custom_socket'
require 'port_client'

class PeerServer
  attr_reader(:port_client, :free_sockets)
  def initialize(port_client)
    @port_client  = port_client
  end

  def start(sid="test",lport = 0)
    lport, rhost, rport = port_client.resolve(sid,lport)

    server = CustomSocket.new
    server.bind(lport)
    server.listen(5)

    punch_nat(lport, rhost, rport)

    begin
      socket = server.accept
      $stderr.puts "connected to #{rhost}\n"
      socket
    rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL => e
      puts e.message
    end
  end

  def punch_nat(lport, rhost, rport)
    begin
      socket = CustomSocket.new

      # set ttl low enough so it crosses our nat but won't reach remote peer.
      socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_TTL, [2].pack("L"))
      socket.bind(lport)

      Timeout::timeout(0.3) do
        puts "punching hole through our NAT"
        socket.connect(rhost,rport)
      end

    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL => e
      socket.close
    end
  end
end
=begin
if $0 == __FILE__
  $:.push(File.dirname(__FILE__))
  port_client = PortClient.new("blastmefy.net:2000")
  PeerServer.new(port_client).start("testy", 2008)
end
=end
