#!/usr/bin/env bash
# ------------------------------------------------------------------
# ARP Keepalive Service Script for Proxmox routed IPs
# ------------------------------------------------------------------

set -euo pipefail

# Path to configuration file
CONFIG_FILE="/etc/arp-keepalive/config.json"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    log "ERROR: jq is not installed. Please install: apt-get install jq"
    exit 1
fi

# Check if arping is installed
if ! command -v arping &> /dev/null; then
    log "ERROR: arping is not installed. Please install: apt-get install arping"
    exit 1
fi

# Check configuration file
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Read configuration
IFACE=$(jq -r '.interface' "$CONFIG_FILE")
INTERVAL=$(jq -r '.interval' "$CONFIG_FILE")
IPS=($(jq -r '.ips[]' "$CONFIG_FILE" 2>/dev/null || echo ""))

# Validation
if [[ -z "$IFACE" ]] || [[ "$IFACE" == "null" ]]; then
    log "ERROR: No network interface specified in configuration"
    exit 1
fi

if [[ -z "$INTERVAL" ]] || [[ "$INTERVAL" == "null" ]]; then
    log "ERROR: No interval specified in configuration"
    exit 1
fi

# Check if interface exists
if ! ip link show "$IFACE" &> /dev/null; then
    log "ERROR: Network interface '$IFACE' does not exist"
    exit 1
fi

log "ARP Keepalive Service started"
log "Interface: $IFACE"
log "Interval: $INTERVAL seconds"
log "Number of IPs: ${#IPS[@]}"

if [[ ${#IPS[@]} -eq 0 ]]; then
    log "WARNING: No IPs configured"
fi

# Infinite loop: sends GARP every INTERVAL seconds for each IP
while true; do
    if [[ ${#IPS[@]} -gt 0 ]]; then
        for ip in "${IPS[@]}"; do
            if [[ -n "$ip" ]]; then
                arping -U -c 1 -I "$IFACE" "$ip" >/dev/null 2>&1 || \
                    log "WARNING: arping failed for $ip"
            fi
        done
        log "ARP pings sent for ${#IPS[@]} IP(s)"
    fi
    sleep "$INTERVAL"
done
