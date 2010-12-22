require 'custom_socket'
require 'port_client'

class Peer
  attr_reader(:port_client)
  def initialize(port_client)
    @port_client = port_client
  end

  def start(sid="test",lport = 0)
    lport, rhost, rport = port_client.resolve(sid,lport)

    socket = CustomSocket.new
    socket.bind(lport)

    begin
      Timeout::timeout(1) do
        socket.connect(rhost,rport)   
        $stderr.puts "connected to #{rhost}\n"
      end
      socket
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL => e
      puts "connecting ..."
      retry
    end
  end
end

=begin
if $0 == __FILE__
  $:.push(File.dirname(__FILE__))
  port_client = PortClient.new("blastmefy.net:2005")
  Peer.new(port_client).start("test", 2008)
end
=end
