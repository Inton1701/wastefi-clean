#!/bin/bash
# WasteFi Installation Test Script

echo "🧪 WasteFi Installation Test"
echo "=========================="

PASSED=0
FAILED=0

test_step() {
    local description="$1"
    local command="$2"
    
    echo -n "Testing: $description... "
    
    if eval "$command" &>/dev/null; then
        echo "✅ PASS"
        ((PASSED++))
    else
        echo "❌ FAIL"
        ((FAILED++))
    fi
}

# Test 1: Check if running as root or with sudo access
test_step "Root/sudo access" "sudo -n true"

# Test 2: Check required packages
test_step "Python3 installed" "which python3"
test_step "Flask available" "python3 -c 'import flask'"
test_step "iptables available" "which iptables"

# Test 3: Check network interface
test_step "eth1 interface exists" "ip link show eth1"

# Test 4: Check services (if installed)
if systemctl list-unit-files | grep -q wastefi; then
    test_step "WasteFi service exists" "systemctl status wastefi"
    test_step "dnsmasq service exists" "systemctl status dnsmasq"
fi

# Test 5: Check portal accessibility
test_step "Portal IP configured" "ip addr show eth1 | grep 192.168.4.1"

# Test 6: Check internet connectivity
test_step "Internet access available" "ping -c 1 8.8.8.8"

# Test 7: Check file permissions
test_step "Install script executable" "[ -x ./install.sh ]"
test_step "App script executable" "[ -x ./app/app.py ]"

echo
echo "📊 Test Results:"
echo "  ✅ Passed: $PASSED"
echo "  ❌ Failed: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo
    echo "🎉 All tests passed! Your system is ready for WasteFi installation."
    echo "Run: sudo ./install.sh"
else
    echo
    echo "⚠️  Some tests failed. Please address the issues before installation."
    if [ $PASSED -gt 0 ]; then
        echo "But $PASSED tests passed, so you're on the right track!"
    fi
fi

echo
echo "💡 Tips:"
echo "  - Make sure you have a USB-to-Ethernet adapter connected"
echo "  - Ensure internet connectivity via eth0 or wlan1"
echo "  - Run this test as: ./test.sh"
echo "  - Run installer as: sudo ./install.sh"