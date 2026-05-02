import customtkinter as ctk
import threading
import time
import json
from pathlib import Path

CONFIG_FILE = Path("pc_app/cypher_config.json")

def start_server():
    """Start Flask server in background thread."""
    try:
        import server
        t = threading.Thread(
            target=lambda: server.app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False),
            daemon=True
        )
        t.start()
        time.sleep(1.5)
    except Exception as e:
        print(f"[CYPHER] Server error: {e}")

def main():
    start_server()

    # Start mDNS Discovery
    pc_display_name = "Cypher PC"
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r") as f:
                pc_display_name = json.load(f).get("pc_name", "Cypher PC")
        except: pass

    from discovery import start_discovery_thread
    discovery = start_discovery_thread(pc_display_name)

    from tray import start_tray
    start_tray()

    from splash_screen import SplashScreen
    from setup_screen import SetupScreen
    from dashboard_screen import DashboardScreen

    def on_splash_complete(root):
        """Called when splash finishes — decide where to go."""
        for widget in root.winfo_children():
            widget.destroy()

        if CONFIG_FILE.exists():
            # Already set up — show dashboard
            dashboard = DashboardScreen(root)
            dashboard.pack(fill="both", expand=True)
        else:
            # First time — show setup
            def on_setup_complete():
                for w in root.winfo_children():
                    w.destroy()
                dashboard = DashboardScreen(root)
                dashboard.pack(fill="both", expand=True)

            setup = SetupScreen(root, on_setup_complete)
            setup.pack(fill="both", expand=True)

    root = ctk.CTk()
    root.title("CYPHER")
    root.geometry("520x760")
    root.minsize(520, 700)
    root.configure(fg_color="#0D0D0D")

    # Center window
    root.update_idletasks()
    x = (root.winfo_screenwidth() // 2) - 260
    y = (root.winfo_screenheight() // 2) - 380
    root.geometry(f"+{x}+{y}")

    splash = SplashScreen(root, on_complete=lambda: on_splash_complete(root))
    splash.pack(fill="both", expand=True)

    root.mainloop()

if __name__ == "__main__":
    main()
