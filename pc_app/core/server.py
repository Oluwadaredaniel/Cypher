import os
import socket
import platform
import psutil
import io
import base64
import json
import uuid
import secrets
import random
import time
import zipfile
import threading
import queue
from datetime import datetime, timedelta
from pathlib import Path

# Detect platform
WINDOWS = platform.system() == 'Windows'

# Standard imports (work everywhere)
from flask import Flask, jsonify, request, send_file, Response, stream_with_context
from flask_cors import CORS

# Windows-only imports
if WINDOWS:
    try:
        import ctypes
        import pyautogui
        import pyperclip
        import pygetwindow as gw
        from PIL import Image
        from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
        from comtypes import CLSCTX_ALL
    except ImportError as e:
        print(f"Warning: Some Windows packages not available: {e}")

# Fallback for non-Windows or missing packages
if not WINDOWS or 'pyautogui' not in dir():
    pyautogui = None
    pyperclip = None
    gw = None
    Image = None
    AudioUtilities = None
    IAudioEndpointVolume = None
    ctypes = None
    CLSCTX_ALL = None

app = Flask(__name__)
CORS(app)

# --- CONSTANTS & SECURITY ---
INTERNAL_TOKEN = "cypher-internal-pc-app-token-2024"
if pyautogui:
    pyautogui.FAILSAFE = False  # Prevent server crash if mouse hits screen corner

from core.utils import get_config_path, log_event

# --- GLOBAL STORAGE & PERSISTENCE ---
notifications_list = []
command_history = []
connection_events = []
active_transfers = {}  # Format: {transfer_id: {"name": str, "size": int, "progress": int, "speed": str}}
cancel_all_transfers = False
phone_clipboard = {"content": "", "timestamp": ""}

MACROS_FILE = get_config_path("macros.json")
SETTINGS_FILE = get_config_path("settings.json")
PAIRED_DEVICES_FILE = get_config_path("paired_devices.json")
PAIRING_CODE = str(random.randint(100000, 999999))
paired_devices = {}
valid_tokens = set()

# --- PERSISTENCE HELPERS ---
def load_paired_devices():
    global paired_devices, valid_tokens
    if PAIRED_DEVICES_FILE.exists():
        try:
            with open(PAIRED_DEVICES_FILE, 'r') as f:
                paired_devices = json.load(f)
                for dev in paired_devices.values():
                    valid_tokens.add(dev["token"])
        except Exception as e:
            print(f"Error loading paired devices: {e}")

def save_paired_devices():
    try:
        with open(PAIRED_DEVICES_FILE, 'w') as f:
            json.dump(paired_devices, f, indent=4)
    except Exception as e:
        print(f"Error saving paired devices: {e}")

load_paired_devices()

# --- [UPDATE] RESOURCE MONITORING THREAD ---
resource_usage_history = {"cpu": [], "ram": [], "timestamps": []}

def monitor_resources():
    while True:
        try:
            resource_usage_history["cpu"].append(psutil.cpu_percent(interval=1))
            resource_usage_history["ram"].append(psutil.virtual_memory().percent)
            resource_usage_history["timestamps"].append(datetime.now().strftime("%H:%M:%S"))
            if len(resource_usage_history["cpu"]) > 30:
                resource_usage_history["cpu"].pop(0)
                resource_usage_history["ram"].pop(0)
                resource_usage_history["timestamps"].pop(0)
        except:
            pass
        time.sleep(2)

threading.Thread(target=monitor_resources, daemon=True).start()

# Ensure directories and persistence files exist
if not MACROS_FILE.parent.exists():
    MACROS_FILE.parent.mkdir(parents=True, exist_ok=True)

if not MACROS_FILE.exists():
    with open(MACROS_FILE, 'w') as f:
        json.dump([], f)

# Default Settings & Battery Threshold Initialization
DEFAULT_SETTINGS = {
    "auto_clipboard_sync": False,
    "clipboard_sync_direction": "manual",
    "server_port": 5000,
    "device_name": "My PC",
    "battery_alert_threshold": 20,
    "notifications_enabled": True
}

if not SETTINGS_FILE.exists():
    with open(SETTINGS_FILE, 'w') as f:
        json.dump(DEFAULT_SETTINGS, f, indent=4)
    battery_threshold = 20
