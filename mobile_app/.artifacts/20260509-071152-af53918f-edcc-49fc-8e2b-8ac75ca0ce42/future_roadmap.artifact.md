# Cypher Future Roadmap & Technical Concept

This document outlines how the proposed "advanced" features will work technically and provides a list of fresh ideas to make Cypher a powerhouse.

## 1. Feature Concepts: How they will work

### 🔄 Auto-Sync (Background Backup)
*   **The Goal**: Automatically backup Phone photos/screenshots to the PC as soon as you take them.
*   **How it works**:
    1.  **WorkManager**: We use the `WorkManager` package in Flutter to create a background task that runs every 15-30 minutes.
    2.  **Detection**: The task checks the `DCIM` or `Pictures` folder for any new files since the last sync.
    3.  **Silent Upload**: It uses the existing `/files/upload` endpoint to send the files to a dedicated `C:\Users\Name\CypherBackups` folder on the PC.
    4.  **WiFi Only**: We add a setting so it only runs when connected to your home WiFi to save mobile data.

### 🖱️ Remote Mouse & Trackpad
*   **The Goal**: Use your phone screen like a laptop trackpad to move the PC mouse.
*   **How it works**:
    1.  **Input Listener**: A new full-screen "Trackpad" mode in the app that listens for `onPanUpdate` gestures.
    2.  **Delta Math**: We calculate the "Delta" (the distance your finger moved) and send it as a small JSON packet: `{"dx": 10, "dy": -5}`.
    3.  **Low Latency**: Instead of standard HTTP (which can be slow), we can use **WebSockets** or **UDP** for near-zero delay.
    4.  **PyAutoGUI**: On the PC, `pyautogui.moveRel(dx, dy)` moves the actual cursor. Tapping the phone screen sends a `pyautogui.click()`.

### 🖥️ Multi-PC Support
*   **The Goal**: Pair with your Desktop and your Laptop and switch between them easily.
*   **How it works**:
    1.  **Local Database**: Switch from `SharedPreferences` to a simple `SQLite` database on the phone to store multiple PC profiles (IP, Token, Name).
    2.  **Profile Switcher**: A simple dropdown or swipe-to-switch UI on the Home screen.
    3.  **Discovery**: Use the existing `nsd` (Network Service Discovery) to show which of your paired PCs are currently online.

---

## 2. New Feature Ideas (Brainstorm)

### 📈 PC Performance "Oversight"
- **Floating Widget**: A tiny floating window on the phone that shows live PC CPU/RAM usage while you are gaming on the PC.
- **Remote Kill**: If a game freezes, you can "Kill Process" directly from the phone list.

### 🎮 Game Mode Macros
- **Custom Buttons**: Create a screen of big buttons for specific games (e.g., in a flight sim, a button for "Landing Gear" or "Flaps").
- **Voice Commands**: "Hey Cypher, open Chrome" or "Hey Cypher, mute the PC."

### 📂 Smart File Search
- Instead of browsing folders, a **Search Bar** that uses Windows Search index to find any file on your PC instantly and let you download it.

### 🔒 Privacy Lock (Auto-Lock)
- **Distance Lock**: If your phone loses WiFi connection to the PC (meaning you walked out of the house), Cypher automatically locks your PC or puts it to sleep for security.

### 🎥 Remote Camera
- Use your phone's high-quality camera as a **Webcam** for your PC during Zoom/Teams calls (Streaming phone camera feed to PC).

---

## 3. Immediate Polish (Activity Feed)
I have already implemented a "Noise Filter" for the Activity Screen:
- **Removed**: Background pings, status checks, and battery updates.
- **Keep**: File transfers, text typing, screenshots, and power actions.
- **Enhanced**: Log entries now show human-friendly names (e.g., "Pasted text from Phone" instead of `/clipboard/paste`).
