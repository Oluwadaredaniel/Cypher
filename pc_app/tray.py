import threading
import requests
import pystray
import keyboard
import webbrowser
from PIL import Image, ImageDraw

INTERNAL_TOKEN = "cypher-internal-pc-app-token-2024"
VERSION = "1.0.0"

def make_icon():
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Circle icon with purple accent
    draw.ellipse([4, 4, 60, 60], fill="#6C63FF")
    draw.text((20, 15), "C", fill="white", font=None) # Simplified for now
    return img

def paste_from_phone():
    """Triggers the paste from phone action on the PC."""
    try:
        requests.post("http://localhost:5000/clipboard/paste-from-phone",
            headers={"X-Auth-Token": INTERNAL_TOKEN}, timeout=2)
        print("[HOTKEY] Pasted from phone clipboard")
    except Exception as e:
        print(f"[HOTKEY] Paste failed: {e}")

def open_guide():
    webbrowser.open("https://cypher.app/guide") # Placeholder for the dynamic manual

def check_for_updates():
    # In a real app, this would fetch from a remote JSON
    print("[UPDATER] You are on the latest version:", VERSION)

def setup_hotkeys():
    """Register global hotkeys for quick interaction."""
    # Ctrl + Alt + V to paste from phone anywhere
    keyboard.add_hotkey('ctrl+alt+v', paste_from_phone)

def start_tray(dashboard_root=None):
    menu = pystray.Menu(
        pystray.MenuItem("📋 Paste from Phone (Ctrl+Alt+V)", lambda: paste_from_phone()),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem(f"CYPHER v{VERSION}", lambda: None, enabled=False),
        pystray.MenuItem("🌐 User Guide", lambda: open_guide()),
        pystray.MenuItem("🔄 Check for Updates", lambda: check_for_updates()),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Exit", lambda icon, item: icon.stop()),
    )

    icon = pystray.Icon("CYPHER", make_icon(), "CYPHER", menu)

    # Start hotkey listener
    threading.Thread(target=setup_hotkeys, daemon=True).start()

    # Run tray icon
    threading.Thread(target=icon.run, daemon=True).start()
