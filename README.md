# CYPHER — Your PC, In Your Pocket

Control and monitor your Windows PC from your Android phone over your local Wi-Fi network. No cloud, no accounts, no data leaving your network.

---

## What It Does

- **File transfer** — Browse PC files, download to phone, upload from phone
- **Remote control** — Type, send hotkeys, and trigger system actions from your phone
- **System monitoring** — Live CPU, RAM, disk, and battery gauges
- **Clipboard sync** — Copy on PC, paste on phone (and vice versa)
- **Process manager** — View and kill running processes
- **App launcher** — Launch installed apps on your PC
- **Screenshot capture** — Take a screenshot of your PC screen
- **Wake on LAN** — Wake up a sleeping PC remotely
- **PC notifications** — See your PC notifications on your phone

---

## Project Structure

```
CYPHER/
├── mobile_app/          # Flutter Android app (the remote controller)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/     # All app screens
│   │   ├── providers/   # State management (connection, files, system)
│   │   ├── services/    # API, storage, discovery
│   │   ├── widgets/     # Reusable UI components
│   │   └── theme/       # Colors and app theme
│   └── android/
│
├── pc_app_flutter/      # PC-side Flutter + Python backend
│   ├── backend/         # Python Flask server (runs on your Windows PC)
│   │   └── core/        # Server, pairing, file handling, system APIs
│   └── lib/             # PC Flutter UI (system tray app)
│
└── index.html           # Landing page
```

---

## Setup

### PC Side

1. Install Python 3.10+
2. Install dependencies:
   ```bash
   cd pc_app_flutter/backend
   pip install -r requirements.txt
   ```
3. Run the server:
   ```bash
   python main.py
   ```
4. The server starts on port `5000`. A system tray icon will appear.

### Mobile App

1. Install [Flutter](https://flutter.dev/docs/get-started/install)
2. Connect your Android device or start an emulator
3. Build and run:
   ```bash
   cd mobile_app
   flutter pub get
   flutter run
   ```
4. Make sure your phone and PC are on the **same Wi-Fi network**
5. Open the app, tap your PC in the device list, then pair with the code shown on your PC

---

## First-Time Pairing

1. Start the CYPHER server on your PC
2. Open the mobile app — it will scan your local network
3. Tap your PC in the list
4. Enter the 6-digit pairing code shown on your PC screen
5. Done — your phone is now paired and auto-connects next time

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile app | Flutter (Dart) |
| PC backend | Python + Flask |
| PC UI | Flutter (Windows) |
| Device discovery | mDNS / DNS-SD |
| Local storage | SharedPreferences |
| Auth | Token-based (generated at pairing) |

---

## Requirements

- **PC**: Windows 10/11, Python 3.10+
- **Phone**: Android 8.0+
- **Network**: Both devices on the same local Wi-Fi

---

## Contributing

1. Fork the repo
2. Create a branch: `git checkout -b your-feature`
3. Commit your changes
4. Open a pull request

---

## License

MIT
