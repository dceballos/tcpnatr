### NAT traversal tunneling for routers with port preservation.

#### blastfemy.net terminal:
`ruby port_server.rb`

#### peer 1 (with http server) terminal:
`ruby gateway_client.rb`

#### peer 2 (with http client) terminal:
`ruby gateway_server.rb`

#### debug peer:  
`sudo tcpdump -ln not port 22 and host other_peer_ip`
