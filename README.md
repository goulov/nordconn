# nordconn

A very simple NordVPN client.

## Dependencies

- `curl`
- `jq`
- `openvpn`
- `sipcalc`

---

## Setup

To setup `nordconn` one must:

1. download the ovpn files provided by NordVPN [here](https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip) and extract the zip to `/etc/openvpn/nordvpn/`
2. create an OpenVPN `auth-user-pass` file (2 lines -- 1st line: `username`; and 2nd line: `password`) in `/etc/openvpn/.nordvpn_auth` with the NordVPN credentials (provided on the personal account page, for manual connections)

`# ./nordconn.sh` also guides the user on how to setup `nordconn`, if not yet set correctly.

## Connect to a server

`# ./nordconn.sh tcp FR`

NordVPN supports different server types, one may check their server selection recommendations in their website [here](https://nordvpn.com/servers/tools/).

`nordconn` uses NordVPN API to find the recommended server, given the preferred server country and server type.
Countries are given using their respective two-letter code (e.g. `FR` for France servers).
`nordconn` supports connecting to the following server types: `tcp`, `udp`, `p2ptcp`, `p2pudp`, `doubletcp`, `doubleudp`.

## Disconnect

`# ./nordconn.sh disconnect`

Disconnects the NordVPN connection that was established using `nordconn`.

## Exclude IPs/subnets from VPN routing

`# ./nordconn.sh tcp FR noroute 192.168.1.0/24`

`noroute` is optional.
It excludes the specified CIDR networks from being routed through the VPN interface.
Useful, for instance, to exclude private networks from being routed.

Can be used multiple times in the same command, example:

`# ./nordconn.sh tcp FR noroute 192.168.1.0/24 noroute 10.0.0.0/8`

## Route only specific IPs/subnets

`# ./nordconn.sh tcp FR route 1.2.3.0/24`

`route` is optional.
Makes `nordconn` only route the specified CIDR networks through the VPN, and removes the default routes (which route everything though the VPN).

Can be used multiple times in the same command, example:

`# ./nordconn.sh tcp FR route 1.1.1.1/32 route 2.2.0.0/16`

## Show help

`# ./nordconn.sh help`

## Notes

- `nordconn` does not set any DNS server, be sure to set the DNS so as to avoid DNS leaking.
- `# ./nordconn tcp` shows all available countries returned by the NordVPN API.
