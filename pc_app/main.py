import sys
import os
import threading
import time
import json
import logging
from pathlib import Path

# ----------------------------
# CORE MODULAR IMPORTS
# ----------------------------
import customtkinter as ctk

# Correct production-safe imports from core package
from core.server import app as flask_app
from core import discovery
from core import tray
from core.splash_screen import SplashScreen
from core.setup_screen import SetupScreen
from core.dashboard_screen import DashboardScreen
from core.utils import get_config_path

# ----------------------------
# LOGGING
# ----------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [CYPHER] %(levelname)s: %(message)s"
)
log = logging.getLogger("cypher")

# ----------------------------
# CONFIG
# ----------------------------
CONFIG_FILE = get_config_path("cypher_config.json")

# ----------------------------
# SERVER
# ----------------------------
def start_server():
    def run():
        try:
            log.info("Starting Flask server...")
            flask_app.run(
                host="0.0.0.0",
                port=5000,
                debug=False,
                use_reloader=False
            )
        except Exception as e:
            log.error(f"Server crash: {e}")

    threading.Thread(target=run, daemon=True).start()
    time.sleep(1.2)

# ----------------------------
# CONFIG LOAD
# ----------------------------
def get_pc_name():
    try:
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE, "r") as f:
                return json.load(f).get("pc_name", "Cypher PC")
    except Exception as e:
        log.warning(f"Config error: {e}")
    return "Cypher PC"

# ----------------------------
# DASHBOARD LOADER
# ----------------------------
def load_dashboard(root):
    for w in root.winfo_children():
        w.destroy()
    DashboardScreen(root).pack(fill="both", expand=True)

# ----------------------------
# UI FLOW
# ----------------------------
def on_splash_complete(root):
    for widget in root.winfo_children():
        widget.destroy()

    if CONFIG_FILE.exists():
        log.info("Opening dashboard...")
        load_dashboard(root)
    else:
        log.info("Opening setup screen...")
        def setup_done():
            load_dashboard(root)

        SetupScreen(root, on_setup_complete=setup_done).pack(
            fill="both",
            expand=True
        )

# ----------------------------
# MAIN
# ----------------------------
def main():
    log.info("CYPHER starting...")

    start_server()

    pc_name = get_pc_name()

    try:
        discovery.start_discovery_thread(pc_name)
    except Exception as e:
        log.error(f"Discovery error: {e}")

    try:
        tray.start_tray()
    except Exception as e:
        log.error(f"Tray error: {e}")

    # UI
    root = ctk.CTk()
    root.title("CYPHER")
    root.geometry("960x640")
    root.minsize(900, 600)
    root.configure(fg_color="#0D0D0D")

    # Center window
    root.update_idletasks()
    x = (root.winfo_screenwidth() // 2) - 480
    y = (root.winfo_screenheight() // 2) - 320
    root.geometry(f"+{x}+{y}")

    SplashScreen(root, on_complete=lambda: on_splash_complete(root)).pack(
        fill="both",
        expand=True
    )

    root.mainloop()

if __name__ == "__main__":
    main()
