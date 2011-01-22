module Gateway
  module Common
    KEEPALIVE_TIMEOUT = 20

    def handle_client(client_request)
      @requests[client_request.id] = client_request
      begin
        loop do
          sockets = IO.select([client_request.socket])
          timeout(1) do
            sockets[0].each do |socket|
              writemsg = Message.new(Message::PAYLOAD, client_request.id)
              writemsg.read_from_client(client_request.socket)
              @mutex.synchronize {
                writemsg.write_to_peer(@peer_socket)
              }
            end
          end
        end
      rescue EOFError, Errno::ECONNRESET, IOError, Errno::EAGAIN, Timeout::Error => e
        $stderr.puts e.message
        fin = Message.new(Message::FIN, client_request.id)
        @mutex.synchronize {
          fin.write_to_peer(@peer_socket)
        }
        client_request.socket.close
        @requests.delete(client_request.id)
      end
    end

    def handle_peer
      begin
        loop do
          sockets = IO.select([@peer_socket])
          timeout(1) do
            sockets[0].each do |socket|

              # Read packet from peer and create new message or complete
              # previous unfinished packet

              @readmsg ||= Message.new
              @readmsg.read_from_peer(socket)

              if @readmsg.read_complete?
                $stderr.puts("read message #{@readmsg.id}")

                # If we are a Gateway::Client instance, create socket
                # to HTTP server and handle it in a new thread

                if self.is_a?(Gateway::Client)
                  if @requests[@readmsg.id].nil? && @readmsg.payload?
                    client_socket          = TCPSocket.new(host, port)
                    @requests[@readmsg.id] = ClientRequest.new(@readmsg.id, client_socket)
                    Thread.new do
                      handle_client(@requests[@readmsg.id])
                    end
                  end
                end

                # Handle message if it doesn't contain payload data

                unless @readmsg.payload?
                  if @readmsg.fin?
                    finack = Message.new(Message::FINACK, @readmsg.id)
                    @mutex.synchronize {  
                      finack.write_to_peer(@peer_socket)
                    }
                    @requests.delete(@readmsg.id)
                    @readmsg = nil
                    break
                  elsif @readmsg.finack?
                    @requests.delete(@readmsg.id)
                    @readmsg = nil
                    break
                  elsif @readmsg.keepalive?
                    @readmsg = nil
                    break
                  end
                end

                # Write message to client socket

                unless @requests[@readmsg.id].nil?
                  client_request = @requests[@readmsg.id]
                  if client_request.socket.closed?
                    @requests.delete(@readmsg.id)
                    @readmsg = nil
                    break
                  end
                  $stderr.puts("writing request #{@readmsg.id} to client")
                  @readmsg.write_to_client(client_request.socket)
                end
                @readmsg = nil
              end
            end
          end
        end
      rescue EOFError, Errno::ECONNRESET, IOError, Errno::EAGAIN, Timeout::Error => e
        $stderr.puts e.message
        exit if @peer_socket.eof?
        retry
      end
    end

    def new_request_id
      loop do
        n = rand(2**16)
        return n unless @requests.has_key?(n)
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

