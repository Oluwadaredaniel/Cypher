import os
import sys

import threading
import time
import json
import logging
import ctypes
import subprocess
import warnings
from pathlib import Path

# --- SUPPRESS DEPRECATIONS ---
warnings.filterwarnings("ignore", category=DeprecationWarning)

# --- SINGLE INSTANCE LOCK ---
def ensure_single_instance():
    """Uses a named mutex to prevent multiple instances of the backend service."""
    if sys.platform == 'win32':
        mutex_name = "Global\\CypherBackendServiceMutex"
        # CreateMutexW returns a handle to the mutex
        kernel32 = ctypes.windll.kernel32
        mutex = kernel32.CreateMutexW(None, False, mutex_name)
        last_error = kernel32.GetLastError()

        # ERROR_ALREADY_EXISTS = 183
        if last_error == 183:
            print("CYPHER Backend is already running. Exiting.")
            sys.exit(0)
        # We must keep the mutex handle alive for the duration of the process
        return mutex
    return None

# Keep reference to mutex so it's not garbage collected
_instance_mutex = None

# Set up logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
log = logging.getLogger("cypher")

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def elevate():
    """Triggers the Windows UAC prompt to run this script as Administrator."""
    if not is_admin():
        log.info("Requesting Administrator privileges...")
        # Get absolute path to the script to ensure it can be found after elevation
        script = os.path.abspath(sys.argv[0])
        # Prepare parameters, ensuring the script path is quoted if it contains spaces
        params = f'"{script}"'
        if len(sys.argv) > 1:
            params += " " + " ".join(sys.argv[1:])

        # 'runas' is the verb that triggers UAC
        # We also pass the directory explicitly to maintain the working environment
        directory = os.path.dirname(script)

        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable, params, directory, 1
        )
        sys.exit(0)

def register_firewall():
    """Ensures the PC allows connections from the mobile app through the Windows Firewall."""
    if not is_admin():
        return

    log.info("Checking System Firewall rules...")
    try:
        # Check if rule exists
        check_cmd = 'netsh advfirewall firewall show rule name="CYPHER_BRIDGE"'
        result = subprocess.run(check_cmd, capture_output=True, text=True, shell=True)

        if "no rules match" in result.stdout.lower() or result.returncode != 0:
            log.info("Registering CYPHER in Windows Firewall...")
            # Add rule for the API port and the Discovery port
            add_cmd = 'netsh advfirewall firewall add rule name="CYPHER_BRIDGE" dir=in action=allow protocol=TCP localport=5000,5001'
            subprocess.run(add_cmd, shell=True, capture_output=True)

            # Also allow UDP for Discovery
            add_udp = 'netsh advfirewall firewall add rule name="CYPHER_DISCOVERY" dir=in action=allow protocol=UDP localport=5001,5002'
            subprocess.run(add_udp, shell=True, capture_output=True)

            log.info("Firewall configured successfully.")
        else:
            log.info("Firewall rules already present.")
    except Exception as e:
        log.error(f"Failed to configure firewall: {e}")

def get_pc_name():
    try:
        # Avoid circular import by importing here
        from core.utils import get_config_path
        settings_path = get_config_path("settings.json")
        if settings_path.exists():
            with open(settings_path, "r") as f:
                return json.load(f).get("device_name", "Cypher PC")
    except: pass
    return "Cypher PC"

def start_server(flask_app, socketio):
    def run():
        log.info("Starting High-Performance Node on port 5000...")
        socketio.run(flask_app, host="0.0.0.0", port=5000, debug=False, use_reloader=False)
    threading.Thread(target=run, daemon=True).start()

def main():
    # 🚀 Step -1: Single Instance Check
    global _instance_mutex
    _instance_mutex = ensure_single_instance()

    # 🚀 Step 0: Elevation Strategy
    if not is_admin():
        check_cmd = 'netsh advfirewall firewall show rule name="CYPHER_BRIDGE"'
        result = subprocess.run(check_cmd, capture_output=True, text=True, shell=True)
        if "no rules match" in result.stdout.lower():
            log.info("System configuration missing. Requesting one-time elevation...")
            elevate()

    log.info("CYPHER Background Service initializing...")

    # Lazy Load Core Services
    try:
        from core.server import app as flask_app, socketio
        from core import discovery
        from core import tray
    except ImportError as e:
        log.critical(f"Failed to import core modules: {e}")
        sys.exit(1)

    # 2. Start the 'Brain' (Server)
    start_server(flask_app, socketio)

    # 3. Start the 'Lighthouse' (Discovery)
    pc_name = get_pc_name()
    discovery.start_discovery_thread(pc_name)

    # 4. Start the 'Control' (Tray Icon)
    tray.start_tray()

    log.info("CYPHER System is now persistent in the background.")

    # Keep the main thread alive
    while True:
        time.sleep(1)

if __name__ == "__main__":
    main()
