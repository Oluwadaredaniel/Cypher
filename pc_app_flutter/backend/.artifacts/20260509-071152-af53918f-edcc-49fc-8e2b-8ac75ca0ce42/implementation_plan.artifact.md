# Implementation Plan - PC UI Overhaul & Feature Fixes

This plan details the visual transformation of the PC application and fixes the visibility of the Guest Access feature.

## User Review Required

- **UI Style**: I am moving towards a "Premium Dark" theme with improved contrast and rounded cards.
- **Guest Access**: I will embed the `GuestPanel` directly into the "Security" tab for easier management.

## Proposed Changes

### [PC App] UI Overhaul & Integration

#### [dashboard_screen.py](file:///C:/Cypher/pc_app/core/dashboard_screen.py)

- **Complete Redesign**: Rewrite the `setup_layout` and `switch_panel` logic to use a more modern sidebar and main content area.
- **Guest Access Integration**: In the `render_security` method, instead of just showing a QR code, I will instantiate and show the `GuestPanel` from `guest_panel.py`.
- **Improved Stat Cards**: Redesign the system stats cards (CPU/RAM/Battery) to look cleaner and more professional.

#### [guest_panel.py](file:///C:/Cypher/pc_app/core/guest_panel.py)

- Update the styling to match the new dashboard design.

---

### [Mobile App] Final Polish

- **Build Commands**: Execute the necessary Flutter build commands to generate the final APK.

## Verification Plan

### Manual Verification
- **PC UI**: Launch the PC app and verify the new sidebar, brand header, and stat cards look modern and "not trash."
- **Guest Panel**: Navigate to the "Security" tab on the PC and verify the "Start Guest Session" UI is visible and functional.
- **Mobile Build**: Verify the APK is generated successfully in `build/app/outputs/flutter-apk/app-release.apk`.
