#!/usr/bin/env python3
"""
USB Tethering Detection Test
Tests the improved get_local_ip() function for USB tethering support.
"""

import socket
import psutil

def get_local_ip_improved():
    """Returns the primary IP, prioritizing USB tethering → Android hotspot → Windows hotspot → WiFi/LAN."""
    try:
        all_addrs = psutil.net_if_addrs()

        print("📊 Network Interfaces Detected:")
        print("=" * 60)
        for iface_name, addrs in all_addrs.items():
            for addr in addrs:
                if addr.family == socket.AF_INET:
                    print(f"  {iface_name:15} → {addr.address}")
        print("=" * 60)

        # Priority 1: USB Tethering (192.168.42.x)
        print("\n🔍 Checking Priority 1: USB Tethering (192.168.42.x)...")
        for iface_name, addrs in all_addrs.items():
            if any(x in iface_name.lower() for x in ['usb', 'rndis', 'ncm', 'teth']):
                for addr in addrs:
                    if addr.family == socket.AF_INET and addr.address.startswith("192.168.42."):
                        print(f"  ✅ Found USB tethering: {iface_name} → {addr.address}")
                        return addr.address

        # Priority 2: Phone hotspot (Android = 192.168.43.x)
        print("\n🔍 Checking Priority 2: Android Hotspot (192.168.43.x)...")
        for iface_name, addrs in all_addrs.items():
            for addr in addrs:
                if addr.family == socket.AF_INET and addr.address.startswith("192.168.43."):
                    print(f"  ✅ Found Android hotspot: {iface_name} → {addr.address}")
                    return addr.address

        # Priority 3: Windows built-in hotspot (192.168.137.x)
        print("\n🔍 Checking Priority 3: Windows Hotspot (192.168.137.x)...")
        for iface_name, addrs in all_addrs.items():
            for addr in addrs:
                if addr.family == socket.AF_INET and addr.address.startswith("192.168.137."):
                    print(f"  ✅ Found Windows hotspot: {iface_name} → {addr.address}")
                    return addr.address

        # Priority 4: Active route detection
        print("\n🔍 Checking Priority 4: Active Route Detection...")
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0)
        try:
            s.connect(('10.254.254.254', 1))
            ip = s.getsockname()[0]
            if ip != '127.0.0.1' and not ip.startswith('169.254.'):
                print(f"  ✅ Found via active route: {ip}")
                return ip
        except Exception:
            pass
        finally:
            s.close()

        # Priority 5: Any private range
        print("\n🔍 Checking Priority 5: Any Private Range...")
        for iface_name, addrs in all_addrs.items():
            for addr in addrs:
                if addr.family == socket.AF_INET:
                    a = addr.address
                    if (a.startswith("10.") or a.startswith("192.168.") or a.startswith("172.")):
                        print(f"  ✅ Found private range: {iface_name} → {a}")
                        return a

        print("\n⚠️  No suitable interface found, returning 127.0.0.1")
        return "127.0.0.1"
    except Exception as e:
        print(f"\n❌ Error: {e}")
        return "127.0.0.1"


if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("🛡️  CYPHER USB Tethering Detection Test")
    print("=" * 60)

    ip = get_local_ip_improved()

    print("\n" + "=" * 60)
    print(f"📍 FINAL RESULT: {ip}")
    print("=" * 60)

    if ip.startswith("192.168.42."):
        print("\n✅ USB TETHERING DETECTED - CYPHER will work over USB!")
    elif ip.startswith("192.168.43."):
        print("\n✅ ANDROID HOTSPOT DETECTED - CYPHER will work!")
    elif ip.startswith("192.168.137."):
        print("\n✅ WINDOWS HOTSPOT DETECTED - CYPHER will work!")
    elif ip.startswith("192.168.") or ip.startswith("10."):
        print("\n✅ LOCAL NETWORK DETECTED - CYPHER will work!")
    else:
        print("\n⚠️  No suitable network detected")
