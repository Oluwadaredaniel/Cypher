# 🏁 CYPHER: Mass Publication Readiness Checklist

Before we push this to production, every single one of these items must be verified. This is the difference between "an app" and "Industry Standard Software".

## 1. 🛡️ Security & Safeguards
- [ ] **Restricted Deletion**: Verify that system files (C:\Windows, etc.) cannot be deleted via the app.
- [ ] **Restricted Uploads**: Verify that files cannot be uploaded to Program Files or System32.
- [ ] **Token Validation**: Ensure every remote command requires the `X-Auth-Token`.
- [ ] **Pairing Integrity**: Ensure a device cannot pair without the exact 6-digit dynamic code.

## 2. ⚡ Performance & Stability
- [ ] **Warp Speed (64KB Buffers)**: Verify file transfer speeds saturate the local WiFi (aiming for 20MB/s+).
- [ ] **Background Mode**: Verify the PC app continues to run in the Tray when the window is closed.
- [ ] **Resource Usage**: Ensure background RAM usage is < 80MB.
- [ ] **Memory Leaks**: Run the app for 1 hour while sending files and monitor for RAM creep.

## 3. 🎨 User Experience (UX)
- [ ] **Transfer Feedback**: PC Dashboard must show the name of the file currently being received.
- [ ] **Success Toasts**: Both Phone and PC must show a "Transfer Complete" notification.
- [ ] **Deletion Confirmation**: Mobile app must prompt "Are you sure?" before deleting a PC file.
- [ ] **Empty States**: Verify "Nothing here yet" screens show when history or files are empty.

## 4. 🔗 Connectivity
- [ ] **mDNS Discovery**: Verify the PC shows up on the phone within 3 seconds of opening the app.
- [ ] **Auto-Reconnect**: Close and reopen the mobile app; it should find the PC without re-pairing.
- [ ] **Multi-Device**: Attempt to connect two phones to one PC (should be supported).

## 5. 📦 Packaging & Branding
- [ ] **Single EXE**: `dist/cypher.exe` must be the only file needed to run the PC side.
- [ ] **Branded APK**: Verify the icon is the "Y" logo and the name is "CYPHER".
- [ ] **Persistent Config**: Restart PC; ensure the paired phone is still remembered.

## 6. 🚀 Distribution & Installation
- [ ] **Pro Installer**: Compile `cypher_setup.iss` with Inno Setup. Verify it creates Start Menu shortcuts.
- [ ] **Uninstaller**: Verify that the app can be cleanly uninstalled via Windows Settings.
- [ ] **Multi-File Stress Test**: Send 10+ photos at once from the mobile app.
- [ ] **Progress Fidelity**: Verify that the PC "Transfers" panel shows accurate percentages and MB/s.
- [ ] **Analytics Audit**: Open `AppData/Roaming/Cypher/analytics_log.json` and ensure it's recording events.
- [ ] **Import Robustness**: Run the installed EXE on a fresh PC to ensure no `ModuleNotFoundError` occurs.
