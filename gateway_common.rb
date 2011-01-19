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
              @writemsg.write_to_peer(@peer_socket)
            end
          end
        end
      rescue EOFError, Errno::ECONNRESET, IOError, Errno::EAGAIN, Timeout::Error => e
        $stderr.puts e.message + " foo"
        @transactions.delete(transaction_id(client_socket))
        retry
      end
    end

    def handle_peer
      begin
        loop do
          $stderr.puts "waiting for peer"
          sockets = IO.select([@peer_socket])
          timeout(1) do
            sockets[0].each do |socket|
              $stderr.puts("reading from peer socket")
              @readmsg ||= Message.new
              @readmsg.read_from_peer(@peer_socket)
              $stderr.puts("id from peer is #{@readmsg.id}")
              client_socket = @transactions[@readmsg.id]
              $stderr.puts("client socket from message is #{client_socket.to_s}")
              if @readmsg.read_complete?
                $stderr.puts "read complete"
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
                    next
                  elsif @readmsg.finack?
                    $stderr.puts("received finack")
                    unless client_socket.closed?
                      client_socket.close
                      @transactions.delete(transaction_id(client_socket))
                    end
                    @readmsg = nil
                    next
                  elsif @readmsg.keepalive?
                    $stderr.puts("received keepalive")
                    @readmsg = nil
                    next
                  end
                end
                unless @transactions[transaction_id(client_socket)].nil?
                  $stderr.puts("reading from peer socket, writing to client")
                  @readmsg.write_to_client(client_socket)
                end
                @readmsg = nil
              end
            end
          end
        end
      rescue EOFError, Errno::ECONNRESET, IOError, Errno::EAGAIN, Timeout::Error => e
        $stderr.puts e.message
        finish
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

    def finish
      delete_closed_client_sockets

      @readmsg ||= Message.new
      unless @readmsg.id.nil?
        $stderr.puts("sending fin for #{@readmsg.id}")
        fin = Message.new(Message::FIN, @readmsg.id)
        fin.write_to_peer(@peer_socket)
      end

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

    def finish_client
      delete_closed_client_sockets
      return unless @writemsg

      @writemsg ||= Message.new
      unless @writemsg.id.nil?
        $stderr.puts("sending fin for client #{@writemsg.id}")
        fin = Message.new(Message::FIN, @writemsg.id)
        fin.write_to_peer(@peer_socket)
      end
      
      loop do
        begin
          timeout(0.5) do
            sockets = IO.select([@peer_socket])
            @writemsg.read_from_peer(@peer_socket)
            if @writemsg.read_complete?
              unless @writemsg.payload?
                if @writemsg.finack?
                  $stderr.puts("received finack")
                  @writemsg = nil
                  return
                end
              end
            end
            @writemsg = nil
          end
        rescue Timeout::Error
          $stderr.puts("timeout cleaning socket")
          return  
        end       
      end       
    end 

    def keepalive                                                                    
      keepalive = Message.new(Message::KEEPALIVE, 0)
      keepalive.write_to_peer(@peer_socket)                                          
    end
  end
end
