#!/bin/bash
# WasteFi System Status Checker

echo "=== WasteFi System Status ==="
echo

# Check services
echo "🔧 Services:"
if systemctl is-active --quiet wastefi; then
    echo "  ✅ WasteFi Portal: Running"
else
    echo "  ❌ WasteFi Portal: Stopped"
fi

if systemctl is-active --quiet dnsmasq; then
    echo "  ✅ DNS/DHCP: Running"
else
    echo "  ❌ DNS/DHCP: Stopped"
fi

if systemctl is-active --quiet dhcpcd; then
    echo "  ✅ Network Config: Running"
else
    echo "  ❌ Network Config: Stopped"
fi

echo

# Check network interfaces
echo "🌐 Network Interfaces:"
if ip addr show eth1 2>/dev/null | grep -q "192.168.4.1"; then
    echo "  ✅ eth1 (AP): 192.168.4.1"
else
    echo "  ❌ eth1 (AP): Not configured"
fi

# Check WAN connectivity
echo "  📡 WAN Interfaces:"
if ip route | grep -q "default.*eth0"; then
    echo "    ✅ eth0: Connected to internet"
elif ip route | grep -q "default.*wlan1"; then
    echo "    ✅ wlan1: Connected to internet"
elif ip route | grep -q "default.*wlan0"; then
    echo "    ✅ wlan0: Connected to internet"
else
    echo "    ❌ No internet connection detected"
fi

echo

# Check active sessions
echo "👥 Active WiFi Sessions:"
if [ -f /tmp/wastefi_sessions.json ]; then
    python3 -c "
import json, time
try:
    with open('/tmp/wastefi_sessions.json') as f:
        sessions = json.load(f)
    current = time.time()
    active = {ip: s for ip, s in sessions.items() if s['expires'] > current}
    if active:
        print(f'  📱 {len(active)} devices with internet access:')
        for ip, session in active.items():
            remaining = int(session['expires'] - current)
            mins = remaining // 60
            secs = remaining % 60
            if mins > 0:
                time_str = f'{mins}m {secs}s'
            else:
                time_str = f'{secs}s'
            print(f'    • {ip}: {time_str} remaining')
    else:
        print('  📱 No devices currently have internet access')
except Exception as e:
    print(f'  ❌ Error reading sessions: {e}')
"
else
    echo "  📱 No active sessions (sessions file not found)"
fi

echo

# Check if portal is accessible
echo "🔍 Portal Test:"
if curl -s --connect-timeout 3 http://192.168.4.1 > /dev/null; then
    echo "  ✅ Portal is accessible at http://192.168.4.1"
else
    echo "  ❌ Portal is not accessible"
fi

echo

# Show logs
echo "📋 Recent Logs (last 5 lines):"
echo "  WasteFi App:"
journalctl -u wastefi --no-pager -n 3 2>/dev/null | tail -n 3 | sed 's/^/    /'
echo "  DNS/DHCP:"
journalctl -u dnsmasq --no-pager -n 3 2>/dev/null | tail -n 3 | sed 's/^/    /'