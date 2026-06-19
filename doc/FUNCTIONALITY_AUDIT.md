# CYPHER Functionality Audit & Lock-Down

## 🔍 Issues to Investigate

### 1. Screenshot Endpoint
**Status:** ❓ NEEDS TESTING
**Backend:** `/screenshot` (line 2660) - Uses `pyautogui.screenshot()`
**Mobile:** `ApiService.getScreenshot(ip)` - Expects image/jpeg bytes
**Known Issues:**
- [ ] Works locally?
- [ ] Works over network?
- [ ] Timeout issue? (15s timeout)
- [ ] Permission issue?
- [ ] Return format issue?

**To Fix:**
1. Test PC backend: `curl -H "X-Auth-Token: <token>" http://localhost:5000/screenshot -o test.jpg`
2. Test mobile: tap screenshot button in Controls screen
3. Check logs for errors

---

### 2. Screen Recording
**Status:** ❓ NEEDS TESTING
**Backend:** `/recording/start`, `/recording/stop`, `/recording/status` (lines 2595-2660)
**Mobile:** `startRecording()`, `stopRecording()`, `getRecordingStatus()` 
**Known Issues:**
- [ ] Recording worker thread fails?
- [ ] Codec issue?
- [ ] File permission issue?
- [ ] Overlay manager error?

**To Fix:**
1. Check `recording_state` initialization
2. Verify `recording_worker()` thread doesn't crash
3. Test if file is created in Videos/CYPHER folder
4. Check overlay manager startup

---

### 3. Remote Keyboard/Type
**Status:** ❓ NEEDS TESTING
**Backend:** `/type` (line 2710) - Uses `pyautogui.write()`
**Mobile:** `ApiService.remoteType(ip, text)` 
**Known Issues:**
- [ ] Focus window not set before typing?
- [ ] pyautogui write interval too fast?
- [ ] Special characters cause issues?
- [ ] Timing/race condition?

**To Fix:**
1. Increase pre-type sleep from 0.1s to 0.5s
2. Slow down interval from 0.01 to 0.05
3. Add window focus step before typing
4. Validate input length

---

### 4. Connection Stability
**Status:** ❓ NEEDS TESTING
**Backend:** Heartbeat, auth token validation
**Mobile:** ConnectionProvider heartbeat (line 160)
**Known Issues:**
- [ ] Token expires but still trying to use it?
- [ ] Reconnection fails after disconnect?
- [ ] IP detection still broken for some methods?
- [ ] Timeout values too aggressive?

**To Fix:**
1. Verify token validation on all endpoints
2. Add token refresh mechanism
3. Add connection retry logic (exponential backoff)
4. Increase timeout values where needed

---

### 5. Quick Control: "Get from PC" (Download Files)
**Status:** ❌ NOT IMPLEMENTED (says "Get Clipboard")
**Current:** Only clipboard get exists
**Needed:** 
- Browse PC files
- Download/transfer files to phone

**To Fix:**
1. Use existing FileBrowserScreen for browsing PC
2. Route to `/browser` with download capability
3. Implement file download streaming

---

### 6. API Endpoint Coverage
**Status:** ⚠️ INCOMPLETE
**Need to verify:**
- [ ] `/lock` - does it work?
- [ ] `/shutdown`, `/restart`, `/sleep` - work?
- [ ] `/clipboard` GET/POST - work?
- [ ] `/media/volume/set` - works?
- [ ] `/files` endpoints - work?
- [ ] Token validation on EVERY endpoint

---

## 🧪 Testing Checklist

### Before Building UI, Test These:

#### Phase 1: Connection
- [ ] Start PC app
- [ ] Open mobile app
- [ ] Discover PC ✓/✗
- [ ] Connect successfully ✓/✗
- [ ] Pairing code works ✓/✗
- [ ] Stays connected for 5 min ✓/✗

#### Phase 2: Core Commands (Home Screen)
- [ ] Lock PC - press → PC locks ✓/✗
- [ ] Get Clipboard - press → copies PC clipboard to phone ✓/✗
- [ ] Send to PC - navigate to send screen ✓/✗
- [ ] Screenshot - press → shows image ✓/✗

#### Phase 3: Controls Screen
- [ ] Type text - type "hello world" → appears on PC ✓/✗
- [ ] Hotkey - Ctrl+Alt+Del → works ✓/✗
- [ ] Volume change - slider moves, PC volume changes ✓/✗
- [ ] Mute toggle - works ✓/✗

#### Phase 4: Advanced
- [ ] Screen recording start → file created ✓/✗
- [ ] Screen recording stop → file exists ✓/✗
- [ ] File browser - browse PC files ✓/✗
- [ ] Process list - shows processes ✓/✗
- [ ] App launcher - launch app ✓/✗

#### Phase 5: Stability
- [ ] Kill connection on PC → mobile shows "Disconnected" within 10s ✓/✗
- [ ] Reconnect after PC restart → works ✓/✗
- [ ] 30+ API calls in row → all succeed ✓/✗
- [ ] No token refresh needed for 10 min ✓/✗

---

## 🔒 Lock-Down Checklist

### Authentication
- [ ] Every endpoint validates `X-Auth-Token` header
- [ ] Invalid token returns 401, not error
- [ ] Pairing code is random 6-digit (not predictable)
- [ ] Token stored in secure location

### Connection  
- [ ] IP detection never returns virtual adapter
- [ ] Fallback to active route detection works
- [ ] Handles USB tether, WiFi hotspot, LAN, WiFi all correctly
- [ ] Heartbeat detects disconnection within 10 seconds

### Input Validation
- [ ] `/type` endpoint - max 1000 chars
- [ ] `/clipboard` - max 1MB content
- [ ] `/keyboard/hotkey` - validate key names
- [ ] File paths - no path traversal (`../..`)

### Error Handling
- [ ] All endpoints return proper HTTP status codes
- [ ] No stack traces in error responses
- [ ] Timeout all network calls (30s max)
- [ ] Graceful fallback for missing features

---

## 📝 Action Items

**BEFORE redesigning UI:**
1. Run full test checklist above
2. Fix any failing endpoints
3. Document what works / what doesn't
4. Lock down auth on all endpoints
5. Add input validation everywhere
6. Then proceed with beautiful UI

**Report Format:**
```
SCREENSHOT: ✓ WORKS / ✗ BROKEN
  Error: (if broken)
  Fix: (if needed)

KEYBOARD: ✓ WORKS / ✗ BROKEN
  ...
```

---

## Notes

- User is very particular about functionality being rock-solid before aesthetics
- Connection methods (USB, hotspot, WiFi, LAN) must all work flawlessly
- Commands that "didn't work last time" need investigation + fixes
- Don't assume backend is fine - test everything
