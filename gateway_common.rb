require 'message'
require 'zlib'

module Gateway
  module Common
    KEEPALIVE_TIMEOUT = 20
    
    def handle_client(client_socket)
      begin
        loop do
          break if @transactions[transaction_id(client_socket)].nil?
          sockets = IO.select([client_socket])
          timeout(1) do
            sockets[0].each do |socket|
              writemsg = Message.new(Message::PAYLOAD, transaction_id(socket)) 
              writemsg.read_from_client(socket)
              @mutex.synchronize {
                writemsg.write_to_peer(@peer_socket)
              }
            end
          end
        end
      rescue EOFError, Errno::ECONNRESET, IOError, Errno::EAGAIN, Timeout::Error => e
        return if @transactions[transaction_id(client_socket)].nil?
        $stderr.puts e.message + " c "

        fin = Message.new(Message::FIN, transaction_id(client_socket))
        @mutex.synchronize {
          fin.write_to_peer(@peer_socket)
        }
        client_socket.close
        @transactions.delete(transaction_id(client_socket))
      end
    end

    def handle_peer
      begin
        loop do
          sockets = IO.select([@peer_socket])
          timeout(1) do
            sockets[0].each do |socket|
              @readmsg ||= Message.new
              @readmsg.read_from_peer(@peer_socket)

              if @readmsg.read_complete?
                $stderr.puts("reading from peer #{@readmsg.id}")

                if self.is_a?(Gateway::Client)
                  if @transactions[@readmsg.id].nil? && @readmsg.id != 256
                    client_socket = TCPSocket.new("localhost", port)
                    @transactions[@readmsg.id] = client_socket
                    Thread.new do
                      handle_client(client_socket)
                    end
                  end
                end

                client_socket = @transactions[@readmsg.id]

                unless @readmsg.payload?
                  if @readmsg.fin?
                    finack = Message.new(Message::FINACK, @readmsg.id)
                    @mutex.synchronize {  
                      finack.write_to_peer(@peer_socket)
                    }
                    @transactions.delete(transaction_id(client_socket))
                    @readmsg = nil
                    break
                  elsif @readmsg.finack?
                    @transactions.delete(transaction_id(client_socket))
                    @readmsg = nil
                    break
                  elsif @readmsg.keepalive?
                    @readmsg = nil
                    break
                  end
                end

                unless @transactions[transaction_id(client_socket)].nil?
                  if client_socket.closed?
                    @transactions.delete(transaction_id(client_socket))
                    @readmsg = nil
                    break
                  end
                  $stderr.puts("writing to client #{@readmsg.id} <#{transaction_id(client_socket)}>")
                  @readmsg.write_to_client(client_socket)
                end
                @readmsg = nil
              else
                $stderr.puts("read not complete")
              end
            end
          end
        end
      rescue Errno::ECONNRESET, IOError, Errno::EAGAIN, Timeout::Error => e
        $stderr.puts e.message + " s "
        retry
      end
    end

    def transaction_id(socket)
      @transactions.each_pair do |key,val|
        return key if val == socket
      end
      nil
    end

    def keepalive                                                                    
      keepalive = Message.new(Message::KEEPALIVE, 256)
      @mutex.synchronize {
        keepalive.write_to_peer(@peer_socket)
      }
    end
  end
end

