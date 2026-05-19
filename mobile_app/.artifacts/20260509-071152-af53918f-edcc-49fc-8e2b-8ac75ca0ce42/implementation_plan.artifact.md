# Implementation Plan - UI Features, Permissions, and File Transfer Fixes

This plan addresses user feedback regarding missing UI features (Cancel buttons, Updates), permission handling, download visibility, and the "Choose Destination" spinner bug.

## User Review Required

> [!NOTE]
> The "Transfer Progress" screen exists in the code but is not currently used for active background transfers. I will focus on fixing the cancellation logic in the screens where transfers are actually initiated (`FileBrowserScreen`, `FilePreviewScreen`, and `SendToPCScreen`).

## Proposed Changes

### File Transfer & Visibility Fixes

#### [send_to_pc_screen.dart](file:///C:/Cypher/mobile_app/lib/screens/send_to_pc_screen.dart)

- Fix the "Choose Destination" spinner by encoding the path parameter and improving error handling.
- Ensure the modal UI updates correctly when folder loading completes.

```dart
// Example fix for URL encoding
final response = await http.get(
  Uri.parse("$_baseUrl/files/list?path=${Uri.encodeComponent(_currentPath)}"),
  headers: _headers,
).timeout(const Duration(seconds: 5));
```

#### [file_preview_screen.dart](file:///C:/Cypher/mobile_app/lib/screens/file_preview_screen.dart)

- Refactor download logic to use `IOSink` for streaming directly to disk, preventing OutOfMemory (OOM) errors on large files.
- Improve `MediaScanner` integration to ensure files show up in the system Downloads app.
- Ensure the Cancel button is prominent and correctly cleans up resources.

#### [file_browser_screen.dart](file:///C:/Cypher/mobile_app/lib/screens/file_browser_screen.dart)

- Similar refactor as `file_preview_screen.dart` to use `IOSink` for downloads.
- Fix the download progress sheet to properly handle cancellation and resource cleanup.

---

### Permissions & Updates

#### [permission_service.dart](file:///C:/Cypher/mobile_app/lib/services/permission_service.dart)

- Ensure `MANAGE_EXTERNAL_STORAGE` is requested on Android 11+ to provide a better user experience for file management.

#### [home_screen.dart](file:///C:/Cypher/mobile_app/lib/screens/home_screen.dart)

- Ensure the update check runs on startup and shows a clear notification.
- Add a visual indicator (badge or icon) to the settings/activity button if an update is available.

#### [settings_screen.dart](file:///C:/Cypher/mobile_app/lib/screens/settings_screen.dart)

- Verify "Check for Updates" button provides immediate feedback.
- Add a "Request All Permissions" button to allow users to easily fix permission issues.

## Verification Plan

### Manual Verification
- **Spinner Fix**: Open "Send to PC", click "Choose Destination", and verify folders load (even those with spaces/special chars) and the spinner stops.
- **Download Visibility**: Download a file and check if it appears in the Android system "Files" -> "Downloads" app immediately.
- **Large File Download**: Attempt to download a file > 500MB to verify that the app doesn't crash (Streaming to file fix).
- **Cancellation**: Start a download/upload and click Cancel. Verify the transfer stops and partial files are cleaned up.
- **Update Check**: Click "Check for Updates" in Settings and verify the "Up to date" or "New version" dialog appears.
- **Permissions**: Clear app data, open app, and verify it asks for Camera, Location, and Storage permissions.
