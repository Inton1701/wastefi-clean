#!/bin/bash
# WasteFi Manual Internet Grant Script
# For testing - grants internet access directly without portal

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <client_ip> <duration_seconds>"
    echo "Example: $0 192.168.4.15 30"
    exit 1
fi

CLIENT_IP="$1"
DURATION="$2"

echo "Granting $DURATION seconds of internet access to $CLIENT_IP..."

# Add iptables rule
sudo iptables -I FORWARD -s $CLIENT_IP -j ACCEPT

# Create session file entry
python3 -c "
import json
import time
import os

session_file = '/tmp/wastefi_sessions.json'
sessions = {}

if os.path.exists(session_file):
    try:
        with open(session_file, 'r') as f:
            sessions = json.load(f)
    except:
        pass

sessions['$CLIENT_IP'] = {
    'granted': time.time(),
    'expires': time.time() + $DURATION,
    'duration': $DURATION
}

with open(session_file, 'w') as f:
    json.dump(sessions, f, indent=2)

print(f'Session created for $CLIENT_IP - expires in $DURATION seconds')
"

echo "✅ Internet access granted!"
echo "Test by browsing to google.com from the client device."