#!/bin/bash

NAME="nordconn.sh"
OVPNPATH="/etc/openvpn/nordvpn"
AUTHFILE="/etc/openvpn/.nordvpn_auth"
PIDFILE="/etc/openvpn/.nord.pid"
IFACENAME="tun-nord"

baseargs="--auth-user-pass $AUTHFILE --writepid $PIDFILE --dev $IFACENAME --dev-type tun --daemon"

function usage {
    echo "usage:"
    echo -e "\tnordconn.sh tcp/udp/p2ptcp/p2pudp/doubletcp/doubleudp countrycode [route w.x.y.z/a]*"
    echo -e "\tnordconn.sh disconnect"
    echo -e "\tnordconn.sh help"
    echo -e "\n\t(route is optional or can be set multiple times. default: 0.0.0.0/0)"
    exit
}

function get_server { # ARGS: country_code, server_type, server_protocol
    countrynr=`curl --silent "https://api.nordvpn.com/v1/servers/countries" | jq --raw-output ".[] | select(.code == \"$1\") | .id"`
    if [[ -z $countrynr ]]; then
        echo "ERROR: Invalid country code. Available codes:"
        curl --silent "https://api.nordvpn.com/v1/servers/countries" | jq --raw-output '.[] | [.code, .name] |  @tsv'
        exit 1
    fi
    server=`curl --silent "https://api.nordvpn.com/v1/servers/recommendations?filters\[country_id\]=$countrynr&filters\[servers_groups\]\[identifier\]=$2&filters\[servers_technologies\]\[identifier\]=$3&limit=1" | jq --raw-output '.[].hostname'`
    if [[ -z $server ]]; then
        echo "ERROR: No server found for that country and protocol."
        exit 1
    fi
}

# check if run as root
if [[ "$EUID" != 0 ]]; then
    echo "ERROR: Must be run as r00t."
    exit 1
fi

# check dependencies
dependencies=("openvpn" "sipcalc" "curl" "jq")
for dep in ${dependencies[@]}; do
    if [[ ! `command -v $dep` ]]; then
        echo "ERROR: dependency '$dep' not installed."
        exit 1
    fi
done

# check if ovpn path exists
if [[ ! -d $OVPNPATH ]]; then
    echo "ERROR: Directory '$OVPNPATH' doesn't exist. Download and extract the files (https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip) to $OVPNPATH/."
    exit 1
fi

# check if ovpn authfile exists
if [[ ! -f $AUTHFILE ]]; then
    echo "ERROR: Create an OpenVPN auth-user-pass file in $AUTHFILE."
    exit 1
fi

# check if no arguments provided
[[ $# == 0 ]] && usage

# check if $IFACENAME is already running
if [[ $1 != "disconnect" && ! -z `ip a | grep $IFACENAME` ]]; then
    echo "ERROR: Interface $IFACENAME exists. Please run 'disconnect' first."
    exit 1
fi

while [[ $# > 0 ]]; do
    case $1 in
        disconnect)
            if [[ ! -f "$PIDFILE" ]]; then # pidfile doesn't exist
                echo "ERROR: NordVPN not connected, or not started with '$NAME'. OpenVPN must be killed manually."
                exit 1
            fi
            kill `cat $PIDFILE`
            rm $PIDFILE
            echo "Disconnected!"
            exit
            ;;

        tcp)
            get_server $2 "legacy_standard" "openvpn_tcp"
            serverpath="$OVPNPATH/ovpn_tcp/$server.tcp.ovpn"
            echo $serverpath
            shift; shift
            ;;

        udp)
            get_server $2 "legacy_standard" "openvpn_udp"
            serverpath="$OVPNPATH/ovpn_udp/$server.udp.ovpn"
            echo $serverpath
            shift; shift
            ;;

        p2ptcp)
            get_server $2 "legacy_p2p" "openvpn_tcp"
            serverpath="$OVPNPATH/ovpn_tcp/$server.tcp.ovpn"
            echo $serverpath
            shift; shift
            ;;

        p2pudp)
            get_server $2 "legacy_p2p" "openvpn_udp"
            serverpath="$OVPNPATH/ovpn_udp/$server.udp.ovpn"
            echo $serverpath
            shift; shift
            ;;

        doubletcp)
            get_server $2 "legacy_double_vpn" "openvpn_tcp"
            serverpath="$OVPNPATH/ovpn_tcp/$server.tcp.ovpn"
            echo $serverpath
            shift; shift
            ;;

        doubleudp)
            get_server $2 "legacy_double_vpn" "openvpn_udp"
            serverpath="$OVPNPATH/ovpn_udp/$server.udp.ovpn"
            echo $serverpath
            shift; shift
            ;;

        route) # route only specific cidr networks
            if [[ ! "$2" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
                echo "ERROR: Invalid route string, use CIDR notation."
                exit 1
            fi
            netaddr=`sipcalc $2 | grep -m1 "Network address" | sed 's/.*- //'`
            netmask=`sipcalc $2 | grep -m1 "Network mask" | sed 's/.*- //'`
            route="$route --route $netaddr $netmask --route-nopull"
            shift; shift
            ;;

        help)
            usage
            ;;

        *)
            echo "ERROR: unknown argument $1."
            usage
            ;;
    esac
done
# missing: legacy_obfuscated_servers, legacy_onion_over_vpn

echo "Connecting to $server"
cmd="openvpn --config $serverpath $route $baseargs"
eval $cmd


# USEFUL:
# server types:
# curl --silent "https://api.nordvpn.com/v1/servers/groups" | jq --raw-output '.[] | . as $parent | .type | [$parent.title, $parent.id, $parent.identifier, .title, .id, .identifier] | "\(.[0]) [\(.[2]) (\(.[1]))] -  \(.[3]) [\(.[5]) (\(.[4]))]"'
# server technologies;
# curl --silent "https://api.nordvpn.com/v1/technologies" | jq --raw-output '.[] | [.name, .id, .identifier] | "\(.[0]) [\(.[2]) (\(.[1]))]"'
