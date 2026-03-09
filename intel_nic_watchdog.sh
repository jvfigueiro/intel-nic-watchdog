#!/bin/bash

# --- SETTINGS ---
TARGET="10.0.7.1"    # Gateway IP
IFACE="nic0"         # Physical interface name
LOGFILE="/var/log/watchdog_rede.log"
# ---------------------

# If the cable is disconnected, nothing happens.
if [ -f "/sys/class/net/$IFACE/carrier" ]; then
    LINK_STATUS=$(cat /sys/class/net/$IFACE/carrier)
    if [ "$LINK_STATUS" -eq 0 ]; then
        # Cable disconnected
        # Doesn't log often to avoid filling up disk; just log out.
        exit 0
    fi
else
    echo "$(date): CRITICAL - Interface $IFACE has lost from system!" >> $LOGFILE
    exit 0
fi

# Connectivity test (ping to gateway)
# Try pinging the router. If it responds, everything is great.
if ping -c 3 $TARGET > /dev/null 2>&1; then
    exit 0
fi

# If a temporary failure happens, wait 15 seconds and tries again.
sleep 15
if ping -c 3 $TARGET > /dev/null 2>&1; then
    exit 0
fi

# Soft fix
# The network interface will be restarted

echo "$(date): Gateway $TARGET is inaccessible. Attempting to restart interface $IFACE..." >> $LOGFILE

# Restart the interface and reapply the offload fixes.
ip link set $IFACE down
sleep 2
/usr/sbin/ethtool -K $IFACE tso off gso off
ip link set $IFACE up

# Waits network to negotiate
sleep 20

# Final test
if ping -c 3 $TARGET > /dev/null 2>&1; then
    echo "$(date): SUCCESS - Network recovered after interface restart." >> $LOGFILE
    exit 0
else
 
    echo "$(date): FAIL - The Gateway remains inaccessible after the interface reset." >> $LOGFILE
    echo "$(date): DIAG - Probable ISP outage. System remains ACTIVE for local services." >> $LOGFILE
    
    # No longer reboots (removes /sbin/reboot)
    exit 0
fi
