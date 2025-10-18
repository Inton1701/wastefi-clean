#!/bin/bash

# WasteFi Installation Script
# This script sets up the complete WasteFi system

set -e  # Exit on any error

echo "🌱 WasteFi Installation Starting..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WASTEFI_DIR="$SCRIPT_DIR"

print_step "Installing in directory: $WASTEFI_DIR"

# Update system
print_step "Updating system packages..."
apt update

# Install required packages
print_step "Installing required packages..."
apt install -y python3 python3-pip python3-flask dnsmasq iptables-persistent

# Install Python requirements
print_step "Installing Python packages..."
pip3 install flask

# Create wastefi user if it doesn't exist
if ! id "wastefi" &>/dev/null; then
    print_step "Creating wastefi user..."
    useradd -r -s /bin/false wastefi
fi

# Set up directories and permissions
print_step "Setting up directories..."
mkdir -p /home/pi/wastefi/logs
mkdir -p /tmp
chown -R wastefi:wastefi /home/pi/wastefi/logs
chmod +x "$WASTEFI_DIR/app/app.py"

# Stop conflicting services
print_step "Stopping conflicting services..."
systemctl stop hostapd 2>/dev/null || true
systemctl disable hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true

# Backup original configurations
print_step "Backing up original configurations..."
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup 2>/dev/null || true
cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup 2>/dev/null || true

# Configure dnsmasq
print_step "Configuring dnsmasq..."
cat > /etc/dnsmasq.conf << 'EOF'
# WasteFi dnsmasq configuration

# Interface to use for DHCP
interface=eth1

# DHCP range for clients connecting through Comfast AP
dhcp-range=192.168.4.10,192.168.4.100,255.255.255.0,24h

# DNS server (this machine)
dhcp-option=6,192.168.4.1

# Default gateway (this machine)
dhcp-option=3,192.168.4.1

# Captive portal redirect - redirect all DNS queries to portal
address=/#/192.168.4.1

# Don't read /etc/hosts
no-hosts

# Don't poll /etc/resolv.conf
no-poll

# Cache size
cache-size=1000

# Log DHCP
log-dhcp

# Bind to interface
bind-interfaces
EOF

# Configure network interfaces
print_step "Configuring network interfaces..."
cat > /etc/dhcpcd.conf << 'EOF'
# WasteFi network configuration

# A sample configuration for dhcpcd.
# See dhcpcd.conf(5) for details.

# Allow users of this group to interact with dhcpcd via the control socket.
#controlgroup wheel

# Inform the DHCP server of our hostname for DDNS.
hostname

# Use the hardware address of the interface for the Client ID.
clientid

# Persist interface configuration when dhcpcd exits.
persistent

# Rapid commit support.
# Safe to enable by default because it requires the equivalent option set
# on the server to actually work.
option rapid_commit

# A list of options to request from the DHCP server.
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
# Respect the network MTU. This is applied to DHCP routes.
option interface_mtu

# Request a hostname from the network
option host_name

# Most distributions have NTP support.
#option ntp_servers

# A ServerID is required by RFC2131.
require dhcp_server_identifier

# Generate SLAAC address using the hardware address of the interface
#slaac hwaddr
# OR generate Stable Private IPv6 Addresses based from the DUID
slaac private

# Static IP configuration for eth1 (connection to Comfast AP)
interface eth1
static ip_address=192.168.4.1/24
nohook wpa_supplicant

# Let other interfaces get IP via DHCP (eth0 for ISP, wlan1 for ISP WiFi)
# These will be configured automatically
EOF

# Set up iptables rules
print_step "Configuring firewall rules..."

# Flush existing rules
iptables -F
iptables -t nat -F
iptables -t mangle -F

# Default policies
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (important!)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP on portal interface for captive portal
iptables -A INPUT -i eth1 -p tcp --dport 80 -j ACCEPT

# Allow DHCP
iptables -A INPUT -i eth1 -p udp --dport 67 -j ACCEPT
iptables -A INPUT -i eth1 -p udp --dport 53 -j ACCEPT

# NAT for internet sharing (detect WAN interface automatically)
WAN_INTERFACE=""
if ip route | grep -q "default.*eth0"; then
    WAN_INTERFACE="eth0"
elif ip route | grep -q "default.*wlan1"; then
    WAN_INTERFACE="wlan1"
elif ip route | grep -q "default.*wlan0"; then
    WAN_INTERFACE="wlan0"
fi

if [ -n "$WAN_INTERFACE" ]; then
    print_step "Setting up NAT for WAN interface: $WAN_INTERFACE"
    iptables -t nat -A POSTROUTING -o $WAN_INTERFACE -j MASQUERADE
    iptables -A FORWARD -i $WAN_INTERFACE -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT
else
    print_warning "No WAN interface detected. NAT rules not set up."
    print_warning "You may need to manually configure NAT after connecting to internet."
fi

# Redirect HTTP traffic to captive portal (for clients without access)
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 -j DNAT --to-destination 192.168.4.1:80
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 443 -j DNAT --to-destination 192.168.4.1:80

# Save iptables rules
iptables-save > /etc/iptables/rules.v4

