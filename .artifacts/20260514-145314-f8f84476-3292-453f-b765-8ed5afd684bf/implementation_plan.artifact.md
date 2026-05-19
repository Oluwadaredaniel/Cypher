# Final Feature Logic Audit and Polish (Update-Centric)

This plan ensures that both PC and Mobile apps behave like "normal apps"—automatically notifying users of updates and providing direct links to the latest releases. It also fixes a few missing logical links in the controls.

## User Review Required

- **Landing Page Sync**: I am modifying `server.py` to dynamically fetch the latest download URL from GitHub for the `index.html` landing page. This ensures the "Download" button always points to the latest release without you having to edit the code every time.
- **Update Check Logic**: Mobile app now uses semantic versioning to avoid downgrade prompts.

## Proposed Changes

### PC App (Server & Metadata)

#### [server.py](file:///C:/Cypher/pc_app/core/server.py)

- **New Endpoint**: Add `@app.route('/open-link', methods=['POST'])` to support the mobile app's "Open Link" feature.
- **Dynamic Landing Page**: Modify the `index.html` template rendering to inject the latest `app_updates_url` from `metadata.json` (or a remote fetch) so the web download link is always current.

#### [metadata.json](file:///C:/Cypher/pc_app/metadata.json)

- Add `"app_updates_url": "https://github.com/Oluwadaredaniel/Cypher/releases/latest"` to ensure the "Check for Updates" button has a destination.

---

### Mobile App (Services & Logic)

#### [central_service.dart](file:///C:/Cypher/mobile_app/lib/services/central_service.dart)

- Refine `checkForUpdates` to use semantic version comparison.
- Ensure the update URL provided to the UI is the `app_updates_url` from the remote metadata.

#### [home_screen.dart](file:///C:/Cypher/mobile_app/lib/screens/home_screen.dart)

- Ensure the update banner is prominent and correctly uses the URL returned by `CentralService`.

---

### Global Ecosystem

#### [NEW] [sync_release.py](file:///C:/Cypher/sync_release.py)

- Create a master synchronization script that you run before publishing a new version.
- **Functions**:
    1. Update version in `metadata.json` (PC).
    2. Update version in `pubspec.yaml` (Mobile).
    3. Update version in `cypher_installer.iss` (Inno Setup).
    4. **Update `index.html`**: Scan the landing page and update any version strings or download links to match the new release.
    5. Sync filenames (e.g., if the setup file name changes).

---

#### [index.html](file:///C:/Cypher/index.html)

- Ensure download links are using the most reliable format.
- Add a small "Latest Version: v1.0.0" badge that the sync script can find and update.

## Verification Plan

### Automated Tests
- `curl -X POST http://localhost:5000/open-link -d '{"url": "https://google.com"}'`

### Manual Verification
1. **Landing Page**: Open the guest landing page in a browser and verify the "Download PC App" button points to the GitHub Releases page.
2. **Update Banner**: Mock a remote version `1.0.1` and verify the mobile app shows the "New Version available!" banner with a working "GET APK" button.
