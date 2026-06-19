#!/usr/bin/env python3
"""Test critical endpoints that need to work."""
import requests
import json
import time
import sys
import io

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BASE_URL = "http://127.0.0.1:5000"
TEST_TOKEN = "test-token-12345"

def test_endpoint(name, method, path, data=None, expected_status=None):
    """Test a single endpoint."""
    try:
        if method == "GET":
            res = requests.get(
                f"{BASE_URL}{path}",
                headers={"X-Auth-Token": TEST_TOKEN},
                timeout=5
            )
        else:  # POST
            res = requests.post(
                f"{BASE_URL}{path}",
                headers={"X-Auth-Token": TEST_TOKEN, "Content-Type": "application/json"},
                json=data or {},
                timeout=5
            )

        status_ok = expected_status is None or res.status_code == expected_status
        result = "PASS" if status_ok else f"FAIL (got {res.status_code})"
        print(f"  {name:30} {result}")

        if not status_ok:
            print(f"    Response: {res.text[:100]}")
        return status_ok
    except requests.exceptions.Timeout:
        print(f"  {name:30} TIMEOUT")
        return False
    except Exception as e:
        print(f"  {name:30} ERROR: {str(e)[:50]}")
        return False

print("\n" + "=" * 70)
print("CYPHER CRITICAL ENDPOINTS TEST")
print("=" * 70)

print("\n[1] Connection & Status")
test_endpoint("GET /ping", "GET", "/ping", expected_status=200)
test_endpoint("GET /status", "GET", "/status", expected_status=200)
test_endpoint("GET /connection-info", "GET", "/connection-info", expected_status=200)

print("\n[2] Lock & Power Commands")
test_endpoint("POST /lock", "POST", "/lock", expected_status=200)
test_endpoint("POST /shutdown (no-confirm)", "POST", "/shutdown", {"confirm": False}, expected_status=200)
test_endpoint("POST /restart (no-confirm)", "POST", "/restart", {"confirm": False}, expected_status=200)
test_endpoint("POST /sleep", "POST", "/sleep", expected_status=200)

print("\n[3] Clipboard")
test_endpoint("GET /clipboard", "GET", "/clipboard", expected_status=200)
test_endpoint("POST /clipboard (set)", "POST", "/clipboard", {"content": "test"}, expected_status=200)

print("\n[4] Input/Keyboard")
test_endpoint("POST /type", "POST", "/type", {"text": "hello"}, expected_status=200)
test_endpoint("POST /keyboard/hotkey", "POST", "/keyboard/hotkey", {"keys": ["alt", "tab"]}, expected_status=200)

print("\n[5] Screenshot")
test_endpoint("GET /screenshot", "GET", "/screenshot", expected_status=200)

print("\n[6] Recording")
test_endpoint("POST /recording/start", "POST", "/recording/start", {"source": "fullscreen"}, expected_status=200)
test_endpoint("GET /recording/status", "GET", "/recording/status", expected_status=200)
test_endpoint("POST /recording/stop", "POST", "/recording/stop", expected_status=200)

print("\n[7] Volume")
test_endpoint("GET /media/volume/get", "GET", "/media/volume/get", expected_status=200)
test_endpoint("POST /media/volume/set", "POST", "/media/volume/set", {"volume": 50}, expected_status=200)

print("\n[8] System Stats")
test_endpoint("GET /system-stats", "GET", "/system-stats", expected_status=200)
test_endpoint("GET /system-info", "GET", "/system-info", expected_status=200)

print("\n" + "=" * 70)
print("TEST COMPLETE")
print("=" * 70)
print("\nResult: Check which ones FAILED - those need fixing")
print("To debug: Check backend logs and error responses above")
