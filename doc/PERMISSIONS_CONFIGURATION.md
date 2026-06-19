# ✅ CYPHER - Complete Permissions Configuration

## 📱 ANDROID PERMISSIONS

**File:** `android/app/src/main/AndroidManifest.xml`

### Network & Discovery
- ✅ `INTERNET` - Network connectivity to PC
- ✅ `ACCESS_NETWORK_STATE` - Check network status
- ✅ `CHANGE_WIFI_MULTICAST_STATE` - mDNS discovery
- ✅ `ACCESS_FINE_LOCATION` - Location for local network optimization

### Storage (All Versions)
- ✅ `READ_EXTERNAL_STORAGE` - Read phone files
- ✅ `WRITE_EXTERNAL_STORAGE` - Write to phone storage
- ✅ `MANAGE_EXTERNAL_STORAGE` - Full storage access (Android 11+)

### Media (Android 13+)
- ✅ `READ_MEDIA_IMAGES` - Access to photos
- ✅ `READ_MEDIA_VIDEO` - Access to videos
- ✅ `READ_MEDIA_AUDIO` - Access to audio files

### Camera
- ✅ `CAMERA` - Camera access (future features)

### Share Sheet Integration
- ✅ Intent filters for `ACTION_SEND` - Share single files
- ✅ Intent filters for `ACTION_SEND_MULTIPLE` - Share multiple files

---

## 🍎 iOS PERMISSIONS

**File:** `ios/Runner/Info.plist`

### Local Network Discovery
- ✅ `NSLocalNetworkUsageDescription` - Discover PCs on local network
- ✅ `NSBonjourServices` - mDNS service discovery (_cypher._tcp)

### Photo & File Access
- ✅ `NSPhotoLibraryUsageDescription` - Access photos to share with PC
- ✅ `NSPhotoLibraryAddUsageDescription` - Save screenshots to photo library
- ✅ `NSDocumentsFolderUsageDescription` - Access documents to upload

### Camera
- ✅ `NSCameraUsageDescription` - Camera access for future features

### Location
- ✅ `NSLocationWhenInUseUsageDescription` - Location for network optimization

---

## 🔧 RUNTIME PERMISSION REQUESTS

**File:** `lib/main.dart`

### Permissions Requested at Startup
```dart
await [
  Permission.storage,              // File access
  Permission.manageExternalStorage, // Full storage (Android 11+)
  Permission.camera,               // Camera
  Permission.locationWhenInUse,   // Location
  Permission.photos,              // Photo library
  Permission.mediaLibrary,        // Media access
].request()
```

### Features That Require Permissions

| Feature | Permission | Why |
|---------|-----------|-----|
| Upload files | STORAGE | Read phone files |
| Download files | WRITE_EXTERNAL_STORAGE | Save to Downloads |
| Save screenshots | WRITE_EXTERNAL_STORAGE + PHOTOS | Save to phone |
| PC discovery | CHANGE_WIFI_MULTICAST_STATE | mDNS discovery |
| Share files | CAMERA + STORAGE | File operations |
| Local network | ACCESS_FINE_LOCATION | Network optimization |

---

## ✅ COMPLIANCE

### Android
- [x] All permissions declared in AndroidManifest.xml
- [x] Scoped storage support (Android 11+)
- [x] Runtime permission requests at startup
- [x] Legacy external storage support
- [x] Media permission scoping (Android 13+)

### iOS
- [x] All privacy descriptions in Info.plist
- [x] Bonjour service declared
- [x] Photo library access configured
- [x] Location services configured
- [x] Camera access configured

### Flutter
- [x] permission_handler package integrated
- [x] Comprehensive permission request logic
- [x] Error handling for denied permissions
- [x] Permission status logging for debugging

---

## 🚀 READY FOR SUBMISSION

All necessary permissions are:
- ✅ Declared in manifest files
- ✅ Explained to users with descriptions
- ✅ Requested at runtime
- ✅ Handled for Android 11+ scoped storage
- ✅ Handled for iOS privacy requirements
- ✅ Logged for debugging

**Status: PRODUCTION READY** 🎉
