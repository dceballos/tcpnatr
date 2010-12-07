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
        $stderr.puts "Connected to #{rhost}\n"
      end

      Thread.new do
        while true
          read = socket.readline.chomp
          $stderr.puts "#{rhost}: #{read}"
        end
      end

      Thread.new do
        while true
          write = $stdin.gets
          socket.puts write
        end
      end.join
    
    rescue Errno::EINVAL => e
      puts e.message
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL => e
      puts e.message
      retry
    end
  end
end

if $0 == __FILE__
  $:.push(File.dirname(__FILE__))
  port_client = PortClient.new("blastmefy.net:2000")
  Peer.new(port_client).start("testy", 2008)
end
