import os
import sys
import json
from pathlib import Path

# ----------------------------
# PYINSTALLER PATH RESOLUTION
# ----------------------------
def get_resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")

    return os.path.join(base_path, relative_path)

def get_app_data_dir():
    """Returns the persistent directory for application data."""
    if sys.platform == "win32":
        base = os.environ.get("APPDATA") or os.path.expanduser("~\\AppData\\Roaming")
        path = Path(base) / "Cypher"
    elif sys.platform == "darwin":
        path = Path.home() / "Library/Application Support/Cypher"
    else:
        path = Path.home() / ".cypher"

    path.mkdir(parents=True, exist_ok=True)
    return path


def get_config_path(filename):
    """
    Returns full path to a config file inside Cypher app data folder.
    """
    return get_app_data_dir() / filename

def get_metadata():
    """Reads project metadata from the local master file."""
    try:
        # Try to find metadata.json in the app root
        meta_path = get_resource_path("metadata.json")
        if os.path.exists(meta_path):
            with open(meta_path, "r") as f:
                return json.load(f)
    except:
        pass

    # Fallback
    return {
        "app_name": "CYPHER",
        "app_version": "1.0.0",
        "app_publisher": "Emerald Dev"
    }

def log_event(event_type, details):
    """Industry Standard local analytics/event logging."""
    from datetime import datetime

    log_file = get_config_path("analytics_log.json")

    event = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "type": event_type,
        "details": details
    }

    try:
        data = []

        if log_file.exists():
            with open(log_file, "r") as f:
                data = json.load(f)

        data.append(event)

        # Keep only last 500 events
        if len(data) > 500:
            data = data[-500:]

        with open(log_file, "w") as f:
            json.dump(data, f, indent=4)

    except:
        pass
