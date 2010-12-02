require 'socket'
require 'timeout'

class CustomSocket < Socket  
  def initialize
    super(AF_INET, SOCK_STREAM, 0)
    setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
    if defined?(SO_REUSEPORT)
      setsockopt(SOL_SOCKET, SO_REUSEPORT, 1)
    end
  end
  
  def bind(port = 0)
    addr_local = Socket.pack_sockaddr_in(port, '0.0.0.0')
    super(addr_local)
  end
  
  def connect(ip, port)
    addr_remote = Socket.pack_sockaddr_in(port, ip)
    super(addr_remote)
  end

  def connect_nonblock(ip,port)
    super(Socket.pack_sockaddr_in(port, ip))
  rescue Errno::EISCONN,Errno::EINPROGRESS
  end
  
  def accept
    super[0]
  end

  def accept_nonblock
    super[0]
  end

  def addr
    Socket.unpack_sockaddr_in(getsockname)
  end
  
  def local_port
    addr[0]
  end
end
