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

NEEDS_UPDATE=false
if ! command -v jq &> /dev/null; then
    log_warn "jq is not installed."
    NEEDS_UPDATE=true
fi

if ! command -v arping &> /dev/null; then
    log_warn "arping is not installed."
    NEEDS_UPDATE=true
fi

if [ "$NEEDS_UPDATE" = true ]; then
    log_info "Installing missing dependencies..."
    # Update package list, ignore errors from enterprise repos
    apt-get update 2>&1 | grep -v "enterprise.proxmox.com" || true

    # Install packages individually
    if ! command -v jq &> /dev/null; then
        apt-get install -y jq || {
            log_error "Failed to install jq"
            exit 1
        }
    fi

    if ! command -v arping &> /dev/null; then
        apt-get install -y arping || apt-get install -y iputils-arping || {
            log_error "Failed to install arping"
            exit 1
        }
    fi
fi

log_info "All dependencies are installed"

# Create configuration directory
CONFIG_DIR="/etc/arp-keepalive"
if [[ ! -d "$CONFIG_DIR" ]]; then
    log_info "Creating configuration directory: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
fi

# Check if service already exists and stop it
SERVICE_NAME="arp-keepalive.service"
if systemctl list-unit-files | grep -q "^$SERVICE_NAME"; then
    log_info "Existing service found. Stopping and disabling old service..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    log_info "Old service stopped and disabled"
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
    log_info "Configuration file already exists: $CONFIG_FILE (keeping existing config)"
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
    log_error "Check logs with: journalctl -u arp-keepalive -n 50"
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

# Schedule cleanup of installation directory
INSTALL_DIR="$SCRIPT_DIR"
log_info "Scheduling cleanup of installation directory: $INSTALL_DIR"
cat > /tmp/cleanup-arp-install.sh <<EOF
#!/bin/bash
sleep 3
rm -rf "$INSTALL_DIR"
rm -f /tmp/cleanup-arp-install.sh
EOF
chmod +x /tmp/cleanup-arp-install.sh
nohup /tmp/cleanup-arp-install.sh >/dev/null 2>&1 &
log_info "Installation directory will be removed in 3 seconds..."
