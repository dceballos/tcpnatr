require 'message'
require 'zlib'

module Gateway
  module Common
    KEEPALIVE_TIMEOUT = 20
    
    def handle_client(client_socket)
      begin
        loop do
          break if @transactions[transaction_id(client_socket)].nil?
          $stderr.puts "waiting for client"
          sockets = IO.select([client_socket])
          timeout(1) do
            sockets[0].each do |socket|
              $stderr.puts("client socket #{socket}")
              $stderr.puts("reading from client socket")
              @writemsg = Message.new(Message::PAYLOAD, transaction_id(socket)) 
              @writemsg.read_from_client(socket)
              $stderr.puts("writing to peer for #{@writemsg.id}")
              @mutex.synchronize {
                @writemsg.write_to_peer(@peer_socket)
              }
              $stderr.puts("wrote #{@writemsg.id} to peer")
            end
          end
        end
      rescue EOFError, Errno::ECONNRESET, IOError, Errno::EAGAIN, Timeout::Error => e
        return if @transactions[transaction_id(client_socket)].nil?
        $stderr.puts e.message + " foo"
        if self.is_a?(Gateway::Server)
          $stderr.puts("sending fin for #{@writemsg.id}")
          fin = Message.new(Message::FIN, @writemsg.id)
          fin.write_to_peer(@peer_socket)
        end
        client_socket.close
        @transactions.delete(transaction_id(client_socket))
      end
    end

    def handle_peer
      begin
        loop do
          $stderr.puts("waiting for peer")
          sockets = IO.select([@peer_socket])
          timeout(1) do
            sockets[0].each do |socket|
              $stderr.puts("reading from peer socket")
              @readmsg ||= Message.new
              @readmsg.read_from_peer(@peer_socket)
              $stderr.puts("id from peer is #{@readmsg.id}")
              if self.is_a?(Gateway::Client)
                unless @transactions[@readmsg.id] && @readmsg.id != 0
                  $stderr.puts("new client for #{@readmsg.id}")
                  client_socket = TCPSocket.new("localhost", port)
                  @transactions[@readmsg.id] = client_socket
                  Thread.new do
                    handle_client(client_socket)
                  end
                end
              end
              client_socket = @transactions[@readmsg.id]
              $stderr.puts("client socket from message is #{client_socket.to_s}")
              if @readmsg.read_complete?
                unless @readmsg.payload?
                  if @readmsg.fin?
                    $stderr.puts("received fin for #{@readmsg.id} sending finack")
                    finack = Message.new(Message::FINACK, @readmsg.id)
                    @mutex.synchronize {  
                      finack.write_to_peer(@peer_socket)
                    }
                    #client_socket.close unless client_socket.closed?
                    @transactions.delete(transaction_id(client_socket))
                    @readmsg = nil
                    break
                  elsif @readmsg.finack?
                    $stderr.puts("received finack for #{@readmsg.id} in main")
                    #client_socket.close unless client_socket.closed?
                    @transactions.delete(transaction_id(client_socket))
                    @readmsg = nil
                    $stderr.puts("breaking ...")
                    break
                  elsif @readmsg.keepalive?
                    $stderr.puts("received keepalive")
                    @readmsg = nil
                    break
                  end
                end
                unless @transactions[transaction_id(client_socket)].nil?
                  $stderr.puts("reading from peer socket, writing to client")
                  if client_socket.closed?
                    @transactions.delete(transaction_id(client_socket))
                    break
                  end
  
                  @readmsg.write_to_client(client_socket)
                end
                @readmsg = nil
              end
            end
          end
        end
      rescue EOFError, Errno::ECONNRESET, IOError, Errno::EAGAIN, Timeout::Error => e
        $stderr.puts e.message
        #finish
        retry
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

    def keepalive                                                                    
      keepalive = Message.new(Message::KEEPALIVE, 0)
      @mutex.synchronize {
        keepalive.write_to_peer(@peer_socket)
      }
    end
  end
end

