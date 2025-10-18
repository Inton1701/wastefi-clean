#!/bin/bash

# WasteFi Old System Removal Script
# This script completely removes the previous WasteFi installation

set -e  # Exit on any error

echo "🗑️ WasteFi Old System Removal"
echo "============================="

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

print_warning "This will completely remove the old WasteFi system!"
print_warning "Make sure you have backed up any important data."
echo
read -p "Do you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

print_step "Stopping WasteFi services..."

# Stop and disable WasteFi services
systemctl stop wastefi 2>/dev/null || true
systemctl disable wastefi 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true
systemctl stop hostapd 2>/dev/null || true

print_step "Removing service files..."

# Remove systemd service files
rm -f /etc/systemd/system/wastefi.service
rm -f /etc/systemd/system/wastefi-*
systemctl daemon-reload

print_step "Cleaning up processes..."

# Kill any remaining WasteFi processes
pkill -f "wastefi" 2>/dev/null || true
pkill -f "app.py" 2>/dev/null || true

print_step "Removing old WasteFi directories..."

# Remove old WasteFi installations (common locations)
rm -rf /home/pi/wastefi 2>/dev/null || true
rm -rf /opt/wastefi 2>/dev/null || true
rm -rf /usr/local/wastefi 2>/dev/null || true
rm -rf /root/wastefi 2>/dev/null || true

# Remove logs and temporary files
rm -rf /var/log/wastefi 2>/dev/null || true
rm -f /tmp/wastefi* 2>/dev/null || true
rm -f /var/tmp/wastefi* 2>/dev/null || true

print_step "Restoring network configurations..."

# Restore original configurations if backups exist
if [ -f /etc/dnsmasq.conf.backup ]; then
    print_step "Restoring dnsmasq configuration..."
    cp /etc/dnsmasq.conf.backup /etc/dnsmasq.conf
    print_success "dnsmasq.conf restored from backup"
else
    print_step "Resetting dnsmasq configuration..."
    # Create minimal dnsmasq config
    cat > /etc/dnsmasq.conf << 'EOF'
# Configuration file for dnsmasq.
#
# Format is one option per line, legal options are the same
# as the long options legal on the command line. See
# "/usr/sbin/dnsmasq --help" or "man 8 dnsmasq" for details.

# The following two options make you a better netizen, since they
# tell dnsmasq to filter out queries which the public DNS cannot
# answer, and which load the servers (especially the root servers)
# unnecessarily. If you have a dial-on-demand link they also stop
# these requests from bringing up the link unnecessarily.

# Never forward plain names (without a dot or domain part)
domain-needed
# Never forward addresses in the non-routed address spaces.
bogus-priv
EOF
fi

if [ -f /etc/dhcpcd.conf.backup ]; then
    print_step "Restoring dhcpcd configuration..."
    cp /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
    print_success "dhcpcd.conf restored from backup"
else
    print_step "Resetting dhcpcd configuration..."
    # Create default dhcpcd config
    cat > /etc/dhcpcd.conf << 'EOF'
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
option rapid_commit

# A list of options to request from the DHCP server.
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
option interface_mtu

# Most distributions have NTP support.
#option ntp_servers

# Respect the network MTU. This is applied to DHCP routes.
option interface_mtu

# A ServerID is required by RFC2131.
require dhcp_server_identifier

# Generate SLAAC address using the hardware address of the interface
#slaac hwaddr
# OR generate Stable Private IPv6 Addresses based from the DUID
slaac private
EOF
fi

print_step "Cleaning up iptables rules..."

# Save current rules before cleanup
iptables-save > /tmp/iptables_before_cleanup.bak

# Remove WasteFi specific iptables rules
print_warning "Removing WasteFi iptables rules (keeping SSH and basic rules)"

# Remove WasteFi NAT rules
iptables -t nat -D PREROUTING -i eth1 -p tcp --dport 80 -j DNAT --to-destination 192.168.4.1:80 2>/dev/null || true
iptables -t nat -D PREROUTING -i eth1 -p tcp --dport 443 -j DNAT --to-destination 192.168.4.1:80 2>/dev/null || true

