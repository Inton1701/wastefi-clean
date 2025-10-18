#!/bin/bash
# WasteFi Restart Script

echo "🔄 Restarting WasteFi system..."

echo "Stopping services..."
sudo systemctl stop wastefi
sudo systemctl stop dnsmasq

echo "Clearing expired sessions..."
sudo rm -f /tmp/wastefi_sessions.json

echo "Restarting network..."
sudo systemctl restart dhcpcd
sleep 2

echo "Starting DNS/DHCP..."
sudo systemctl start dnsmasq
sleep 2

echo "Starting WasteFi portal..."
sudo systemctl start wastefi
sleep 2

echo "✅ Restart complete!"
echo
echo "Status:"
./status.sh