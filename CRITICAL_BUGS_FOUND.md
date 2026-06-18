# 🔴 CRITICAL BUGS FOUND - Must Fix Before UI Redesign

## Test Results
Ran endpoint tests with correct token: `cypher-internal-pc-app-token-2024`

---

## 🔴 CRITICAL (Breaks Core Features)

### 1. `/lock` endpoint - **404 NOT FOUND**
**Severity:** CRITICAL - Users can't lock PC from mobile
**Status:** Endpoint doesn't exist  
**Fix Needed:** Implement `/lock` endpoint
**Code Location:** Need to add in `server.py`
**Expected Behavior:** Calls Windows API to lock screen

**Test Result:**
```
Lock                 FAIL (404)
```

---

### 2. `/sleep` endpoint - **404 NOT FOUND**
**Severity:** CRITICAL - Users can't sleep PC from mobile
**Status:** Endpoint doesn't exist
**Fix Needed:** Implement `/sleep` endpoint  
**Code Location:** Need to add in `server.py`
**Expected Behavior:** Sends PC to sleep mode

**Test Result:**
```
Sleep                FAIL (404)
```

---

### 3. `/screenshot` - **500 ERROR** - pyscreeze import
**Severity:** CRITICAL - Screenshot feature completely broken
**Status:** Dependency missing or import error
**Error:** `PyAutoGUI was unable to import pyscreeze`
**Fix Needed:** 
- Check if `pyscreeze` is installed
- Update imports in `_load_automation()`
- Use alternative if needed (mss, PIL)

**Test Result:**
```
Screenshot           FAIL (500)
Error: PyAutoGUI was unable to import pyscreeze...
```

**Code Location:** `server.py` line 2668 - `pyautogui.screenshot()`

---

### 4. `/media/volume/get` - **500 ERROR** - AudioDevice error
**Severity:** HIGH - Volume controls broken
**Status:** Audio API error
**Error:** `'AudioDevice' object has no attribute 'Activate'`
**Fix Needed:**
- Debug audio device API
- Use alternative audio library if needed
- Graceful fallback if audio unavailable

**Test Result:**
```
Volume GET           FAIL (500)
Error: 'AudioDevice' object has no attribute 'Activate'
```

**Code Location:** `server.py` around line 2737 `_load_audio_engine()`

---

## ✓ WORKING

### 1. Remote Type - ✓ WORKING
```
Type                 PASS
```
Typing text works correctly!

### 2. Clipboard GET - ✓ WORKING  
```
Clipboard GET        PASS
```
Reading PC clipboard works!

---

## 🔧 Implementation Priority

### Phase 1 - Critical (Fix TODAY)
1. [ ] Implement `/lock` endpoint
2. [ ] Implement `/sleep` endpoint
3. [ ] Fix `/screenshot` pyscreeze error
4. [ ] Fix `/media/volume/get` AudioDevice error

### Phase 2 - Testing
5. [ ] Test all 4 fixes work
6. [ ] Test from mobile app
7. [ ] Verify no 401/500 errors

### Phase 3 - Polish (THEN UI Redesign)
8. [ ] Add input validation
9. [ ] Add error messages
10. [ ] Lock down auth on all endpoints

---

## Code Locations to Check

**Need to find where these endpoints SHOULD be:**
```
grep -n "@app.route('/lock" server.py      # Should exist but doesn't
grep -n "@app.route('/sleep" server.py     # Should exist but doesn't  
grep -n "def get_screenshot" server.py     # Line 2661
grep -n "_load_audio_engine" server.py     # Around line 2737
```

---

## Why This Matters

**Without these fixes:**
- Can't lock PC (critical security feature)
- Can't put PC to sleep (power management)
- Can't take screenshots (feature completely broken)
- Can't control volume (convenience feature broken)

**User explicitly said:** "do a very very thorough audit" and "lock down a lot of things" - these are blocking issues that MUST be fixed first.

---

## Next Steps

1. Fix the 4 critical endpoints above
2. Re-run test suite
3. THEN proceed with beautiful UI redesign
4. Don't make it beautiful if core features are broken
