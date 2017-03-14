#!/bin/sh

set -e

# Default if not supplied - same as weave net default
IPALLOC_RANGE=${IPALLOC_RANGE:-10.32.0.0/12}
HTTP_ADDR=${WEAVE_HTTP_ADDR:-127.0.0.1:6784}
STATUS_ADDR=${WEAVE_STATUS_ADDR:-0.0.0.0:6782}
HOST_ROOT=${HOST_ROOT:-/host}
WEAVE_DIR="/host/var/lib/weave"

mkdir $WEAVE_DIR || true

echo "Starting launch.sh"

# Check if the IP range overlaps anything existing on the host
/usr/bin/weaveutil netcheck $IPALLOC_RANGE weave

SWARM_MANAGER_PEERS=$(/usr/bin/weaveutil swarm-manager-peers)
IS_SWARM_MANAGER=$(/usr/bin/weaveutil is-swarm-manager)
# Prevent from restoring from a persisted peers list
rm -f "/restart.sentinel"

/home/weave/weave --local create-bridge \
    --proc-path=/host/proc \
    --weavedb-dir-path=$WEAVE_DIR \
    --force

# ?
NICKNAME_ARG=""

BRIDGE_OPTIONS="--datapath=datapath"
if [ "$(/home/weave/weave --local bridge-type)" = "bridge" ]; then
    # TODO: Call into weave script to do this
    if ! ip link show vethwe-pcap >/dev/null 2>&1; then
        ip link add name vethwe-bridge type veth peer name vethwe-pcap
        ip link set vethwe-bridge up
        ip link set vethwe-pcap up
        ip link set vethwe-bridge master weave
    fi
    BRIDGE_OPTIONS="--iface=vethwe-pcap"
fi

if [ -z "$IPALLOC_INIT" ]; then
    if [ $IS_SWARM_MANAGER == "1" ]; then
        IPALLOC_INIT="consensus=$(echo $SWARM_MANAGER_PEERS | wc -l)"
    else
        IPALLOC_INIT="observer"
    fi
fi

exec /home/weave/weaver $EXTRA_ARGS --port=6783 $BRIDGE_OPTIONS \
    --http-addr=$HTTP_ADDR --status-addr=$STATUS_ADDR --docker-api='' --no-dns \
    --ipalloc-range=$IPALLOC_RANGE $NICKNAME_ARG \
    --ipalloc-init $IPALLOC_INIT \
    --log-level=debug \
    --db-prefix="$WEAVE_DIR/weave" \
    --plugin \
    $(echo $SWARM_MANAGER_PEERS | tr '\n' ' ')
