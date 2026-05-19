import sys
import os
import threading
import time
import json
import logging
import traceback
from pathlib import Path

# ----------------------------
# LOGGING
# ----------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
log = logging.getLogger("cypher")

# ----------------------------
# CORE MODULAR IMPORTS
# ----------------------------
try:
    import customtkinter as ctk

    # Correct production-safe imports from core package
    from core.server import app as flask_app
    from core import discovery
    from core import tray
    from core.splash_screen import SplashScreen
    from core.setup_screen import SetupScreen
    from core.dashboard_screen import DashboardScreen
    from core.utils import get_config_path
except Exception as e:
    log.critical(f"Critical import failure: {e}")
    log.critical(traceback.format_exc())
    sys.exit(1)

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
            log.error(traceback.format_exc())

    threading.Thread(target=run, daemon=True).start()
    time.sleep(1.2)

# ----------------------------
# CONFIG LOAD
# ----------------------------
def get_pc_name():
    try:
        settings_path = get_config_path("settings.json")
        if settings_path.exists():
            with open(settings_path, "r") as f:
                return json.load(f).get("device_name", "Cypher PC")
    except Exception as e:
        log.warning(f"Settings error: {e}")
    return "Cypher PC"

# ----------------------------
# DASHBOARD LOADER
# ----------------------------
def load_dashboard(root):
    try:
        log.info("Loading Dashboard Screen...")
        for w in root.winfo_children():
            w.destroy()
        DashboardScreen(root).pack(fill="both", expand=True)
        log.info("Dashboard Screen loaded successfully.")
    except Exception as e:
        log.error(f"Dashboard load failure: {e}")
        log.error(traceback.format_exc())
        # Show emergency error label
        err_lbl = ctk.CTkLabel(root, text=f"UI Error: {e}\nCheck logs for details.", text_color="red")
        err_lbl.pack(expand=True)

# ----------------------------
# UI FLOW
# ----------------------------
def on_splash_complete(root):
    try:
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
    except Exception as e:
        log.error(f"Splash completion failure: {e}")
        log.error(traceback.format_exc())

# ----------------------------
# MAIN
# ----------------------------
def main():
    try:
        log.info("CYPHER starting...")

        start_server()

        pc_name = get_pc_name()

        try:
            discovery.start_discovery_thread(pc_name)
            log.info("Discovery system initialized.")
        except Exception as e:
            log.error(f"Discovery initialization failed: {e}")

        try:
            tray.start_tray()
            log.info("Tray system initialized.")
        except Exception as e:
            log.error(f"Tray initialization failed: {e}")

        # UI
        log.info("Initializing UI Root...")
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

        log.info("Showing Splash Screen...")
        SplashScreen(root, on_complete=lambda: on_splash_complete(root)).pack(
            fill="both",
            expand=True
        )

        root.mainloop()
    except Exception as e:
        log.critical(f"Main loop crashed: {e}")
        log.critical(traceback.format_exc())

if __name__ == "__main__":
    main()
