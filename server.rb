require 'custom_socket'
require 'port_client'

class Server
  attr_reader(:port_client)
  def initialize(port_client)
    @port_client = port_client
  end

  def start(sid="test",lport = 0)
    lport, rhost, rport = port_client.resolve(sid,lport)

    syn_socket = send_syn!(lport,rhost,rport)
    
    $stderr.puts "Connected to #{rhost}\n"

    Thread.new do
      while true
        read = syn_socket.readline.chomp
        $stderr.puts "#{rhost}: #{read}"
      end
    end

    Thread.new do
      while true
        write = $stdin.gets
        syn_socket.puts write
      end
    end.join

    #accept_socket = accept!(lport)
    #rset, wset, _ = IO.select([accept_socket],[syn_socket])
    #$stderr.puts("rset: #{rset.inspect}")
    #$stderr.puts("wset: #{wset.inspect}")
  end

  def send_syn!(lport,rhost,rport)
    socket = CustomSocket.new
    socket.bind(lport)
    socket.connect(rhost,rport)
    socket
  end

  def accept!(lport)
    socket = CustomSocket.new
    socket.bind(lport)
    socket.listen(5)
    socket.accept
    socket
  end
end

if $0 == __FILE__
  $:.push(File.dirname(__FILE__))
  port_client = PortClient.new("blastmefy.net:2008")
  Server.new(port_client).start("testy", 2008)
end
