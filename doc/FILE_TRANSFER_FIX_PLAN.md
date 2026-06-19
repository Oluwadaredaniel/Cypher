# File Transfer & Connection Issues - Fix Plan

## 🔴 Critical Issues Found

### 1. Send to PC Upload Broken
**Problem:** Backend expects full path but mobile sends just "Desktop"
**Backend:** `server.py:1500` - `dest = request.form.get('destination')`
**Fix:** Convert "Desktop"/"Documents" to full Windows paths

**Code to fix:**
```python
# Line 1500 - convert folder names to full paths
desktop_path = str(Path.home() / "Desktop")
documents_path = str(Path.home() / "Documents") 
downloads_path = str(Path.home() / "Downloads")

folder_map = {
    "Desktop": desktop_path,
    "Documents": documents_path,
    "Downloads": downloads_path,
}
dest = folder_map.get(destination, downloads_path)
```

---

### 2. File Browser Navigation Missing
**Problem:** Can't navigate to nested folders (e.g., Documents/Code/project/...)
**Frontend:** `send_to_pc_screen.dart` - Only has 3 folder options
**Fix:** 
1. Add folder browser that lists PC folders
2. Let user select specific destination folder
3. Show folder structure before upload

---

### 3. Download to Phone Not Working
**Problem:** Files not saving to phone Downloads folder
**Frontend Issues:**
- Missing permissions request
- No path to Downloads folder
- No save directory configured

**Fix:**
1. Request STORAGE permission on app startup
2. Get Downloads directory path
3. Save files there with proper permissions
4. Add progress modal during download

---

### 4. App Disconnects When Backgrounded
**Problem:** Connection drops if user leaves app
**Frontend:** Connection heartbeat stops
**Fix:**
1. Configure app to keep background service alive
2. Use Android background task/iOS app refresh
3. Maintain socket connection in background
4. Reconnect automatically when app resumes

---

### 5. No Progress UI for Downloads
**Problem:** User doesn't see download progress
**Fix:**
1. Create progress modal
2. Show file name + size + speed
3. Cancel button
4. Success/error notifications

---

## 🔧 Implementation Order

1. [ ] Fix upload destination path mapping (BACKEND)
2. [ ] Add folder browser to send screen (MOBILE UI)
3. [ ] Fix download to phone (MOBILE)
4. [ ] Add permissions configuration (MOBILE)
5. [ ] Fix app disconnection (MOBILE)
6. [ ] Add download progress modal (MOBILE UI)
7. [ ] Test end-to-end

---

## Files to Modify

**Backend:**
- `/pc_app_flutter/backend/core/server.py` - Line 1500 upload destination

**Mobile:**
- `/mobile_app/lib/screens/send_to_pc_screen.dart` - Add folder browser
- `/mobile_app/lib/services/file_service.dart` - Create file operations service
- `/mobile_app/lib/main.dart` - Add permissions + background service
- `/mobile_app/pubspec.yaml` - Add permissions package if needed
- `/mobile_app/android/AndroidManifest.xml` - Request permissions

---

## Quick Tests After Fix

1. Send file to Documents → should appear in Documents folder
2. Send file to custom nested folder → should appear there
3. Download file → should appear in Phone Downloads
4. Leave app → should stay connected
5. Background app → should reconnect when opened
