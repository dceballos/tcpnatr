traverse NAT in routers with port preservation.

# third party server terminal:
ruby port_server.rb

# peer 1 terminal:
ruby peer.rb

# peer 2 terminal:
ruby peer.rb

# tcpdump on linode.  
# only imac's public ip, filter ssh & the port server
sudo tcpdump -ln not port 22 and host 67.169.43.12 and not port 2008