else:
    with open(SETTINGS_FILE, 'r') as f:
        current_settings = json.load(f)
        battery_threshold = current_settings.get("battery_alert_threshold", 20)

# --- SECURITY & LOGGING MIDDLEWARE ---

@app.before_request
def verify_token_and_log():
    # [CHAOS FIX] Prevent rapid-fire memory exhaustion from spamming requests
    if request.path == '/screenshot':
        global last_screenshot_time
        now = time.time()
        if 'last_screenshot_time' in globals() and now - last_screenshot_time < 1.0:
            return jsonify({"success": False, "error": "Cooldown active"}), 429
        last_screenshot_time = now

    incoming_token = request.headers.get("X-Auth-Token")
    if incoming_token == INTERNAL_TOKEN:
        return None

    log_entry = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "endpoint": request.path,
        "method": request.method,
        "success": True,
        "details": ""
    }

    # Add extra context to log entries
    if request.path == '/type':
        log_entry["details"] = f"Typed: {request.json.get('text', '')[:20]}"
    elif request.path == '/files/download':
        log_entry["details"] = f"File: {os.path.basename(request.args.get('path', ''))}"
    elif request.path == '/apps/launch':
        log_entry["details"] = f"App: {os.path.basename(request.json.get('path', ''))}"

    # Audit Fix: Ensure these match the actual function names used in @app.route
    public_endpoints = [
        'ping', 'get_status', 'pair_device', 'get_connect_code',
        'get_screenshot', 'get_resource_trends', 'get_display_info'
    ]

    if request.endpoint not in public_endpoints and request.method != 'OPTIONS':
        if not incoming_token or incoming_token not in valid_tokens:
            log_entry["success"] = False
            command_history.append(log_entry)
            if len(command_history) > 100: command_history.pop(0)
            return jsonify({"success": False, "error": "Unauthorized"}), 401

    command_history.append(log_entry)
    if len(command_history) > 100: command_history.pop(0)
    return None

# --- HELPERS ---

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def set_volume(change):
    if not WINDOWS or not AudioUtilities:
        return False
    try:
        devices = AudioUtilities.GetSpeakers()
        interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
        volume = ctypes.cast(interface, ctypes.POINTER(IAudioEndpointVolume))
        current_volume = volume.GetMasterVolumeLevelScalar()
        new_volume = max(0.0, min(1.0, current_volume + change))
        volume.SetMasterVolumeLevelScalar(new_volume, None)
        return True
    except Exception:
        return False

def get_unique_path(target_path):
    path = Path(target_path)
    if not path.exists():
        return str(path)
    parent = path.parent
    name = path.stem
    ext = path.suffix
    counter = 1
    while (parent / f"{name} ({counter}){ext}").exists():
        counter += 1
    return str(parent / f"{name} ({counter}){ext}")

# --- NEW PUBLIC ENDPOINT ---

@app.route('/connect-code', methods=['GET'])
def get_connect_code():
    """Public endpoint to return the current pairing code for the PC dashboard."""
    return jsonify({"code": PAIRING_CODE})

# --- SETTINGS ENDPOINTS ---

@app.route('/settings', methods=['GET', 'POST'])
def handle_settings():
    global battery_threshold
    if request.method == 'GET':
        with open(SETTINGS_FILE, 'r') as f:
            return jsonify(json.load(f))

    new_settings = request.json
    with open(SETTINGS_FILE, 'r+') as f:
        current = json.load(f)
        current.update(new_settings)
        battery_threshold = current.get("battery_alert_threshold", battery_threshold)
        f.seek(0)
        json.dump(current, f, indent=4)
        f.truncate()
    return jsonify({"success": True, "action": "settings_updated"})

# --- PHONE CLIPBOARD BUFFER ---

