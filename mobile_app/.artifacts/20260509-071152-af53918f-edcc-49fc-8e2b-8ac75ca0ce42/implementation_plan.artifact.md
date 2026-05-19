# Implementation Plan - Share Sheet & WhatsApp Integration

This plan details the addition of Cypher to the Android Share menu and the implementation of WhatsApp media shortcuts.

## User Review Required

- **Dependencies**: Requires adding `receive_sharing_intent: ^1.6.3` to `pubspec.yaml`.
- **System Integration**: Modifying `AndroidManifest.xml` to register Cypher for `SEND` intents.
- **Background Handling**: Share sheet actions will launch the app and navigate directly to the "Send to PC" screen.

## Proposed Changes

### [Mobile App] Share Sheet Integration

#### [pubspec.yaml](file:///C:/Cypher/mobile_app/pubspec.yaml)
- Add: `receive_sharing_intent: ^1.6.3`.

#### [AndroidManifest.xml](file:///C:/Cypher/mobile_app/android/app/src/main/AndroidManifest.xml)
- Add `<intent-filter>` for `action.SEND` and `action.SEND_MULTIPLE` to handle images, videos, and files.

#### [main.dart](file:///C:/Cypher/mobile_app/lib/main.dart)
- Initialize `ReceiveSharingIntent` to listen for incoming shares.
- Logic: If a share is received, navigate the user to `/send_to_pc` with the shared files pre-loaded.

---

### [Mobile App] WhatsApp & Quick Access

#### [phone_browser_screen.dart](file:///C:/Cypher/mobile_app/lib/screens/phone_browser_screen.dart)
- **Shortcut Section**: Add a horizontal list at the top for "Quick Folders":
    - **WhatsApp Images**: Direct link to `/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images`.
    - **Downloads**: Link to `/storage/emulated/0/Download`.
    - **Camera**: Link to `/storage/emulated/0/DCIM/Camera`.
- This avoids digging through nested folders for the most common items.

## Verification Plan

### Manual Verification
- **Share Sheet**: Open your phone's Gallery or a PDF, click "Share," select **CYPHER**, and verify it opens the "Send to PC" screen with the file ready.
- **WhatsApp Shortcut**: Open "Phone Storage" in Cypher, click the "WhatsApp Images" button, and verify it instantly loads all your WhatsApp photos.
- **Multiple Files**: Select 3 photos in your Gallery and share them to Cypher. Verify all 3 appear in the "Send to PC" queue.
