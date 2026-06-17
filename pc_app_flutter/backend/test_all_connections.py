#!/usr/bin/env python3
"""
Comprehensive test for get_local_ip() across all connection types.
Logs which interface would be selected and its IP for each scenario.
"""
import psutil
import socket
import sys
import io
from datetime import datetime

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from core.server import get_local_ip

print("\n" + "=" * 80)
print(f"CYPHER CONNECTION TEST - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print("=" * 80)

all_addrs = psutil.net_if_addrs()
all_stats = psutil.net_if_stats()

# Test 1: Active route detection
print("\n[TEST 1] Active Route Detection (Primary Strategy)")
print("-" * 80)
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(0)
try:
    s.connect(('10.254.254.254', 1))
    active_ip = s.getsockname()[0]
    print(f"✓ Internet-connected interface IP: {active_ip}")
except Exception as e:
    print(f"✗ Failed: {e}")
finally:
    s.close()

# Test 2: get_local_ip() function
print("\n[TEST 2] get_local_ip() Function Result")
print("-" * 80)
detected_ip = get_local_ip()
print(f"✓ Detected IP: {detected_ip}")

# Test 3: All UP interfaces
print("\n[TEST 3] All UP Interfaces (Candidates)")
print("-" * 80)
up_interfaces = []
for iface_name in sorted(all_addrs.keys()):
    if iface_name in all_stats and all_stats[iface_name].isup:
        for addr in all_addrs[iface_name]:
            if addr.family == socket.AF_INET and not addr.address.startswith('127.'):
                up_interfaces.append((iface_name, addr.address))
                print(f"  {iface_name:30} → {addr.address}")

# Test 4: Connection type classification
print("\n[TEST 4] Connection Type Classification")
print("-" * 80)
detected_type = "UNKNOWN"

if detected_ip:
    if detected_ip.startswith('192.168.19.'):
        detected_type = "USB TETHERING"
    elif detected_ip.startswith('192.168.42.'):
        detected_type = "USB TETHERING (alternative range)"
    elif detected_ip.startswith('192.168.235.'):
        detected_type = "USB TETHERING (VirtualBox range)"
    elif detected_ip.startswith('192.168.43.'):
        detected_type = "ANDROID HOTSPOT"
    elif detected_ip.startswith('192.168.137.'):
        detected_type = "WINDOWS HOTSPOT"
    elif detected_ip.startswith('10.'):
        detected_type = "WIFI or LAN"
    elif detected_ip.startswith('172.'):
        detected_type = "WIFI or LAN"
    elif detected_ip.startswith('192.168.'):
        detected_type = "WIFI or LAN"

print(f"Connection Type: {detected_type}")
print(f"IP Address:     {detected_ip}")

# Test 5: Expected vs Actual
print("\n[TEST 5] Interface Details for Detected IP")
print("-" * 80)
for iface_name, ip in up_interfaces:
    if ip == detected_ip:
        stats = all_stats[iface_name]
        print(f"Interface:    {iface_name}")
        print(f"IP:           {ip}")
        print(f"Status:       {'UP' if stats.isup else 'DOWN'}")
        print(f"MTU:          {stats.mtu}")
        try:
            io_counters = psutil.net_io_counters(pernic=True).get(iface_name)
            if io_counters:
                print(f"Bytes sent:   {io_counters.bytes_sent}")
                print(f"Bytes recv:   {io_counters.bytes_recv}")
        except:
            pass
        break

print("\n" + "=" * 80)
print("TEST COMPLETE")
print("=" * 80)
print("\nNext Steps:")
print("1. Note the 'Connection Type' above")
print("2. Compare with your actual connection method")
print("3. If mismatch, report the issue")
print()
