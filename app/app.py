#!/usr/bin/env python3
"""
WasteFi - Clean WiFi Vendo System
Simple captive portal for Raspberry Pi with Comfast AP
"""

from flask import Flask, request, jsonify, render_template_string
import subprocess
import os
import json
import time
from datetime import datetime

app = Flask(__name__)

# Simple configuration
CONFIG = {
    'ap_interface': 'eth1',      # USB-to-Ethernet to Comfast AP
    'wan_interface': 'wlan1',    # WiFi connection to ISP
    'portal_ip': '192.168.4.1',
    'session_file': '/tmp/wastefi_sessions.json'
}

# Duration options (in seconds)
DURATIONS = {
    'plastic': 10,  # 10 seconds for plastic waste
    'metal': 20,    # 20 seconds for metal waste
    'paper': 30     # 30 seconds for paper waste
}

def run_command(cmd):
    """Execute shell command safely"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def load_sessions():
    """Load active sessions from file"""
    try:
        if os.path.exists(CONFIG['session_file']):
            with open(CONFIG['session_file'], 'r') as f:
                return json.load(f)
    except:
        pass
    return {}

def save_sessions(sessions):
    """Save sessions to file"""
    try:
        with open(CONFIG['session_file'], 'w') as f:
            json.dump(sessions, f)
    except:
        pass

def get_client_ip():
    """Get client IP address"""
    return request.environ.get('HTTP_X_REAL_IP', request.remote_addr)

def cleanup_expired_sessions():
    """Remove expired sessions and their iptables rules"""
    sessions = load_sessions()
    current_time = time.time()
    expired = []
    
    for ip, session in list(sessions.items()):
        if current_time > session['expires']:
            # Remove iptables rule
            cmd = f"iptables -D FORWARD -s {ip} -j ACCEPT 2>/dev/null"
            run_command(cmd)
            expired.append(ip)
            del sessions[ip]
    
    if expired:
        save_sessions(sessions)
        print(f"Cleaned up {len(expired)} expired sessions")

def grant_internet_access(client_ip, duration):
    """Grant internet access to client for specified duration"""
    # Clean up first
    cleanup_expired_sessions()
    
    # Calculate expiry time
    expires = time.time() + duration
    
    # Add iptables rule for this client
    cmd = f"iptables -I FORWARD -s {client_ip} -j ACCEPT"
    success, stdout, stderr = run_command(cmd)
    
    if success:
        # Save session
        sessions = load_sessions()
        sessions[client_ip] = {
            'granted': time.time(),
            'expires': expires,
            'duration': duration
        }
        save_sessions(sessions)
        return True
    
    return False

# HTML Template for captive portal
PORTAL_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WasteFi - WiFi Vendo</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 400px;
            width: 100%;
        }
        
        .logo {
            font-size: 2.5em;
            color: #667eea;
            margin-bottom: 10px;
            font-weight: bold;
        }
        
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 1.1em;
        }
        
        .waste-buttons {
            display: flex;
            flex-direction: column;
            gap: 15px;
            margin-bottom: 30px;
        }
        
        .waste-button {
            background: linear-gradient(135deg, #4CAF50, #45a049);
            color: white;
            border: none;
            padding: 20px;
            border-radius: 12px;
            font-size: 1.1em;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        
        .waste-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(76, 175, 80, 0.3);
        }
        
        .waste-button.plastic {
            background: linear-gradient(135deg, #FF6B6B, #EE5A5A);
        }
        
        .waste-button.metal {
            background: linear-gradient(135deg, #4ECDC4, #44A08D);
        }
        
        .waste-button.paper {
            background: linear-gradient(135deg, #45B7D1, #3498DB);
        }
        
        .waste-button.plastic:hover {
            box-shadow: 0 8px 20px rgba(255, 107, 107, 0.3);
        }
        
        .waste-button.metal:hover {
            box-shadow: 0 8px 20px rgba(78, 205, 196, 0.3);
        }
        
        .waste-button.paper:hover {
            box-shadow: 0 8px 20px rgba(69, 183, 209, 0.3);
        }
        
        .duration {
            font-size: 0.9em;
            opacity: 0.9;
        }
        
        .loading {
            display: none;
            margin-top: 20px;
        }
        
        .spinner {
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            width: 30px;
            height: 30px;
            animation: spin 1s linear infinite;
            margin: 0 auto;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .success {
            background: #4CAF50;
            color: white;
            padding: 15px;
            border-radius: 8px;
            margin-top: 20px;
            display: none;
        }
        
        .error {
            background: #f44336;
            color: white;
            padding: 15px;
            border-radius: 8px;
            margin-top: 20px;
            display: none;
        }
        
        .footer {
            margin-top: 30px;
            font-size: 0.9em;
            color: #999;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🌱 WasteFi</div>
        <div class="subtitle">Turn your waste into WiFi time!</div>
        
        <div class="waste-buttons">
            <button class="waste-button plastic" onclick="selectWaste('plastic')">
                🗂️ Plastic Waste
                <div class="duration">{{ durations.plastic }} seconds</div>
            </button>
            
            <button class="waste-button metal" onclick="selectWaste('metal')">
                🔧 Metal Waste
                <div class="duration">{{ durations.metal }} seconds</div>
            </button>
            
            <button class="waste-button paper" onclick="selectWaste('paper')">
                📄 Paper Waste
                <div class="duration">{{ durations.paper }} seconds</div>
            </button>
        </div>
        
        <div class="loading" id="loading">
            <div class="spinner"></div>
            <p>Activating your internet access...</p>
        </div>
        
        <div class="success" id="success">
            <h3>🎉 Access Granted!</h3>
            <p>Enjoy your internet time!</p>
        </div>
        
        <div class="error" id="error">
            <h3>❌ Error</h3>
            <p id="error-message">Something went wrong. Please try again.</p>
        </div>
        
        <div class="footer">
            <p>Eco-friendly internet access system</p>
            <p>Your IP: {{ client_ip }}</p>
        </div>
    </div>

    <script>
        function selectWaste(wasteType) {
            // Hide buttons and show loading
            document.querySelector('.waste-buttons').style.display = 'none';
            document.getElementById('loading').style.display = 'block';
            
            // Send request to grant access
            fetch('/grant_access', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    waste_type: wasteType
                })
            })
            .then(response => response.json())
            .then(data => {
                document.getElementById('loading').style.display = 'none';
                
                if (data.success) {
                    document.getElementById('success').style.display = 'block';
                    // Redirect to a test page or close after 3 seconds
                    setTimeout(() => {
                        window.location.href = 'http://google.com';
                    }, 3000);
                } else {
                    document.getElementById('error-message').textContent = data.message || 'Failed to grant access';
                    document.getElementById('error').style.display = 'block';
                    // Show buttons again after error
                    setTimeout(() => {
                        document.querySelector('.waste-buttons').style.display = 'flex';
                        document.getElementById('error').style.display = 'none';
                    }, 3000);
                }
            })
            .catch(error => {
                document.getElementById('loading').style.display = 'none';
                document.getElementById('error-message').textContent = 'Network error: ' + error.message;
                document.getElementById('error').style.display = 'block';
                setTimeout(() => {
                    document.querySelector('.waste-buttons').style.display = 'flex';
                    document.getElementById('error').style.display = 'none';
                }, 3000);
            });
        }
    </script>
</body>
</html>
"""

