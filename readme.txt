# third party server terminal 1:
ruby port_server.rb

# linode terminal 2:
ruby client.rb

# imac terminal 1:
ruby server.rb


# tcpdump on linode.  
# only imac's public ip, filter ssh & the port server
sudo tcpdump -ln not port 22 and host 67.169.43.12 and not port 2008

