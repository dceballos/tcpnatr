require 'message'
require 'zlib'

module Gateway
  module Common
    KEEPALIVE_TIMEOUT = 20

    def handle_accept
      begin
        rd_sock = [@peer_socket] + @transactions.values
        $stderr.puts("read sockets #{rd_sock.inspect}")
        while (sockets = IO.select(rd_sock))
          timeout(1) do
            sockets[0].each do |socket|
              $stderr.puts("@transactions #{@transactions.inspect}")
              client_socket = @transactions[transaction_id(socket)]
              $stderr.puts("client socket #{client_socket}")
              if socket != @peer_socket
                @writemsg = Message.new(Message::PAYLOAD, transaction_id(socket)) 
                @writemsg.read_from_client(client_socket)
                @writemsg.write_to_peer(@peer_socket)
              else
                @readmsg ||= Message.new
                @readmsg.read_from_peer(@peer_socket)
                client_socket = @transactions[@readmsg.id]
                $stderr.puts("client socket from message is #{client_socket.to_s}")
                if @readmsg.read_complete?
                  unless @readmsg.payload?
                    if @readmsg.fin?
                      $stderr.puts("received fin sending finack")
                      finack = Message.new(Message::FINACK)
                      finack.write_to_peer(@peer_socket)
                      unless client_socket.close?
                        client_socket.close
                        #@transactions.delete(transaction_id(client_socket))
                      end
                      @readmsg = nil
                      return
                    elsif @readmsg.finack?
                      $stderr.puts("received finack")
                      unless client_socket.close?
                        client_socket.close
                        #@transactions.delete(transaction_id(client_socket))
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

    def finish
      $stderr.puts("sending fin")
      fin = Message.new(Message::FIN)
      fin.write_to_peer(@peer_socket)

      loop do
        begin
          timeout(0.5) do
            sockets = IO.select([@peer_socket])
            @readmsg ||= Message.new
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