# Enable IP forwarding
print_step "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# Create systemd service
print_step "Creating WasteFi service..."
cat > /etc/systemd/system/wastefi.service << EOF
[Unit]
Description=WasteFi Captive Portal
After=network.target dnsmasq.service
Wants=dnsmasq.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$WASTEFI_DIR
ExecStart=/usr/bin/python3 $WASTEFI_DIR/app/app.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
print_step "Enabling and starting services..."
systemctl daemon-reload
systemctl enable dnsmasq
systemctl enable wastefi

# Restart network services
print_step "Restarting network services..."
systemctl restart dhcpcd
sleep 2
systemctl restart dnsmasq
sleep 2
systemctl restart wastefi

# Create management scripts
print_step "Creating management scripts..."

# Status script
cat > "$WASTEFI_DIR/scripts/status.sh" << 'EOF'
#!/bin/bash
echo "=== WasteFi System Status ==="
echo
echo "Services:"
systemctl is-active wastefi && echo "✓ WasteFi: Running" || echo "✗ WasteFi: Stopped"
systemctl is-active dnsmasq && echo "✓ DNS/DHCP: Running" || echo "✗ DNS/DHCP: Stopped"
systemctl is-active dhcpcd && echo "✓ Network: Running" || echo "✗ Network: Stopped"
echo
echo "Network Interfaces:"
ip addr show eth1 | grep inet || echo "✗ eth1: No IP"
echo
echo "Active Sessions:"
if [ -f /tmp/wastefi_sessions.json ]; then
    python3 -c "
import json, time
try:
    with open('/tmp/wastefi_sessions.json') as f:
        sessions = json.load(f)
    current = time.time()
    active = {ip: s for ip, s in sessions.items() if s['expires'] > current}
    print(f'{len(active)} active sessions')
    for ip, session in active.items():
        remaining = int(session['expires'] - current)
        print(f'  {ip}: {remaining}s remaining')
except:
    print('No sessions file')
"
else
    echo "No sessions file"
fi
EOF

# Restart script
cat > "$WASTEFI_DIR/scripts/restart.sh" << 'EOF'
#!/bin/bash
echo "Restarting WasteFi system..."
sudo systemctl restart dnsmasq
sudo systemctl restart wastefi
echo "Done!"
EOF

# Stop script
cat > "$WASTEFI_DIR/scripts/stop.sh" << 'EOF'
#!/bin/bash
echo "Stopping WasteFi system..."
sudo systemctl stop wastefi
sudo systemctl stop dnsmasq
echo "Done!"
EOF

# Start script
cat > "$WASTEFI_DIR/scripts/start.sh" << 'EOF'
#!/bin/bash
echo "Starting WasteFi system..."
sudo systemctl start dnsmasq
sudo systemctl start wastefi
echo "Done!"
EOF

# Make scripts executable
chmod +x "$WASTEFI_DIR/scripts/"*.sh

# Create uninstall script
cat > "$WASTEFI_DIR/uninstall.sh" << 'EOF'
#!/bin/bash
echo "Uninstalling WasteFi..."
sudo systemctl stop wastefi
sudo systemctl disable wastefi
sudo rm -f /etc/systemd/system/wastefi.service
sudo systemctl daemon-reload

# Restore original configs
sudo cp /etc/dnsmasq.conf.backup /etc/dnsmasq.conf 2>/dev/null || true
sudo cp /etc/dhcpcd.conf.backup /etc/dhcpcd.conf 2>/dev/null || true

# Flush iptables (be careful!)
echo "Note: iptables rules NOT automatically removed for safety."
echo "To remove WasteFi iptables rules, run: sudo iptables -F && sudo iptables -t nat -F"

echo "WasteFi uninstalled."
EOF

chmod +x "$WASTEFI_DIR/uninstall.sh"

# Final status check
print_step "Checking installation..."
sleep 3

if systemctl is-active --quiet wastefi; then
    print_success "WasteFi service is running!"
else
    print_error "WasteFi service failed to start"
    systemctl status wastefi
fi

if systemctl is-active --quiet dnsmasq; then
    print_success "DNS/DHCP service is running!"
else
    print_error "DNS/DHCP service failed to start"
    systemctl status dnsmasq
fi

echo
print_success "🎉 WasteFi installation completed!"
echo
echo "📋 Next Steps:"
echo "1. Connect your Comfast AP to eth1 (USB-to-Ethernet adapter)"
echo "2. Configure Comfast AP in bridge mode with SSID 'WasteFi'"
echo "3. Connect Pi to internet via eth0 (Ethernet) or wlan1 (WiFi)"
echo "4. Test by connecting a device to WasteFi WiFi"
echo
echo "🔧 Management Commands:"
echo "  Check status: ./scripts/status.sh"
echo "  Restart:      ./scripts/restart.sh"
echo "  Start:        ./scripts/start.sh"
echo "  Stop:         ./scripts/stop.sh"
echo
echo "🌐 Portal URL: http://192.168.4.1"
echo "📱 Connect devices to 'WasteFi' network to test"
echo
print_warning "Reboot recommended to ensure all network changes take effect"