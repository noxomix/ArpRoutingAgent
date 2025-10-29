#!/usr/bin/env bash
# ------------------------------------------------------------------
# Installation Script for ARP Keepalive Service
# ------------------------------------------------------------------

set -euo pipefail

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check root privileges
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

log_info "Starting installation of ARP Keepalive Service..."

# Check and install dependencies
log_info "Checking dependencies..."

if ! command -v jq &> /dev/null; then
    log_warn "jq is not installed. Installing jq..."
    apt-get update && apt-get install -y jq
fi

if ! command -v arping &> /dev/null; then
    log_warn "arping is not installed. Installing arping..."
    apt-get update && apt-get install -y arping
fi

log_info "All dependencies are installed"

# Create configuration directory
CONFIG_DIR="/etc/arp-keepalive"
if [[ ! -d "$CONFIG_DIR" ]]; then
    log_info "Creating configuration directory: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
fi

# Create configuration file (if not present)
CONFIG_FILE="$CONFIG_DIR/config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_info "Creating configuration file: $CONFIG_FILE"
    cat > "$CONFIG_FILE" <<'EOF'
{
  "interface": "vmbr0",
  "interval": 60,
  "ips": []
}
EOF
    log_warn "Configuration file created with default values"
    log_warn "Please edit: $CONFIG_FILE"
else
    log_info "Configuration file already exists: $CONFIG_FILE"
fi

# Copy script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="$SCRIPT_DIR/files"
SCRIPT_SOURCE="$FILES_DIR/arp-keepalive.sh"
SCRIPT_DEST="/usr/local/bin/arp-keepalive.sh"

if [[ -f "$SCRIPT_SOURCE" ]]; then
    log_info "Copying script to: $SCRIPT_DEST"
    cp "$SCRIPT_SOURCE" "$SCRIPT_DEST"
    chmod +x "$SCRIPT_DEST"
else
    log_error "Script not found: $SCRIPT_SOURCE"
    exit 1
fi

# Install systemd service
SERVICE_SOURCE="$FILES_DIR/arp-keepalive.service"
SERVICE_DEST="/etc/systemd/system/arp-keepalive.service"

if [[ -f "$SERVICE_SOURCE" ]]; then
    log_info "Installing systemd service: $SERVICE_DEST"
    cp "$SERVICE_SOURCE" "$SERVICE_DEST"
else
    log_error "Service file not found: $SERVICE_SOURCE"
    exit 1
fi

# Reload systemd
log_info "Reloading systemd configuration..."
systemctl daemon-reload

# Enable service
log_info "Enabling ARP Keepalive Service..."
systemctl enable arp-keepalive.service

# Start service
log_info "Starting ARP Keepalive Service..."
if systemctl start arp-keepalive.service; then
    log_info "Service started successfully"
else
    log_error "Service could not be started"
    exit 1
fi

# Show status
echo ""
log_info "Installation completed!"
echo ""
echo "Useful commands:"
echo "  - Show status:            systemctl status arp-keepalive"
echo "  - Stop service:           systemctl stop arp-keepalive"
echo "  - Start service:          systemctl start arp-keepalive"
echo "  - Restart service:        systemctl restart arp-keepalive"
echo "  - Show logs:              journalctl -u arp-keepalive -f"
echo "  - Edit configuration:     nano $CONFIG_FILE"
echo ""
log_warn "IMPORTANT: Please configure the IPs in: $CONFIG_FILE"
log_warn "After changes restart service: systemctl restart arp-keepalive"
echo ""

# Output status
systemctl status arp-keepalive --no-pager
