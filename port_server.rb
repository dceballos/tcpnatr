#!/usr/bin/ruby
require 'socket'

class Session < Struct.new(:sid,:socket,:port)
  def message
    "#{ip}:#{port}"
  end

  def port
    socket.peeraddr[1]
  end
  def ip
    socket.peeraddr[3]
  end

  def to_s
    "#{sid}: #{ip}:#{port}"
  end
end

class PortServer
  attr_reader(:port,:sessions,:server)

  def initialize(port)
    @port     = port
    @sessions = {}
  end

  def start
    server = TCPServer.new(port)
    puts "Starting port server.  Waiting for sessions"
	
    while (socket = server.accept)
      handle_accept(socket)
    end
  end

  def handle_accept(socket)
    port = socket.peeraddr[1]
    sid  = socket.gets.chomp
    register_session(Session.new(sid,socket,port))
  end

  def register_session(session)
    info("handling session #{session}")
    if other = sessions.delete(session.sid)
      info("found corresponding session #{other}")
      other.socket.puts(session.message)
      session.socket.puts(other.message)
      other.socket.close
      session.socket.close
    else
      info("waiting for second session #{session.sid}")
      sessions[session.sid] = session
    end
  end

  def info(msg)
    $stderr.puts(msg)
  end
end

if $0 == __FILE__
  PortServer.new(2008).start
end
