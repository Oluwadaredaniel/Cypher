# Bug Fixes and Future-Proofing for CYPHER PC App

This plan addresses reported crashes in `SetupScreen` and `Tray`, and implements robustness improvements for the `DashboardScreen` including thread safety and network resilience.

## Proposed Changes

### Dashboard & Hub Integration

#### [dashboard_screen.py](file:///C:/Cypher/pc_app/core/dashboard_screen.py)
- Add "Cloud Hub" to the sidebar navigation items.
- Implement `render_hub` method to open the Hub URL in the default browser.
- Ensure all font weights are "normal" or removed.

#### [tray.py](file:///C:/Cypher/pc_app/core/tray.py)
- Add "Open Cloud Hub" option to the system tray menu.

#### [server.py](file:///C:/Cypher/pc_app/core/server.py)
- (Optional) Add a redirect endpoint or information about the Hub if needed for consistency.

#### [setup_screen.py](file:///C:/Cypher/pc_app/core/setup_screen.py)
- Rename `on_complete` parameter in `__init__` to `on_setup_complete` to match `main.py` instantiation.
- Ensure the callback is stored and used correctly.

#### [tray.py](file:///C:/Cypher/pc_app/core/tray.py)
- Replace `pystray.Item` with `pystray.MenuItem` to fix `AttributeError`.
- Ensure imports are clean.

#### [dashboard_screen.py](file:///C:/Cypher/pc_app/core/dashboard_screen.py)
- **Thread Safety**: Wrap all UI updates from threads in `self.after(0, ...)`.
- **Network Resilience**:
    - Add `timeout=1` or `timeout=2` to all `requests` calls.
    - Wrap all network calls in `try/except` blocks.
- **UI Responsiveness**:
    - Move blocking `requests.get` calls in `render_files`, `update_transfers_list`, `update_history_list`, and `update_full_history` into background threads.
    - Use `self.after(0, ...)` to populate UI once data is received.
- **Resource Management**:
    - Initialize all container attributes (`transfers_container`, `activity_container`, etc.) to `None` in `__init__` or ensure they are checked before use.
    - Set `self.stop_polling = True` in a cleanup method or ensure threads exit cleanly.

## Verification Plan

### Automated Tests
- Run `python main.py` and verify:
    - Setup screen opens without crash (if config deleted).
    - Tray icon appears and menu works.
    - Dashboard panels load without freezing.

### Manual Verification
- **Setup Flow**: Delete `cypher_config.json`, run app, complete setup.
- **Tray**: Right-click tray icon, verify "Show Dashboard" and "Exit" work.
- **Dashboard**:
    - Switch between all panels (Home, Transfers, Shared Files, etc.).
    - Verify stats update on Home.
    - Verify file list loads in Shared Files.
    - Verify history loads in Activity.
- **Network Interruption**: Stop the Flask server (if possible) or simulate network delay/failure and ensure UI remains responsive and doesn't crash.
