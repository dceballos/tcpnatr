require 'custom_socket'
require 'port_client'

class Client
  attr_reader(:port_client)
  def initialize(port_client)
    @port_client = port_client
  end

  def start(sid="test", lport=0)
    lport, rhost, rport = port_client.resolve(sid, lport)

    #rport += 1

    puts("lport: #{lport} rhost: #{rhost} rport: #{rport}")

    socket = CustomSocket.new
    socket.bind(lport)

    begin
      Timeout::timeout(2) do
        socket.connect(rhost, rport)
        puts "connected"
      end

      (0..50).each do |n|
        socket.write "woohoo\n"
      end
			socket.close

    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL => e
      puts e.message
      retry
    end
  end
end

if $0 == __FILE__
  $:.push(File.dirname(__FILE__))
  port_client = PortClient.new("blastmefy.net:2008")
  Client.new(port_client).start("testy", 2008)
end