@app.route('/')
def captive_portal():
    """Main captive portal page"""
    client_ip = get_client_ip()
    
    # Check if client already has access
    sessions = load_sessions()
    if client_ip in sessions:
        if time.time() < sessions[client_ip]['expires']:
            # Still has valid access, redirect to internet
            return f"""
            <html>
            <head><meta http-equiv="refresh" content="0;url=http://google.com"></head>
            <body><h1>Redirecting...</h1><p>You already have internet access!</p></body>
            </html>
            """
    
    return render_template_string(PORTAL_TEMPLATE, 
                                durations=DURATIONS, 
                                client_ip=client_ip)

@app.route('/grant_access', methods=['POST'])
def grant_access():
    """Grant internet access based on waste type"""
    try:
        data = request.get_json()
        waste_type = data.get('waste_type')
        client_ip = get_client_ip()
        
        if waste_type not in DURATIONS:
            return jsonify({'success': False, 'message': 'Invalid waste type'})
        
        duration = DURATIONS[waste_type]
        
        if grant_internet_access(client_ip, duration):
            return jsonify({
                'success': True, 
                'message': f'Access granted for {duration} seconds',
                'duration': duration
            })
        else:
            return jsonify({'success': False, 'message': 'Failed to grant access'})
            
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/status')
def status():
    """Check current session status"""
    client_ip = get_client_ip()
    sessions = load_sessions()
    
    if client_ip in sessions:
        session = sessions[client_ip]
        remaining = max(0, session['expires'] - time.time())
        return jsonify({
            'has_access': remaining > 0,
            'remaining_seconds': int(remaining),
            'expires': session['expires']
        })
    
    return jsonify({'has_access': False, 'remaining_seconds': 0})

@app.route('/cleanup')
def cleanup():
    """Manual cleanup endpoint (for debugging)"""
    cleanup_expired_sessions()
    return jsonify({'message': 'Cleanup completed'})

if __name__ == '__main__':
    # Ensure log directory exists
    os.makedirs('/home/pi/wastefi/logs', exist_ok=True)
    
    # Initial cleanup
    cleanup_expired_sessions()
    
    print("WasteFi starting on http://192.168.4.1:80")
    app.run(host='0.0.0.0', port=80, debug=False)