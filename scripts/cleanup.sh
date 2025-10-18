#!/bin/bash
# WasteFi Cleanup Script - Remove expired sessions

echo "🧹 Cleaning up expired sessions..."

# Count before
BEFORE=0
if [ -f /tmp/wastefi_sessions.json ]; then
    BEFORE=$(python3 -c "
import json
try:
    with open('/tmp/wastefi_sessions.json') as f:
        sessions = json.load(f)
    print(len(sessions))
except:
    print(0)
")
fi

# Run cleanup
python3 -c "
import json
import time
import subprocess
import os

session_file = '/tmp/wastefi_sessions.json'
if not os.path.exists(session_file):
    print('No sessions file found')
    exit()

try:
    with open(session_file, 'r') as f:
        sessions = json.load(f)
except:
    print('Error reading sessions file')
    exit()

current_time = time.time()
expired_ips = []
active_sessions = {}

for ip, session in sessions.items():
    if current_time > session['expires']:
        expired_ips.append(ip)
        # Remove iptables rule
        cmd = f'iptables -D FORWARD -s {ip} -j ACCEPT'
        try:
            subprocess.run(cmd, shell=True, capture_output=True)
        except:
            pass
    else:
        active_sessions[ip] = session

# Save updated sessions
with open(session_file, 'w') as f:
    json.dump(active_sessions, f, indent=2)

print(f'Removed {len(expired_ips)} expired sessions')
if expired_ips:
    print('Expired IPs:', ', '.join(expired_ips))
print(f'{len(active_sessions)} active sessions remaining')
"

echo "✅ Cleanup complete!"