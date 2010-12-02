### NAT traversal demo for routers with port preservation.

#### third party server terminal:
`ruby port_server.rb`

#### peer 1 terminal:
`ruby peer.rb`

#### peer 2 terminal:
`ruby peer.rb`

#### debug.  
sudo tcpdump -ln not port 22 and host 67.169.43.12 and not port 2008
