### NAT traversal demo for routers with port preservation.

#### blastfemy.net terminal:
`ruby port_server.rb`

#### peer 1 terminal:
`ruby peer_server.rb`

#### peer 2 terminal:
`ruby peer.rb`

#### debug peer:  
`sudo tcpdump -ln not port 22 and host other_peer_ip and not port 2008`
