#!/bin/bash

NAME="nordconn.sh"
OVPNPATH="/etc/openvpn/nordvpn"
AUTHFILE="/etc/openvpn/.nordvpn_auth"
PIDFILE="/etc/openvpn/.nord.pid"

baseargs="--auth-user-pass $AUTHFILE --writepid $PIDFILE --daemon"

function usage {
    echo -e "nordconn.sh tcp/udp contrycode [route w.x.y.z/a]*"
    echo -e "nordconn.sh disconnect"
    echo -e "\t (route is an optional argument, if not provided 0.0.0.0/0 is routed; one can set route multiple times)"
    exit
}

# check if run as root
if [[ "$EUID" != 0 ]]; then
    echo "MUST BE RUN AS R00T!"
    usage
fi

# check dependencies
dependencies=("openvpn" "sipcalc")
for dep in ${dependencies[@]}; do
    if [[ ! `command -v $dep` ]]; then
        echo "ERROR: dependency $dep not installed."
        exit
    fi
done

# check if path exists
if [[ ! -d $OVPNPATH ]]; then
    echo "ERROR: Directory '$OVPNPATH' doesn't exist. Download and extract the files (https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip) to $OVPNPATH/."
    exit
fi

# check if ovpn authfile exists
if [[ ! -f $AUTHFILE ]]; then
    echo "ERROR: Create an OpenVPN auth-user-pass file in $AUTHFILE."
    exit
fi

# check if no arguments provided
[[ $# == 0 ]] && usage

while [[ $# > 0 ]]; do
    case $1 in
        disconnect)
            if [[ ! -f "$PIDFILE" ]]; then # pidfile doesn't exist
                echo "NordVPN not connected, or not started with '$NAME'. OpenVPN must be killed manually."
                exit
            fi
            kill `cat $PIDFILE`
            rm $PIDFILE
            echo "Disconnected!"
            exit
            ;;

        tcp)
            readarray SERVERLIST < <(find $OVPNPATH/ovpn_tcp/ -name "$2*")
            shift
            shift
            ;;

        udp)
            readarray SERVERLIST < <(find $OVPNPATH/ovpn_udp/ -name "$2*")
            shift
            shift
            ;;

        route)
            if [[ ! "$2" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
                echo "ERROR: Invalid route string, use CIDR notation."
                usage
            fi
            netaddr=`sipcalc $2 | grep -m1 "Network address" | sed 's/.*- //'`
            netmask=`sipcalc $2 | grep -m1 "Network mask" | sed 's/.*- //'`
            route="$route --route $netaddr $netmask --route-nopull"
            shift
            shift
            ;;

        *)
            usage
            ;;
    esac
done

if [[ ${#SERVERLIST[@]} == 0 ]]; then # no servers found
    echo "ERROR: No servers for that country code."
    usage
fi
server=${SERVERLIST[RANDOM%${#SERVERLIST[@]}]} # pick a random server for the country
echo "Connecting to $server"
cmd="openvpn --config $server $route $baseargs"
eval $cmd