# Remove MASQUERADE rules (be careful - don't remove legitimate ones)
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -t nat -D POSTROUTING -o wlan0 -j MASQUERADE 2>/dev/null || true
iptables -t nat -D POSTROUTING -o wlan1 -j MASQUERADE 2>/dev/null || true

# Remove FORWARD rules for 192.168.4.0 network
iptables -D FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i wlan0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i wlan1 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

# Remove any client-specific FORWARD rules (192.168.4.x range)
for ip in $(seq 10 100); do
    iptables -D FORWARD -s 192.168.4.$ip -j ACCEPT 2>/dev/null || true
done

# Remove INPUT rules for port 80 on eth1
iptables -D INPUT -i eth1 -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
iptables -D INPUT -i eth1 -p udp --dport 67 -j ACCEPT 2>/dev/null || true
iptables -D INPUT -i eth1 -p udp --dport 53 -j ACCEPT 2>/dev/null || true

# Save cleaned iptables
iptables-save > /etc/iptables/rules.v4

print_step "Removing hostapd configurations..."

# Remove hostapd configs if they exist
rm -f /etc/hostapd/hostapd.conf.wastefi 2>/dev/null || true
rm -f /etc/default/hostapd.wastefi 2>/dev/null || true

print_step "Cleaning up cron jobs..."

# Remove any WasteFi cron jobs
crontab -l 2>/dev/null | grep -v wastefi | crontab - 2>/dev/null || true

print_step "Removing Python packages (if only used by WasteFi)..."

# Note: We don't automatically remove Flask as it might be used by other apps
print_warning "Flask and other Python packages NOT removed (might be used by other applications)"
print_warning "If you want to remove them manually: pip3 uninstall flask"

print_step "Cleaning up users and groups..."

# Remove wastefi user if it exists
if id "wastefi" &>/dev/null; then
    userdel wastefi 2>/dev/null || true
    print_success "Removed wastefi user"
fi

print_step "Resetting IP forwarding..."

# Reset IP forwarding to default
sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/ip_forward

print_step "Removing RaspiAP conflicts (if any)..."

# If RaspiAP is installed, we need to be more careful
if [ -d "/etc/raspap" ]; then
    print_warning "RaspiAP detected - preserving RaspiAP configurations"
    print_warning "You may need to reconfigure RaspiAP after this cleanup"
else
    # Reset hostapd if no RaspiAP
    systemctl disable hostapd 2>/dev/null || true
fi

print_step "Restarting network services..."

# Restart network services to apply changes
systemctl restart dhcpcd
sleep 2
systemctl restart networking 2>/dev/null || true
sleep 2

# Only restart dnsmasq if it was running before
if systemctl is-enabled dnsmasq &>/dev/null; then
    systemctl restart dnsmasq
else
    systemctl stop dnsmasq 2>/dev/null || true
fi

print_step "Final cleanup..."

# Clear any remaining session files
rm -f /tmp/*wastefi* 2>/dev/null || true
rm -f /var/tmp/*wastefi* 2>/dev/null || true

# Update package database
apt autoremove -y 2>/dev/null || true

print_success "🎉 Old WasteFi system completely removed!"
echo
print_step "System Status After Cleanup:"
echo "  Network interfaces:"
ip addr show | grep -E "eth[0-9]|wlan[0-9]" | grep "inet " || echo "    No static IPs configured"
echo
echo "  Active services:"
systemctl is-active dnsmasq && echo "    ✅ dnsmasq: running" || echo "    ❌ dnsmasq: stopped"
systemctl is-active dhcpcd && echo "    ✅ dhcpcd: running" || echo "    ❌ dhcpcd: stopped"
systemctl is-active hostapd && echo "    ✅ hostapd: running" || echo "    ❌ hostapd: stopped"
echo

print_success "✅ Your Raspberry Pi is now clean and ready for fresh WasteFi installation!"
echo
echo "📋 Next Steps:"
echo "1. Copy the new wastefi-clean directory to your Pi"
echo "2. cd wastefi-clean"
echo "3. sudo ./install.sh"
echo
print_warning "Reboot recommended to ensure all network changes take effect:"
echo "sudo reboot"