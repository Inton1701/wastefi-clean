# 🌱 WasteFi - WiFi Vendo System

A clean, simple WiFi vending system that exchanges waste collection for internet time.

## 🎯 Features

- **3 Waste Categories**: Plastic (10s), Metal (20s), Paper (30s)
- **Captive Portal**: Beautiful web interface for waste selection
- **Automatic Setup**: One-command installation
- **Session Management**: Automatic cleanup of expired sessions
- **Simple Hardware**: Raspberry Pi + Comfast AP

## 🔧 Hardware Setup

```
Internet → Raspberry Pi → Comfast AP → WiFi Clients
           eth0/wlan1     eth1        (WasteFi SSID)
```

### Required Hardware:
- Raspberry Pi (any model with Ethernet)
- USB-to-Ethernet adapter 
- Comfast AP device (or any router in bridge mode)
- Internet connection (Ethernet or WiFi)

### Connections:
1. **Pi to Internet**: 
   - Option A: Ethernet cable to `eth0`
   - Option B: WiFi connection via `wlan1`
2. **Pi to AP**: USB-Ethernet adapter (`eth1`) → Comfast AP
3. **Comfast AP**: Configure in bridge mode with SSID "WasteFi"

## 🚀 Installation

### 1. Quick Install
```bash
# Clone or copy files to Pi
cd /home/pi
git clone <repository> wastefi
cd wastefi

# Run installer (will ask for sudo password)
sudo ./install.sh
```

### 2. Manual Setup (if needed)
```bash
# Make install script executable
chmod +x install.sh

# Run with root privileges
sudo ./install.sh
```

## 📱 Usage

### For Users:
1. Connect device to "WasteFi" WiFi network
2. Open any website - you'll be redirected to the portal
3. Select your waste type:
   - 🗂️ **Plastic Waste** → 10 seconds internet
   - 🔧 **Metal Waste** → 20 seconds internet  
   - 📄 **Paper Waste** → 30 seconds internet
4. Enjoy your internet time!

### For Admins:
```bash
# Check system status
./scripts/status.sh

# Restart system
./scripts/restart.sh

# Manual cleanup
./scripts/cleanup.sh

# Grant access manually (for testing)
./scripts/grant_access.sh 192.168.4.15 60
```

## 🔍 System Status

After installation, check if everything is working:

```bash
./scripts/status.sh
```

Should show:
- ✅ All services running
- ✅ Network interfaces configured
- ✅ Portal accessible at http://192.168.4.1

## 🛠️ Troubleshooting

### Common Issues:

**1. No internet connection**
```bash
# Check WAN interface
ip route show default

# If no default route, connect Pi to internet first
```

**2. Portal not accessible**
```bash
# Check if WasteFi service is running
sudo systemctl status wastefi

# Restart if needed
sudo systemctl restart wastefi
```

**3. Devices can't get IP addresses**
```bash
# Check DHCP service
sudo systemctl status dnsmasq

# Check eth1 interface
ip addr show eth1
```

**4. Internet access not working after "payment"**
```bash
# Check iptables rules
sudo iptables -L FORWARD

# Check active sessions
cat /tmp/wastefi_sessions.json
```

### Log Files:
```bash
# WasteFi app logs
sudo journalctl -u wastefi -f

# DNS/DHCP logs  
sudo journalctl -u dnsmasq -f

# System logs
sudo dmesg | tail
```

## 🔧 Configuration

### Change Duration Times:
Edit `app/app.py`:
```python
DURATIONS = {
    'plastic': 30,  # Change from 10 to 30 seconds
    'metal': 60,    # Change from 20 to 60 seconds  
    'paper': 120    # Change from 30 to 120 seconds
}
```

### Change WiFi Network:
Configure your Comfast AP with:
- **SSID**: WasteFi (or your preferred name)
- **Mode**: Bridge/AP mode (not router mode)
- **Security**: Open or WPA2 (optional)

### Change Portal IP:
Edit `app/app.py` and `install.sh`:
```python
CONFIG = {
    'portal_ip': '10.0.0.1',  # Change from 192.168.4.1
    # ... other settings
}
```

## 📁 File Structure

```
wastefi/
├── install.sh              # Main installation script
├── uninstall.sh           # Removal script
├── app/
│   └── app.py             # Flask web application
├── scripts/
│   ├── status.sh          # System status checker
│   ├── restart.sh         # Restart services
│   ├── cleanup.sh         # Clean expired sessions
│   └── grant_access.sh    # Manual access granting
├── logs/                  # Application logs
└── README.md             # This file
```

## 🚫 Uninstall

```bash
sudo ./uninstall.sh
```

Note: This will restore original network configurations but won't automatically remove iptables rules for safety.

## 📞 Support

### Quick Diagnostics:
1. Run `./scripts/status.sh` - all items should be ✅
2. Check portal: `curl http://192.168.4.1` 
3. Test connection: Connect phone to WasteFi network
4. Check logs: `sudo journalctl -u wastefi -n 20`

### Hardware Checklist:
- [ ] Pi connected to internet (eth0 or wlan1)
- [ ] USB-Ethernet adapter connected to Pi
- [ ] Comfast AP connected to USB-Ethernet adapter
- [ ] Comfast AP in bridge mode with SSID "WasteFi"
- [ ] Test device can see and connect to WasteFi network

---

**🌱 Happy eco-friendly WiFi vending!**