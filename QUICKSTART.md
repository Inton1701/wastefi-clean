# 🚀 WasteFi Quick Start Guide

## Hardware Setup (5 minutes)

1. **Connect to Internet**:
   - Plug Ethernet cable into Pi's `eth0` port, OR
   - Connect Pi to WiFi via `wlan1`

2. **Connect Comfast AP**:
   - Plug USB-to-Ethernet adapter into Pi
   - Connect Comfast AP to USB-Ethernet adapter
   - Power on Comfast AP

3. **Configure Comfast AP**:
   - Connect laptop to Comfast AP default WiFi
   - Open browser → `192.168.1.1` (or check AP label)
   - Set mode to **Bridge/AP** (not Router)
   - Set SSID to **WasteFi**
   - Save settings

## Software Installation (2 minutes)

```bash
# Copy WasteFi files to your Pi
cd /home/pi
# (transfer wastefi-clean folder here)

# Enter directory
cd wastefi-clean

# Test system readiness
./test.sh

# Install WasteFi (requires sudo password)
sudo ./install.sh

# Check status
./scripts/status.sh
```

## Testing (1 minute)

1. **Connect test device** to "WasteFi" network
2. **Open browser** - should redirect to portal
3. **Select waste type** - should grant internet access
4. **Browse internet** - should work for selected duration

## Troubleshooting

### No portal redirection?
```bash
# Check services
./scripts/status.sh

# Restart if needed  
./scripts/restart.sh
```

### No internet after selection?
```bash
# Check if Pi has internet
ping google.com

# Check NAT rules
sudo iptables -t nat -L
```

### Can't connect to WiFi?
- Check Comfast AP is in Bridge mode (not Router mode)
- Verify SSID is set to "WasteFi"
- Check USB-Ethernet connection

## Success Checklist ✅

- [ ] Pi connected to internet
- [ ] Comfast AP in bridge mode  
- [ ] All services running (`./scripts/status.sh`)
- [ ] Portal accessible at `192.168.4.1`
- [ ] Test device can connect to WasteFi
- [ ] Portal shows waste selection page
- [ ] Internet works after waste selection

**🎉 You're ready to start eco-friendly WiFi vending!**

---

*Need help? Check the full README.md or run `./scripts/status.sh` for diagnostics.*