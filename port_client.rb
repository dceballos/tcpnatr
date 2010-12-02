require 'custom_socket'

class PortClient
  def initialize(portserver)
    @portserver_host, @portserver_port = portserver.split(":")
  end

  def resolve(sid,port=0)
    socket = CustomSocket.new
    socket.bind(port)
    trap_int(socket)

    socket.connect(@portserver_host,@portserver_port)
    lport  = socket.local_port
    socket.puts(sid)
    rhost, rport = socket.gets.chomp.split(":")
    return [lport,rhost,rport.to_i]
  end

  def trap_int(socket)
    Signal.trap("INT") do
      unless socket.nil?
        puts "closing open socket"
        socket.close
      end
      exit
    end
  end
end

if $0 == __FILE__
  $:.push(File.dirname(__FILE__))
  puts PortClient.new("blastmefy.net:2008").resolve("test")
end
