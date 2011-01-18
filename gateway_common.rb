require 'message'
require 'zlib'

module Gateway
  module Common
    KEEPALIVE_TIMEOUT = 20

    def handle_accept
      begin
        loop do
          $stderr.puts("@transactions #{@transactions.inspect}")
          sockets = IO.select([@peer_socket] + @transactions.values)
          timeout(1) do
            sockets[0].each do |socket|
              client_socket = @transactions[transaction_id(socket)]
              $stderr.puts("client socket #{client_socket}")
              if socket != @peer_socket
                $stderr.puts("reading from client socket")
                @writemsg = Message.new(Message::PAYLOAD, transaction_id(socket)) 
                @writemsg.read_from_client(client_socket)
                @writemsg.write_to_peer(@peer_socket)
              else
                $stderr.puts("reading from peer socket")
                @readmsg ||= Message.new
                @readmsg.read_from_peer(@peer_socket)
                $stderr.puts("id from peer is #{@readmsg.id}")
                unless @transactions[@readmsg.id]
                  client_socket = TCPSocket.new(host, port) if client_socket.nil?
                  @transactions[@readmsg.id] = client_socket
                else
                  client_socket = @transactions[@readmsg.id]
                end
                $stderr.puts("client socket from message is #{client_socket.to_s}")
                if @readmsg.read_complete?
                  unless @readmsg.payload?
                    if @readmsg.fin?
                      $stderr.puts("received fin sending finack")
                      finack = Message.new(Message::FINACK, @readmsg.id)
                      finack.write_to_peer(@peer_socket)
                      unless client_socket.closed?
                        client_socket.close
                        @transactions.delete(transaction_id(client_socket))
                      end
                      @readmsg = nil
                      return
                    elsif @readmsg.finack?
                      $stderr.puts("received finack")
                      unless client_socket.closed?
                        client_socket.close
                        @transactions.delete(transaction_id(client_socket))
                      end
                      @readmsg = nil
                      return
                    elsif @readmsg.keepalive?
                      $stderr.puts("received keepalive")
                      @readmsg = nil
                      return
                    end
                  end
                  $stderr.puts("reading from peer socket, writing to client")
                  @readmsg.write_to_client(client_socket)
                  @readmsg = nil
                end
              end
            end
          end
        end
      rescue EOFError, Errno::ECONNRESET, IOError, Errno::EAGAIN, Timeout::Error => e
        $stderr.puts e.message
        finish
      end
    end

    def transaction_id(socket)
      @transactions.each_pair do |key,val|
        $stderr.puts("key #{key} val #{val.to_s} compared with #{socket.to_s}")
        return key if val == socket
      end
    end

    def delete_closed_client_sockets
      @transactions.each_pair do |key,val|
        if val.eof?
          $stderr.puts("deleting transaction #{key}")
          val.close unless val.closed?
          @transactions.delete(key)
        end
      end
    end

    def finish
      delete_closed_client_sockets

      @readmsg ||= Message.new
      $stderr.puts("sending fin for #{@readmsg.id}")
      fin = Message.new(Message::FIN, @readmsg.id || 100)
      fin.write_to_peer(@peer_socket)

      loop do
        begin
          timeout(0.5) do
            sockets = IO.select([@peer_socket])
            @readmsg.read_from_peer(@peer_socket)
            if @readmsg.read_complete?
              unless @readmsg.payload?
                if @readmsg.finack?
                  $stderr.puts("received finack")
                  @readmsg = nil
                  return
                end
              end
            end
            @readmsg = nil
          end
        rescue Timeout::Error
          $stderr.puts("timeout cleaning socket")
          return
        end
      end
    end

    def keepalive                                                                    
      keepalive = Message.new(Message::KEEPALIVE)                                                     
      keepalive.write_to_peer(@peer_socket)                                          
    end
  end
end
