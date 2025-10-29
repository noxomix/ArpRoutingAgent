# ARP Keepalive Service for Proxmox

This service regularly sends ARP packets (Gratuitous ARP) for configured IP addresses to keep routed IPs active with hosting providers.

## Quick Install

```bash
git clone https://github.com/noxomix/ArpRoutingAgent.git && cd ArpRoutingAgent && sudo ./install.sh
```

## How it works

The service reads a JSON configuration file and sends ARP pings at a configurable interval for all specified IP addresses via the specified network interface.

## Files

- `arp-keepalive.sh` - Main script that sends ARP pings
- `arp-keepalive.service` - Systemd service definition
- `config.json` - Example configuration file
- `install.sh` - Installation script

## Installation

### Prerequisites

- Proxmox or Linux system with systemd
- Root privileges

### Installation Steps

1. Clone repository or download files

2. Run installation script:
```bash
sudo ./install.sh
```

The script automatically performs the following steps:
- Installs required packages (jq, arping)
- Creates configuration directory `/etc/arp-keepalive/`
- Creates default configuration file
- Copies script to `/usr/local/bin/`
- Installs systemd service
- Enables and starts the service

## Configuration

Configuration is done via the JSON file `/etc/arp-keepalive/config.json`:

```json
{
  "interface": "vmbr0",
  "interval": 60,
  "ips": [
    "2.56.245.72",
    "2.56.245.73",
    "2.56.245.74",
    "2.56.245.75",
    "2.56.245.76",
    "2.56.245.77",
    "2.56.245.78",
    "2.56.245.79"
  ]
}
```

### Parameters

- `interface` - Network interface (e.g. `vmbr0`, `eth0`)
- `interval` - Interval in seconds between ARP pings (default: 60)
- `ips` - Array of IP addresses to be pinged via ARP

### Edit Configuration

```bash
sudo nano /etc/arp-keepalive/config.json
```

Restart service after changes:
```bash
sudo systemctl restart arp-keepalive
```

## Usage

### Service Commands

```bash
# Show status
sudo systemctl status arp-keepalive

# Stop service
sudo systemctl stop arp-keepalive

# Start service
sudo systemctl start arp-keepalive

# Restart service
sudo systemctl restart arp-keepalive

# Disable service
sudo systemctl disable arp-keepalive

# Enable service
sudo systemctl enable arp-keepalive
```

### View Logs

```bash
# Follow live logs
sudo journalctl -u arp-keepalive -f

# Last 100 lines
sudo journalctl -u arp-keepalive -n 100

# Logs since today
sudo journalctl -u arp-keepalive --since today
```

## Uninstallation

```bash
# Stop and disable service
sudo systemctl stop arp-keepalive
sudo systemctl disable arp-keepalive

# Remove files
sudo rm /etc/systemd/system/arp-keepalive.service
sudo rm /usr/local/bin/arp-keepalive.sh
sudo rm -rf /etc/arp-keepalive/

# Reload systemd
sudo systemctl daemon-reload
```

## Troubleshooting

### Service doesn't start

1. Check the logs:
```bash
sudo journalctl -u arp-keepalive -n 50
```

2. Check if interface exists:
```bash
ip link show
```

3. Check the configuration:
```bash
cat /etc/arp-keepalive/config.json
jq . /etc/arp-keepalive/config.json
```

### Dependencies missing

```bash
sudo apt-get update
sudo apt-get install jq arping
```

## Use Case: Proxmox with routed IPs

This script is particularly useful with hosting providers that provide IPs via routing (e.g. /29 or individual /32 IPs). Some hosters require regular ARP packets to keep the routes active.

### Example Scenario

- Hoster routes IP block 2.56.245.72/29 to your Proxmox host
- VMs/Containers use these IPs
- Service regularly sends ARPs so the hoster keeps the route active

## License

Free to use for private and commercial purposes.
