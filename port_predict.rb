require 'custom_socket'
require 'port_client'
require 'uri'

class PortPredict
  attr_reader(:port_client)
  def initialize
    @hosts = []
    @hosts << "http://www.deusty.com/utilities/getMyIPAndPort.php"
    @hosts << "http://www.robbiehanson.com:8080/utilities/getMyIPAndPort.php"
  end

  def start(lport = 0)
    @hosts.each do |host|
      active = CustomSocket.new
      active.bind(lport)
      puts "connecting"
      active.connect("#{::URI.parse(host).host}", ::URI.parse(host).port)
      req = "GET #{::URI.parse(host).path} HTTP/1.0\n\n"
      active.print(req)
      puts active.gets(nil)
      active.close
    end
    
    rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL => e
      puts e.message
      retry
  end
end

if $0 == __FILE__
  $:.push(File.dirname(__FILE__))
  PortPredict.new.start(2003)
end
