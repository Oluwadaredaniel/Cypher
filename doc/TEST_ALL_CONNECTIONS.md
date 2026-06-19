# CYPHER - Complete Connection Test Plan

Test all 5 connection methods to validate the IP detection fix works universally.

---

## 📊 Test Matrix

| # | Connection Type | Status | IP Range | Notes |
|---|---|---|---|---|
| 1 | USB Tethering | ? | 192.168.19.x | Currently fixing |
| 2 | Android Hotspot | ? | 192.168.43.x | Phone creates, PC connects |
| 3 | Windows Hotspot | ? | 192.168.137.x | PC creates, Phone connects |
| 4 | WiFi (same router) | ? | 10.x / 192.168.x | Both on home network |
| 5 | LAN (Ethernet) | ? | Any private | Wired connection |

---

## 🧪 Test #1: USB Tethering (192.168.19.x)

### Setup
```bash
# On Phone
Settings → USB Tethering → Enable

# On PC
Should auto-connect to USB device
```

### PC Side
```bash
cd pc_app_flutter/backend
python3 test_all_connections.py
```
Expected output: `Connection Type: USB TETHERING` with IP `192.168.19.x`

### Mobile App
```bash
cd mobile_app
flutter run
```
- [ ] Discovery shows PC name `Emerald-b832df95`
- [ ] IP shown in discovery matches PC's `192.168.19.x`
- [ ] Click → connects to pairing screen
- [ ] Enter pairing code → successful auth
- [ ] Can access PC features (stats, clipboard, etc.)

### Results
```
Status: ✓ PASS / ✗ FAIL
PC IP Detected: ___________
Mobile Discovery IP: ___________
Notes: ___________
```

---

## 🧪 Test #2: Android WiFi Hotspot (192.168.43.x)

### Setup
```bash
# On Phone
Settings → Tethering → WiFi Hotspot → Enable
Network name: "CYPHER-TEST" (any name)

# On PC
Connect to "CYPHER-TEST" WiFi
```

### PC Side
```bash
cd pc_app_flutter/backend
python3 test_all_connections.py
```
Expected output: `Connection Type: ANDROID HOTSPOT` with IP `192.168.43.x`

### Mobile App
```bash
cd mobile_app
flutter run
```
- [ ] Discovery shows PC (via mDNS on same hotspot)
- [ ] IP shown matches PC's `192.168.43.x`
- [ ] Pairing works
- [ ] Features work

### Results
```
Status: ✓ PASS / ✗ FAIL
PC IP Detected: ___________
Mobile Discovery IP: ___________
Notes: ___________
```

---

## 🧪 Test #3: Windows Hotspot (192.168.137.x)

### Setup
```bash
# On PC
Settings → Network & Internet → Mobile hotspot
Turn on hotspot → Share internet from: [your internet]

# On Phone
Connect to PC's hotspot
```

### PC Side
```bash
cd pc_app_flutter/backend
python3 test_all_connections.py
```
Expected output: `Connection Type: WINDOWS HOTSPOT` with IP `192.168.137.x`

### Mobile App
**NOTE: This is tricky - Phone needs to find PC on same hotspot**

Option A (mDNS Discovery):
```bash
cd mobile_app
flutter run
# Check if it discovers PC via Bonjour
```
- [ ] Discovery works via mDNS

Option B (Manual IP Entry):
```bash
# In mobile app connection screen
Enter PC IP manually: 192.168.137.x
```
- [ ] Manual entry works
- [ ] Pairing succeeds
- [ ] Features work

### Results
```
Status: ✓ PASS / ✗ FAIL
PC IP Detected: ___________
Mobile Discovery IP: ___________
Manual Entry Works: YES / NO
Notes: ___________
```

---

## 🧪 Test #4: WiFi (Same Router - 10.x or 192.168.x)

### Setup
```bash
# Both on same WiFi network
# PC: Connected to home WiFi
# Phone: Connected to same home WiFi
```

### PC Side
```bash
cd pc_app_flutter/backend
python3 test_all_connections.py
```
Expected output: `Connection Type: WIFI or LAN` with IP `10.x` or `192.168.x`

### Mobile App
```bash
cd mobile_app
flutter run
```
- [ ] Discovery shows PC (via mDNS)
- [ ] IP shown matches PC's WiFi IP
- [ ] Pairing works
- [ ] Features work

### Results
```
Status: ✓ PASS / ✗ FAIL
PC IP Detected: ___________
Mobile Discovery IP: ___________
Notes: ___________
```

---

## 🧪 Test #5: LAN (Ethernet - Any Private IP)

### Setup
```bash
# Both connected via Ethernet to same network
# PC: Ethernet cable to router/switch
# Phone: (Usually USB-C to Ethernet adapter)
```

### PC Side
```bash
cd pc_app_flutter/backend
python3 test_all_connections.py
```
Expected output: `Connection Type: WIFI or LAN` with Ethernet IP

### Mobile App
```bash
cd mobile_app
flutter run
```
- [ ] Discovery shows PC
- [ ] IP shown matches PC's LAN IP
- [ ] Pairing works
- [ ] Features work

### Results
```
Status: ✓ PASS / ✗ FAIL
PC IP Detected: ___________
Mobile Discovery IP: ___________
Notes: ___________
```

---

## 📋 Summary Checklist

### Before Testing
- [ ] Latest code pulled from GitHub
- [ ] PC app compiled and ready
- [ ] Mobile app compiled and ready
- [ ] Backend running and accessible

### During Testing
- [ ] Test #1: USB Tethering
- [ ] Test #2: Android Hotspot
- [ ] Test #3: Windows Hotspot
- [ ] Test #4: WiFi (same router)
- [ ] Test #5: LAN (Ethernet)

### Issues Found
```
Issue 1: ___________
  Connection: ___________
  Symptom: ___________
  
Issue 2: ___________
  Connection: ___________
  Symptom: ___________
```

---

## 🚀 How to Run Tests

### Quick Version (Run all in sequence)
```bash
# Test setup - start from Cypher root
cd pc_app_flutter

# 1. For each connection type:
#    a) Setup connection on PC and Phone
#    b) Run diagnostic:
cd backend && python3 test_all_connections.py
#    c) Test mobile discovery:
cd ../../mobile_app && flutter run
#    d) Record results
```

### Full Version (With Flutter hot reload)
```bash
# Terminal 1 - PC App (stays running)
cd pc_app_flutter
flutter run -d windows

# Terminal 2 - Backend diagnostic (run for each test)
cd pc_app_flutter/backend
python3 test_all_connections.py

# Terminal 3 - Mobile App (hot reload for each test)
cd mobile_app
flutter run
# Use 'r' for hot reload when connection changes
```

---

## 📝 Notes

- Each test should take ~5-10 minutes
- Mobile app mDNS discovery might take 30-60 seconds
- If discovery fails, manual IP entry is a fallback
- Report ALL findings - even partial failures help identify issues
