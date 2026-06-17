#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import psutil
import socket
import sys
import io

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

print("\n" + "=" * 70)
print("DETAILED NETWORK INTERFACE ANALYSIS")
print("=" * 70)

all_addrs = psutil.net_if_addrs()
all_stats = psutil.net_if_stats()

for iface_name in sorted(all_addrs.keys()):
    addrs = all_addrs[iface_name]
    stats = all_stats.get(iface_name, None)

    is_up = stats.isup if stats else False
    status = "UP  " if is_up else "DOWN"

    print(f"\n[{status}] {iface_name}")

    is_usb = any(x in iface_name.lower() for x in ['usb', 'rndis', 'ncm', 'teth'])
    if is_usb:
        print(f"      --> POTENTIAL USB TETHERING")

    for addr in addrs:
        if addr.family == socket.AF_INET:
            print(f"      IPv4: {addr.address}")
            if addr.address.startswith("192.168.42."):
                print(f"      *** USB TETHERING FOUND! ***")
        elif addr.family == socket.AF_INET6:
            print(f"      IPv6: {addr.address}")

print("\n" + "=" * 70)
print("END OF REPORT")
print("=" * 70)