@app.route('/clipboard/phone', methods=['GET', 'POST'])
def handle_phone_clipboard():
    global phone_clipboard
    if request.method == 'POST':
        phone_clipboard = {
            "content": request.json.get("text", ""),
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        return jsonify({"success": True, "action": "phone_clipboard_saved"})

    return jsonify({"success": True, **phone_clipboard})

@app.route('/clipboard/paste-from-phone', methods=['POST'])
def paste_from_phone():
    if not WINDOWS or not pyperclip:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    if phone_clipboard["content"]:
        log_to_ui("Pasted from Phone")
        pyperclip.copy(phone_clipboard["content"])
        return jsonify({"success": True, "action": "pasted_to_pc"})
    return jsonify({"success": False, "error": "Phone buffer is empty"}), 400

# --- CONNECTION EVENTS ---

@app.route('/events', methods=['GET'])
def get_events():
    return jsonify(connection_events)

@app.route('/events/connected', methods=['POST'])
def log_connect():
    device = request.json.get("device_name", "Unknown Device")
    event = {"event": "connected", "device": device, "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
    connection_events.append(event)
    if len(connection_events) > 50: connection_events.pop(0)
    return jsonify({"success": True})

@app.route('/events/disconnected', methods=['POST'])
def log_disconnect():
    event = {"event": "disconnected", "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
    connection_events.append(event)
    if len(connection_events) > 50: connection_events.pop(0)
    return jsonify({"success": True})

# --- PAIRING ENDPOINTS ---

@app.route('/pair_device', methods=['POST'])
def pair_device():
    """Audit Fix: Route changed from /pair to /pair_device to match middleware check."""
    data = request.json
    client_code = data.get("pairing_code")
    device_id = data.get("device_id")
    device_name = data.get("device_name", "Unknown Device")

    if str(client_code) == PAIRING_CODE:
        auth_token = secrets.token_hex(16)
        paired_devices[device_id] = {
            "device_name": device_name,
            "token": auth_token,
            "paired_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        valid_tokens.add(auth_token)
        save_paired_devices()
        log_event("DEVICE_PAIRED", {"device": device_name})
        return jsonify({"success": True, "token": auth_token}), 200
    return jsonify({"success": False, "error": "Invalid pairing code"}), 401

@app.route('/paired-devices', methods=['GET'])
def get_paired_devices():
    """Audit Fix: Returning full device info including token and device_name."""
    devices = [{"device_id": k, "device_name": v["device_name"], "token": v["token"]} for k, v in paired_devices.items()]
    return jsonify(devices), 200

@app.route('/unpair', methods=['POST'])
def unpair_device():
    device_id = request.json.get("device_id")
    if device_id in paired_devices:
        valid_tokens.discard(paired_devices[device_id]["token"])
        del paired_devices[device_id]
        save_paired_devices()
        return jsonify({"success": True, "action": "unpaired"})
    return jsonify({"success": False, "error": "Device not found"}), 404

# --- SYSTEM, POWER & PROCESSES ---

@app.route('/status', methods=['GET'])
def get_status():
    try:
        with open(SETTINGS_FILE, 'r') as f:
            settings = json.load(f)
            display_name = settings.get("device_name", socket.gethostname())
    except:
        display_name = socket.gethostname()

    return jsonify({
        "pc_name": display_name,
        "status": "online",
        "platform": platform.system().lower()
    })

@app.route('/system-stats', methods=['GET'])
def get_system_stats():
    vm, disk, battery = psutil.virtual_memory(), psutil.disk_usage('/'), psutil.sensors_battery()
    return jsonify({
        "cpu_percent": psutil.cpu_percent(interval=None),
        "ram_percent": vm.percent,
        "ram_total": round(vm.total / (1024**3), 2),
        "ram_used": round(vm.used / (1024**3), 2),
        "disk_percent": disk.percent,
        "disk_total": round(disk.total / (1024**3), 2),
        "disk_used": round(disk.used / (1024**3), 2),
        "battery_percent": battery.percent if battery else None,
        "battery_plugged": battery.power_plugged if battery else None
    })

# --- [UPDATE] RESOURCE TRENDS ---
@app.route('/system/resource-trends', methods=['GET'])
def get_resource_trends():
    """Returns the last 30 sampled resource data points for charting."""
    return jsonify(resource_usage_history)

@app.route('/uptime', methods=['GET'])
def get_uptime():
    boot_time_timestamp = psutil.boot_time()
    boot_time = datetime.fromtimestamp(boot_time_timestamp)
    uptime_seconds = int(time.time() - boot_time_timestamp)
    return jsonify({
        "uptime_seconds": uptime_seconds,
        "uptime_readable": str(timedelta(seconds=uptime_seconds)),
        "boot_time": boot_time.strftime("%Y-%m-%d %H:%M:%S")
    })

@app.route('/ping', methods=['GET'])
def ping():
    return jsonify({"message": "pong", "timestamp": datetime.now().strftime("%H:%M:%S")})

# --- COMMUNICATION CHANNEL TO UI ---
ui_queue = queue.Queue()

def log_to_ui(action, device="Phone"):
    ui_queue.put({"action": action, "device": device, "time": datetime.now().strftime("%H:%M")})

@app.route('/power/shutdown', methods=['POST'])
def shutdown():
    if not WINDOWS:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    # [CENTURY CHAOS FIX] Prevent shutdown during active transfers to avoid file corruption
    active = [t for t in active_transfers.values() if t.get("status") == "receiving"]
    if active:
        return jsonify({"success": False, "error": "Cannot shutdown while transfers are active"}), 409

    log_to_ui("Shutdown Requested")
    os.system("shutdown /s /t 5")
    return jsonify({"success": True, "action": "shutdown"})

@app.route('/power/restart', methods=['POST'])
def restart():
    if not WINDOWS:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    log_to_ui("Restart Requested")
    os.system("shutdown /r /t 5")
    return jsonify({"success": True, "action": "restart"})

@app.route('/power/sleep', methods=['POST'])
def sleep():
    if not WINDOWS:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    log_to_ui("Sleep Mode Activated")
    os.system("rundll32.exe powrprof.dll,SetSuspendState 0,1,0")
    return jsonify({"success": True, "action": "sleep"})

@app.route('/power/hibernate', methods=['POST'])
def hibernate():
    if not WINDOWS:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    log_to_ui("Hibernation Requested")
    os.system("shutdown /h")
    return jsonify({"success": True, "action": "hibernate"})

@app.route('/power/lock', methods=['POST'])
def lock():
    if not WINDOWS or not ctypes:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    log_to_ui("Locking Workstation")
    ctypes.windll.user32.LockWorkStation()
    return jsonify({"success": True, "action": "lock"})

@app.route('/processes', methods=['GET'])
def get_processes():
    procs = []
    for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info', 'status']):
        try:
            pinfo = proc.info
            procs.append({
                "pid": pinfo['pid'],
                "name": pinfo['name'],
                "cpu_percent": pinfo['cpu_percent'],
                "memory_mb": round(pinfo['memory_info'].rss / (1024 * 1024), 2),
                "status": pinfo['status']
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied): continue
    return jsonify(procs)

@app.route('/processes/kill', methods=['POST'])
def kill_process():
    pid = request.json.get("pid")
    try:
        psutil.Process(pid).terminate()
        return jsonify({"success": True, "pid": pid})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400

# --- APP LAUNCHER ---

@app.route('/apps', methods=['GET'])
def get_installed_apps():
    if not WINDOWS:
        return jsonify([]), 200
    apps = []
    search_paths = [
        Path(os.environ.get('ProgramData', '')) / "Microsoft/Windows/Start Menu/Programs",
        Path(os.environ.get('AppData', '')) / "Microsoft/Windows/Start Menu/Programs"
    ]
    for path in search_paths:
        if path.exists():
            for file in path.rglob("*.lnk"):
                apps.append({"name": file.stem, "path": str(file)})
    return jsonify(apps)

@app.route('/apps/launch', methods=['POST'])
def launch_application():
    if not WINDOWS:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    path = request.json.get("path")
    if path:
        os.startfile(path)
        return jsonify({"success": True, "app": Path(path).stem})
    return jsonify({"success": False, "error": "No path provided"}), 400

# --- NETWORK & WINDOW INFO ---

@app.route('/network', methods=['GET'])
def get_network_info():
    net = psutil.net_io_counters()
    return jsonify({
        "bytes_sent_mb": round(net.bytes_sent / (1024 * 1024), 2),
        "bytes_received_mb": round(net.bytes_recv / (1024 * 1024), 2),
        "pc_ip": get_local_ip(),
        "hostname": socket.gethostname()
    })

@app.route('/activewindow', methods=['GET'])
def get_active_window():
    if not WINDOWS or not gw:
        return jsonify({"window_title": "N/A", "process_name": "N/A"})
    try:
        win = gw.getActiveWindow()
        return jsonify({"window_title": win.title if win else "None", "process_name": "N/A"})
    except:
        return jsonify({"window_title": "Unknown"})

# --- [UPDATE] DISPLAY INFO ---
@app.route('/system/displays', methods=['GET'])
def get_display_info():
    """Detects primary and secondary monitor resolutions."""
    try:
        from screeninfo import get_monitors
        displays = []
        for m in get_monitors():
            displays.append({
                "name": m.name,
                "width": m.width,
                "height": m.height,
                "is_primary": m.is_primary
            })
        return jsonify(displays)
    except:
        return jsonify([{"name": "Default", "width": 1920, "height": 1080, "is_primary": True}])

# --- FILE SYSTEM ---

@app.route('/files', methods=['GET'])
def get_root_files():
    try:
        home = Path.home()
        folders = ["Desktop", "Documents", "Downloads", "Videos", "Music", "Pictures"]
        root_data = [{"name": f, "path": str(home / f), "type": "folder"} for f in folders if (home / f).exists()]
        return jsonify(root_data)
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/files/browse', methods=['GET'])
def browse_files():
    try:
        p = Path(request.args.get('path'))
        items = []
        for count, item in enumerate(p.iterdir()):
            if count >= 150: break
            try:
                stats = item.stat()
                items.append({
                    "name": item.name,
                    "path": str(item.absolute()),
                    "type": "file" if item.is_file() else "folder",
                    "size": stats.st_size if item.is_file() else 0,
                    "modified": datetime.fromtimestamp(stats.st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
                    "extension": item.suffix if item.is_file() else ""
                })
            except: continue
        return jsonify(items)
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/files/upload', methods=['POST'])
def upload_file_stream():
    if 'file' not in request.files:
        return jsonify({"success": False, "error": "No file part"}), 400

    files = request.files.getlist('file')
    dest = request.form.get('destination', str(Path.home() / "Downloads"))

    restricted_paths = ["C:\\Windows", "C:\\Program Files", "C:\\Users\\Default"]
    if any(dest.lower().startswith(r.lower()) for r in restricted_paths):
        return jsonify({"success": False, "error": "Access Denied"}), 403

    results = []
    for file in files:
        target_path = get_unique_path(os.path.join(dest, file.filename))
        transfer_id = str(uuid.uuid4())
        active_transfers[transfer_id] = {
            "name": file.filename,
            "progress": 0,
            "status": "receiving",
            "start_time": time.time(),
            "speed": "0 KB/s"
        }

        try:
            # We use a wrapper to save while tracking progress if possible,
            # but for multipart list, we save sequentially
            file.save(target_path)
            active_transfers[transfer_id]["progress"] = 100
            active_transfers[transfer_id]["status"] = "completed"
            log_to_ui(f"Received: {file.filename}")
            log_event("FILE_RECEIVED", {"name": file.filename})
            results.append({"name": file.filename, "status": "success"})
        except Exception as e:
            active_transfers[transfer_id]["status"] = "failed"
            results.append({"name": file.filename, "status": "error", "message": str(e)})

    return jsonify({"success": True, "files": results})

@app.route('/files/transfers', methods=['GET'])
def get_transfers():
    return jsonify(active_transfers)

@app.route('/files/download', methods=['GET'])
def download_file():
    path = request.args.get('path')
    if path and os.path.isfile(path):
        try:
            return send_file(path, as_attachment=True)
        except Exception as e:
            log_event("DOWNLOAD_ERROR", {"path": path, "error": str(e)})
            return jsonify({"error": "Failed to stream file", "details": str(e)}), 500
    return jsonify({"error": "File not found"}), 404

@app.route('/files/download/chunked', methods=['GET'])
def download_chunked():
    """Optimized for Warp Speed - Uses 64KB buffers to saturate WiFi bandwidth."""
    global cancel_all_transfers
    cancel_all_transfers = False # Reset on new download
    path = request.args.get('path')

    if not path or not os.path.isfile(path):
        return jsonify({"error": "File not found"}), 404

    # Chaos Tester: Handle file permission or lock issues
    try:
        f_test = open(path, "rb")
        f_test.close()
    except Exception as e:
        return jsonify({"error": "File is locked or inaccessible", "details": str(e)}), 403

    def generate():
        try:
            with open(path, "rb") as f:
                while not cancel_all_transfers:
                    chunk = f.read(1024 * 64)
                    if not chunk: break
                    yield chunk
        except Exception as e:
            log_event("STREAM_INTERRUPTED", {"path": path, "error": str(e)})
            # Stream will naturally terminate on error

    return Response(stream_with_context(generate()), mimetype="application/octet-stream")

@app.route('/files/download/cancel', methods=['POST'])
def cancel_downloads():
    global cancel_all_transfers
    cancel_all_transfers = True
    log_to_ui("Downloads Cancelled")
    return jsonify({"success": True, "action": "cancelled"})

@app.route('/files/preview', methods=['GET'])
def preview_file():
    """Streams file for in-app preview without forcing download."""
    path = request.args.get('path')
    if path and os.path.exists(path):
        return send_file(path, as_attachment=False)
    return jsonify({"error": "File not found"}), 404

import shutil

@app.route('/files/delete', methods=['DELETE'])
def delete_file():
    path = request.args.get('path')
    if not path or not os.path.exists(path):
        return jsonify({"success": False, "error": "Not found"}), 404

    # [CHAOS FIX] Handle files currently locked by other Windows processes
    try:
        if os.path.isfile(path):
            os.remove(path)
        else:
            shutil.rmtree(path)
        log_to_ui(f"Deleted: {os.path.basename(path)}")
        return jsonify({"success": True, "action": "deleted"})
    except PermissionError:
        return jsonify({"success": False, "error": "File is currently in use by another program"}), 403
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

# --- PERIPHERALS & MEDIA ---

@app.route('/screenshot', methods=['GET'])
def get_screenshot():
    if not WINDOWS or not pyautogui:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    try:
        log_to_ui("Screenshot Captured")
        screenshot = pyautogui.screenshot()
        buffered = io.BytesIO()
        # Compressed for faster transfer over local network
        screenshot.save(buffered, format="JPEG", quality=60)
        buffered.seek(0)
        return send_file(buffered, mimetype='image/jpeg')
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/clipboard', methods=['GET', 'POST'])
def handle_pc_clipboard():
    if request.method == 'GET':
        if not WINDOWS or not pyperclip:
            return jsonify({"success": True, "content": ""})
        return jsonify({"success": True, "content": pyperclip.paste()})

    if not WINDOWS or not pyperclip:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400

    # [CENTURY CHAOS FIX] Prevent memory exhaustion from massive clipboard payloads
    text = request.json.get("text", "")
    if len(text) > 1024 * 1024: # 1MB Limit
        return jsonify({"success": False, "error": "Clipboard content too large"}), 413

    log_to_ui("Clipboard Updated")
    pyperclip.copy(text)
    return jsonify({"success": True, "action": "clipboard_set"})

@app.route('/type', methods=['POST'])
def remote_type():
    if not WINDOWS or not pyautogui:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    text = request.json.get("text", "")
    log_to_ui(f"Typed: {text[:15]}...")
    pyautogui.write(text)
    return jsonify({"success": True, "text": text})

# --- [UPDATE] GLOBAL HOTKEYS ---
@app.route('/keyboard/hotkey', methods=['POST'])
def remote_hotkey():
    """Presses a combination of keys (e.g., ['ctrl', 'c'])."""
    if not WINDOWS or not pyautogui:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    keys = request.json.get("keys", [])
    if keys:
        log_to_ui(f"Hotkey: {'+'.join(keys)}")
        pyautogui.hotkey(*keys)
        return jsonify({"success": True, "keys": keys})
    return jsonify({"success": False, "error": "No keys provided"}), 400

@app.route('/mouse/move', methods=['POST'])
def mouse_move():
    if not WINDOWS or not pyautogui:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    data = request.json
    dx, dy = data.get('x', 0), data.get('y', 0)
    pyautogui.moveRel(dx, dy)
    return jsonify({"success": True})

@app.route('/mouse/click', methods=['POST'])
def mouse_click():
    if not WINDOWS or not pyautogui:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    btn = request.json.get('button', 'left')
    pyautogui.click(button=btn)
    return jsonify({"success": True})

@app.route('/media/volume/set', methods=['POST'])
def volume_set_exact():
    if not WINDOWS or not AudioUtilities:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    level = request.json.get("level", 50)
    log_to_ui(f"Volume Set: {level}%")
    try:
        devices = AudioUtilities.GetSpeakers()
        interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
        volume = ctypes.cast(interface, ctypes.POINTER(IAudioEndpointVolume))
        volume.SetMasterVolumeLevelScalar(level / 100.0, None)
        return jsonify({"success": True, "level": level})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/media/<action>', methods=['POST'])
def media_generic_control(action):
    if not WINDOWS or not pyautogui:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    # dynamic mapping for common keys
    map = {
        "playpause": "playpause",
        "next": "nexttrack",
        "prev": "prevtrack",
        "stop": "stop",
        "mute": "volumemute"
    }
    if action in map:
        log_to_ui(f"Media: {action}")
        pyautogui.press(map[action])
        return jsonify({"success": True})
    return jsonify({"success": False, "error": "Invalid media action"}), 400

@app.route('/media/volumeup', methods=['POST'])
def volume_up():
    if not WINDOWS or not AudioUtilities:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    set_volume(0.05)
    return jsonify({"success": True})

@app.route('/media/volumedown', methods=['POST'])
def volume_down():
    if not WINDOWS or not AudioUtilities:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    set_volume(-0.05)
    return jsonify({"success": True})

# --- BATTERY & HISTORY ---

@app.route('/battery/status', methods=['GET'])
def get_battery_status():
    batt = psutil.sensors_battery()
    percent = batt.percent if batt else 0
    return jsonify({
        "percent": percent,
        "plugged": batt.power_plugged if batt else False,
        "alert_threshold": battery_threshold,
        "is_critical": percent <= battery_threshold
    })

@app.route('/battery/threshold', methods=['POST'])
def set_battery_threshold():
    global battery_threshold
    battery_threshold = request.json.get("threshold", 20)
    return jsonify({"success": True})

@app.route('/history', methods=['GET'])
def get_history():
    return jsonify(command_history)

# --- NOTIFICATIONS & MACROS ---

@app.route('/notifications', methods=['GET'])
def get_notifications():
    return jsonify(notifications_list)

@app.route('/notifications/add', methods=['POST'])
def add_notification():
    data = request.json
    new_notif = {
        "id": str(uuid.uuid4()),
        "title": data.get("title", "No Title"),
        "message": data.get("message", ""),
        "app_name": data.get("app_name", "System"),
        "timestamp": datetime.now().strftime("%H:%M:%S")
    }
    notifications_list.append(new_notif)
    if len(notifications_list) > 20: notifications_list.pop(0)
    return jsonify({"success": True})

@app.route('/macros', methods=['GET'])
def get_macros():
    with open(MACROS_FILE, 'r') as f: return jsonify(json.load(f))

@app.route('/macros/create', methods=['POST'])
def create_macro():
    data = request.json
    with open(MACROS_FILE, 'r+') as f:
        macros = json.load(f)
        macros.append({"name": data.get("name"), "actions": data.get("actions", [])})
        f.seek(0)
        json.dump(macros, f, indent=4); f.truncate()
    return jsonify({"success": True})

@app.route('/macros/run', methods=['POST'])
def run_macro():
    if not WINDOWS:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    macro_name = request.json.get("name")
    with open(MACROS_FILE, 'r') as f: macros = json.load(f)
    macro = next((m for m in macros if m["name"] == macro_name), None)
    if not macro: return jsonify({"success": False, "error": "Macro not found"}), 404
    for action in macro["actions"]:
        a_type, val = action["type"], action.get("value")
        if a_type == "open_app" and WINDOWS: os.startfile(val)
        elif a_type == "lock" and WINDOWS and ctypes: ctypes.windll.user32.LockWorkStation()
        elif a_type == "volume_up": set_volume(0.05)
        elif a_type == "wait": time.sleep(float(val))
    return jsonify({"success": True, "action": f"Executed: {macro_name}"})

@app.route('/macros/delete', methods=['DELETE'])
def delete_macro():
    macro_name = request.json.get("name")
    with open(MACROS_FILE, 'r+') as f:
        macros = json.load(f)
        macros = [m for m in macros if m["name"] != macro_name]
        f.seek(0); json.dump(macros, f, indent=4); f.truncate()
    return jsonify({"success": True})

# --- STARTUP ---

if __name__ == '__main__':
    local_ip = get_local_ip()
    print("-" * 50)
    print("CYPHER PC SERVER")
    print(f"IP: {local_ip}")
    print(f"PAIRING KEY: {PAIRING_CODE}")
    print(f"INTERNAL BYPASS TOKEN: {INTERNAL_TOKEN}")
    print(f"Platform: {platform.system()}")
    print("-" * 50)
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
