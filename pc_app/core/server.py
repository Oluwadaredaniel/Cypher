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
import re
import mimetypes
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
        from PIL import Image, ImageGrab
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
    ImageGrab = None
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

from .utils import get_config_path, log_event
from .guest_manager import guest_manager
from .recording_overlay import overlay_manager

# --- GLOBAL STORAGE & PERSISTENCE ---
notifications_list = []
command_history = []
connection_events = []
active_transfers = {}  # Format: {transfer_id: {"name": str, "size": int, "progress": int, "speed": str}}
cancel_all_transfers = False
phone_clipboard = {"content": "", "timestamp": "", "type": "text"}

# --- SCREEN RECORDING STATE ---
recording_state = {
    "is_recording": False,
    "is_paused": False,
    "start_time": None,
    "filename": None,
    "filepath": None,
    "process": None,
    "source": "fullscreen"
}

MACROS_FILE = get_config_path("macros.json")
SETTINGS_FILE = get_config_path("settings.json")
PAIRED_DEVICES_FILE = get_config_path("paired_devices.json")
PAIRING_CODE = str(random.randint(100000, 999999))
paired_devices = {}
valid_tokens = {INTERNAL_TOKEN}

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
    guest_token = request.args.get("token")
    
    if incoming_token == INTERNAL_TOKEN:
        return None
    
    # Allow guest endpoints with valid guest token
    if guest_token and (request.path.startswith('/guest/') or request.path == '/guest/access'):
        if not guest_manager.validate_token(guest_token):
            return jsonify({"success": False, "error": "Invalid or expired guest token"}), 401
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
        # [FIX] Initialize COM for this thread
        ctypes.windll.ole32.CoInitialize(None)
        devices = AudioUtilities.GetSpeakers()
        interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
        volume = ctypes.cast(interface, ctypes.POINTER(IAudioEndpointVolume))
        current_volume = volume.GetMasterVolumeLevelScalar()
        new_volume = max(0.0, min(1.0, current_volume + change))
        volume.SetMasterVolumeLevelScalar(new_volume, None)
        return True
    except Exception:
        return False
    finally:
        ctypes.windll.ole32.CoUninitialize()

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

def is_path_in_folders(file_path: str, allowed_folders: list) -> bool:
    """Verify path is within allowed folders (prevent directory traversal)."""
    try:
        file_path_obj = Path(file_path).resolve()
        for folder in allowed_folders:
            folder_obj = Path(folder).resolve()
            file_path_obj.relative_to(folder_obj)
            return True
    except (ValueError, OSError):
        return False
    return False

def get_human_readable_time(seconds: int) -> str:
    """Convert seconds to human readable format."""
    if seconds < 60:
        return f"{seconds}s"
    elif seconds < 3600:
        return f"{seconds // 60}m {seconds % 60}s"
    else:
        hours = seconds // 3600
        mins = (seconds % 3600) // 60
        return f"{hours}h {mins}m"

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
        try:
            with open(SETTINGS_FILE, 'r') as f:
                return jsonify(json.load(f))
        except:
            return jsonify(DEFAULT_SETTINGS)

    new_settings = request.json
    try:
        with open(SETTINGS_FILE, 'r+') as f:
            current = json.load(f)

            # Preserve critical device name logic
            old_name = current.get("device_name", socket.gethostname())

            current.update(new_settings)

            # Ensure name changes are synced to discovery
            new_name = current.get("device_name")
            if new_name and new_name != old_name:
                try:
                    from .discovery import get_discovery_instance
                    disco = get_discovery_instance()
                    if disco:
                        disco.update_name(new_name)
                except ImportError:
                    pass

            battery_threshold = current.get("battery_alert_threshold", battery_threshold)

            f.seek(0)
            json.dump(current, f, indent=4)
            f.truncate()
        return jsonify({"success": True, "action": "settings_updated"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

# --- PHONE CLIPBOARD BUFFER ---

@app.route('/clipboard/phone', methods=['GET', 'POST'])
def handle_phone_clipboard():
    global phone_clipboard
    if request.method == 'POST':
        content = request.json.get("text", "")
        # Check if content is a base64 image
        if content.startswith("data:image"):
             phone_clipboard = {
                "content": content,
                "type": "image",
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
        else:
            phone_clipboard = {
                "content": content,
                "type": "text",
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
        return jsonify({"success": True, "action": "phone_clipboard_saved"})

    return jsonify({"success": True, **phone_clipboard})

@app.route('/clipboard/paste-from-phone', methods=['POST'])
def paste_from_phone():
    if not WINDOWS or not pyperclip:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    if phone_clipboard["content"]:
        log_to_ui(f"Pasted {phone_clipboard.get('type', 'text')} from Phone")
        if phone_clipboard.get("type") == "image":
            # Image setting logic can be complex via native API, saving temp for now
            try:
                 header, encoded = phone_clipboard["content"].split(",", 1)
                 data = base64.b64decode(encoded)
                 img = Image.open(io.BytesIO(data))
                 # [CHAOS FIX] Save to a proper path or use native clipboard
                 img.save(get_app_data_dir() / "temp_clip.png")
            except: pass

        pyperclip.copy(phone_clipboard["content"])
        return jsonify({"success": True, "action": "pasted_to_pc"})
    return jsonify({"success": False, "error": "Phone buffer is empty"}), 400

@app.route('/clipboard/pc', methods=['GET'])
def get_pc_clipboard():
    """Returns the current PC clipboard (Text or Image)."""
    if not WINDOWS or not ImageGrab:
        return jsonify({"type": "text", "content": ""})
    try:
        # Check for image first
        img = ImageGrab.grabclipboard()
        if isinstance(img, Image.Image):
            buffered = io.BytesIO()
            img.save(buffered, format="PNG")
            img_str = base64.b64encode(buffered.getvalue()).decode()
            return jsonify({
                "type": "image",
                "content": f"data:image/png;base64,{img_str}",
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            })

        # Fallback to text
        text = pyperclip.paste()
        return jsonify({
            "type": "text",
            "content": text or "",
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

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
    try:
        ctypes.windll.user32.LockWorkStation()
        return jsonify({"success": True, "action": "lock"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

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
        proc = psutil.Process(pid)
        proc.terminate()
        gone, alive = psutil.wait_procs([proc], timeout=1)
        if alive:
            proc.kill()
        return jsonify({"success": True, "pid": pid})
    except psutil.AccessDenied:
        return jsonify({"success": False, "error": "Access Denied: Try running CYPHER as Admin"}), 403
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

@app.route('/apps/close', methods=['POST'])
def close_application():
    """Tries to find and close a window by ID or title."""
    if not WINDOWS or not gw:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400

    app_name = request.json.get("name")
    window_id = request.json.get("id")

    try:
        if window_id:
            for win in gw.getAllWindows():
                if win._hWnd == window_id:
                    win.close()
                    return jsonify({"success": True, "id": window_id})

        if app_name:
            found = False
            for win in gw.getWindowsWithTitle(app_name):
                win.close()
                found = True
            if found:
                return jsonify({"success": True, "app": app_name})
            else:
                for proc in psutil.process_iter(['name']):
                    if app_name.lower() in proc.info['name'].lower():
                        proc.terminate()
                        found = True
                if found:
                    return jsonify({"success": True, "app": app_name})

        return jsonify({"success": False, "error": "Application window not found"}), 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

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
        return jsonify({
            "window_title": win.title if win else "None",
            "process_name": "N/A",
            "id": win._hWnd if win else None
        })
    except:
        return jsonify({"window_title": "Unknown"})

@app.route('/system/active-windows', methods=['GET'])
def get_active_windows():
    """Returns a list of all visible application windows."""
    if not WINDOWS or not gw:
        return jsonify([])
    try:
        windows = []
        for win in gw.getAllWindows():
            if win.title and win.width > 0 and win.height > 0:
                # Basic detection
                tab_count = 1
                windows.append({
                    "title": win.title,
                    "id": win._hWnd,
                    "is_minimized": win.isMinimized,
                    "is_maximized": win.isMaximized,
                    "tab_hint": tab_count
                })
        return jsonify(windows)
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/system/window-icon', methods=['GET'])
def get_window_icon():
    """Extracts the native icon from a window handle and returns it as an image."""
    if not WINDOWS or not ctypes:
        return jsonify({"error": "Not supported"}), 400

    hwnd = request.args.get('id', type=int)
    if not hwnd:
        return jsonify({"error": "No ID"}), 400

    try:
        user32 = ctypes.windll.user32
        hicon = user32.SendMessageW(hwnd, 0x7F, 1, 0)
        if not hicon:
            hicon = user32.GetClassLongPtrW(hwnd, -14) # GCLP_HICON
        if not hicon:
             return jsonify({"error": "Icon not found"}), 404
        return jsonify({"error": "Icon streaming in progress"}), 501
    except:
        return jsonify({"error": "Failed"}), 500

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
    """Returns all logical drives, standard folders, and user-shared folders."""
    try:
        root_data = []

        # 1. Add User Shared Folders (from settings.json)
        try:
            with open(SETTINGS_FILE, 'r') as f:
                shared = json.load(f).get("shared_folders", [])
                for path in shared:
                    if os.path.exists(path):
                        root_data.append({
                            "name": os.path.basename(path) or path,
                            "path": path,
                            "type": "folder",
                            "is_shared": True
                        })
        except: pass

        # 2. Add Logical Drives (C:\, D:\, etc.)
        for part in psutil.disk_partitions():
            if 'cdrom' in part.opts or part.fstype == '': continue
            drive_name = part.mountpoint
            root_data.append({
                "name": f"Local Disk ({drive_name.strip('\\')})",
                "path": drive_name,
                "type": "drive"
            })

        # 2. Add Quick Access Folders (Home)
        home = Path.home()
        quick_folders = ["Desktop", "Documents", "Downloads", "Videos", "Music", "Pictures"]
        for f in quick_folders:
            p = home / f
            if p.exists():
                root_data.append({
                    "name": f,
                    "path": str(p),
                    "type": "folder"
                })

        return jsonify(root_data)
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/files/list', methods=['GET'])
def list_files_for_app():
    """Returns both directories and files for destination selection."""
    try:
        p_str = request.args.get('path', "")
        if not p_str or p_str == "":
            home = Path.home()
            folders = ["Desktop", "Documents", "Downloads", "Videos", "Music", "Pictures"]
            root_data = []
            for f in folders:
                if (home / f).exists():
                    root_data.append({
                        "name": f,
                        "path": str(home / f),
                        "is_dir": True,
                        "selectable": True
                    })
            return jsonify({"contents": root_data})

        p = Path(p_str)
        if not p.exists():
            return jsonify({"success": False, "error": "Path not found"}), 404

        items = []
        for item in p.iterdir():
            try:
                if item.name.startswith('.') or item.name.startswith('$'): continue
                is_dir = item.is_dir()
                items.append({
                    "name": item.name,
                    "path": str(item.absolute()),
                    "is_dir": is_dir,
                    "selectable": is_dir,
                    "extension": item.suffix.lower() if not is_dir else ""
                })
            except (PermissionError, OSError): continue

        items.sort(key=lambda x: not x['is_dir'])
        return jsonify({"contents": items})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/files/browse', methods=['GET'])
def browse_files():
    try:
        path_str = request.args.get('path')
        if not path_str:
            return jsonify({"success": False, "error": "No path provided"}), 400
        p = Path(path_str)
        if not p.exists():
             return jsonify({"success": False, "error": "Path does not exist"}), 404
        items = []
        for count, item in enumerate(p.iterdir()):
            if count >= 5000: break
            try:
                if item.name.startswith('$') or item.name.startswith('.'): continue
                stats = item.stat()
                items.append({
                    "name": item.name,
                    "path": str(item.absolute()),
                    "type": "file" if item.is_file() else "folder",
                    "size": stats.st_size if item.is_file() else 0,
                    "modified": datetime.fromtimestamp(stats.st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
                    "extension": item.suffix.lower() if item.is_file() else ""
                })
            except (PermissionError, OSError): continue
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
    global cancel_all_transfers
    cancel_all_transfers = False
    path = request.args.get('path')
    if not path or not os.path.isfile(path):
        return jsonify({"error": "File not found"}), 404
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
    return Response(stream_with_context(generate()), mimetype="application/octet-stream")

@app.route('/files/download/cancel', methods=['POST'])
def cancel_downloads():
    global cancel_all_transfers
    cancel_all_transfers = True
    log_to_ui("Downloads Cancelled")
    return jsonify({"success": True, "action": "cancelled"})

@app.route('/files/preview', methods=['GET'])
def preview_file():
    """Streams file for in-app preview with Range support and correct MIME types."""
    path = request.args.get('path')
    if not path or not os.path.exists(path):
        return jsonify({"error": "File not found"}), 404

    mime = mimetypes.guess_type(path)[0] or 'application/octet-stream'
    size = os.path.getsize(path)
    range_header = request.headers.get('Range', None)

    if not range_header:
        return send_file(path, mimetype=mime, as_attachment=False)

    try:
        byte1, byte2 = 0, None
        m = re.search(r'(\d+)-(\d*)', range_header)
        g = m.groups()
        if g[0]: byte1 = int(g[0])
        if g[1]: byte2 = int(g[1])
        length = size - byte1
        if byte2 is not None:
            length = byte2 - byte1 + 1

        def generate():
            with open(path, 'rb') as f:
                f.seek(byte1)
                remaining = length
                while remaining > 0:
                    chunk_size = min(remaining, 1024 * 128)
                    chunk = f.read(chunk_size)
                    if not chunk: break
                    yield chunk
                    remaining -= len(chunk)

        rv = Response(generate(), 206, mimetype=mime, direct_passthrough=True)
        rv.headers.add('Content-Range', 'bytes {0}-{1}/{2}'.format(byte1, byte1 + length - 1, size))
        rv.headers.add('Accept-Ranges', 'bytes')
        return rv
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/files/thumbnail', methods=['GET'])
def get_file_thumbnail():
    """Generates a small preview for images."""
    path = request.args.get('path')
    if not path or not os.path.exists(path) or not Image:
        return jsonify({"error": "Not found"}), 404
    try:
        ext = os.path.splitext(path)[1].lower()
        if ext not in ['.jpg', '.jpeg', '.png', '.gif', '.bmp']:
            return jsonify({"error": "Unsupported"}), 400
        with Image.open(path) as img:
            img.thumbnail((128, 128))
            buffered = io.BytesIO()
            img.save(buffered, format="JPEG", quality=70)
            buffered.seek(0)
            return send_file(buffered, mimetype='image/jpeg')
    except Exception as e:
        return jsonify({"error": str(e)}), 500

import shutil

@app.route('/files/delete', methods=['DELETE'])
def delete_file():
    path = request.args.get('path')
    if not path or not os.path.exists(path):
        return jsonify({"success": False, "error": "Not found"}), 404

    path_low = path.lower()
    restricted_roots = [
        "c:\\windows", "c:\\program files", "c:\\program files (x86)",
        "c:\\users\\default", "c:\\boot", "c:\\recovery"
    ]

    if any(path_low.startswith(r) for r in restricted_roots):
        return jsonify({"success": False, "error": "Access Denied: System Protected Folder"}), 403

    try:
        if os.path.isfile(path):
            os.remove(path)
        else:
            shutil.rmtree(path)
        log_to_ui(f"Deleted: {os.path.basename(path)}")
        return jsonify({"success": True, "action": "deleted"})
    except PermissionError:
        return jsonify({"success": False, "error": "File is currently in use"}), 403
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

# --- GUEST ACCESS ENDPOINTS (TIER 1, 2, 3) ---

@app.route('/guest/create', methods=['POST'])
def guest_create_session():
    """TIER 1: Create a guest session from authenticated device."""
    token = request.headers.get("X-Auth-Token")
    if not token or token not in valid_tokens:
        return jsonify({"success": False, "error": "Unauthorized"}), 401
    
    data = request.json
    folders = data.get("folders", [])
    duration = data.get("duration_minutes", 15)
    
    guest_token = guest_manager.create_session(folders, duration, token)
    guest_url = f"http://{get_local_ip()}:5000/guest/access?token={guest_token}"
    
    return jsonify({
        "success": True,
        "token": guest_token,
        "url": guest_url,
        "expires_at": (datetime.now() + timedelta(minutes=duration)).strftime("%Y-%m-%d %H:%M:%S")
    }), 200

@app.route('/guest/access', methods=['GET'])
def guest_landing():
    """TIER 2: Guest landing page - HTML file browser."""
    token = request.args.get('token')
    session = guest_manager.validate_token(token)
    
    if not session:
        return jsonify({"error": "Invalid or expired token"}), 401
    
    html_content = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover, user-scalable=no">
        <title>Cypher - Guest File Access</title>
        <style>
            :root {{
                --accent: #6C63FF;
                --bg: #0d0d0d;
                --surface: #1a1a1a;
                --text: #ffffff;
                --text-dim: #86868b;
                --glass: rgba(255, 255, 255, 0.05);
            }}

            * {{
                margin: 0;
                padding: 0;
                box-sizing: border-box;
                -webkit-tap-highlight-color: transparent;
            }}

            body {{
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif;
                background: var(--bg);
                color: var(--text);
                line-height: 1.5;
                padding-top: max(12px, env(safe-area-inset-top));
                padding-bottom: max(12px, env(safe-area-inset-bottom));
            }}

            .container {{
                max-width: 800px;
                margin: 0 auto;
                padding: 20px;
            }}

            .header {{
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 24px;
                padding: 16px;
                background: var(--glass);
                backdrop-filter: blur(20px);
                border-radius: 20px;
                border: 1px solid rgba(255, 255, 255, 0.1);
            }}

            .header h1 {{
                font-size: 20px;
                font-weight: 700;
                letter-spacing: -0.5px;
            }}

            .timer {{
                font-size: 14px;
                font-weight: 600;
                font-variant-numeric: tabular-nums;
                color: var(--text-dim);
                padding: 6px 12px;
                background: rgba(255, 255, 255, 0.05);
                border-radius: 100px;
            }}

            .timer.warning {{ color: #ff9500; background: rgba(255, 149, 0, 0.1); }}
            .timer.critical {{ color: #ff3b30; background: rgba(255, 59, 48, 0.1); }}

            .breadcrumb {{
                display: flex;
                gap: 8px;
                margin-bottom: 20px;
                overflow-x: auto;
                padding-bottom: 4px;
                scrollbar-width: none;
            }}

            .breadcrumb::-webkit-scrollbar {{ display: none; }}

            .breadcrumb span {{
                padding: 8px 16px;
                background: var(--surface);
                border-radius: 12px;
                color: var(--accent);
                font-size: 13px;
                font-weight: 600;
                cursor: pointer;
                white-space: nowrap;
                transition: all 0.2s;
                border: 1px solid rgba(255, 255, 255, 0.05);
            }}

            .breadcrumb span:last-child {{
                color: var(--text-dim);
                cursor: default;
                background: transparent;
            }}

            .upload-card {{
                background: var(--surface);
                border: 2px dashed rgba(108, 99, 255, 0.3);
                border-radius: 20px;
                padding: 30px;
                text-align: center;
                margin-bottom: 24px;
                transition: all 0.3s;
                cursor: pointer;
            }}

            .upload-card:hover, .upload-card.dragover {{
                border-color: var(--accent);
                background: rgba(108, 99, 255, 0.05);
            }}

            .upload-card i {{
                font-size: 32px;
                display: block;
                margin-bottom: 12px;
            }}

            .file-list {{
                display: grid;
                gap: 12px;
            }}

            .file-item {{
                display: flex;
                align-items: center;
                gap: 16px;
                padding: 16px;
                background: var(--surface);
                border-radius: 18px;
                transition: transform 0.2s, background 0.2s;
                border: 1px solid rgba(255, 255, 255, 0.03);
            }}

            .file-item:active {{
                transform: scale(0.98);
                background: #252525;
            }}

            .file-icon {{
                width: 48px;
                height: 48px;
                background: rgba(255, 255, 255, 0.05);
                border-radius: 12px;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 24px;
            }}

            .file-info {{
                flex: 1;
                min-width: 0;
            }}

            .file-name {{
                font-weight: 600;
                font-size: 15px;
                margin-bottom: 2px;
                overflow: hidden;
                text-overflow: ellipsis;
                white-space: nowrap;
            }}

            .file-meta {{
                font-size: 12px;
                color: var(--text-dim);
            }}

            .download-btn {{
                width: 40px;
                height: 40px;
                border-radius: 12px;
                background: var(--accent);
                border: none;
                color: white;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 18px;
                cursor: pointer;
            }}

            #alertBox {{
                position: fixed;
                top: 24px;
                left: 50%;
                transform: translateX(-50%);
                z-index: 1000;
                width: calc(100% - 40px);
                max-width: 400px;
            }}

            .alert {{
                padding: 16px 20px;
                border-radius: 16px;
                font-weight: 600;
                font-size: 14px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.5);
                animation: slideDown 0.3s cubic-bezier(0.16, 1, 0.3, 1);
                margin-bottom: 12px;
            }}

            .alert.success {{ background: #30d158; color: #000; }}
            .alert.error {{ background: #ff3b30; color: #fff; }}

            @keyframes slideDown {{
                from {{ transform: translateY(-20px); opacity: 0; }}
                to {{ transform: translateY(0); opacity: 1; }}
            }}

            #uploadInput {{ display: none; }}

            .empty-state {{
                text-align: center;
                padding: 60px 20px;
                color: var(--text-dim);
            }}

            .empty-state i {{ font-size: 48px; display: block; margin-bottom: 16px; }}
        </style>
    </head>
    <body>
        <div id="alertBox"></div>
        <div class="container">
            <div class="header">
                <h1>Cypher Guest</h1>
                <div class="timer" id="timerDisplay">--:--</div>
            </div>

            <div class="breadcrumb" id="breadcrumb">
                <span onclick="navigateTo('')">Home</span>
            </div>

            <div id="uploadArea" class="upload-card">
                <i>📁</i>
                <p style="font-weight: 600;">Tap to upload files</p>
                <p style="font-size: 12px; color: var(--text-dim); margin-top: 4px;">to current folder</p>
                <input type="file" id="uploadInput" multiple>
            </div>

            <div class="file-list" id="fileList"></div>
        </div>

        <script>
            const TOKEN = "{token}";
            const BASE_URL = window.location.origin;
            let currentPath = "";

            document.addEventListener('DOMContentLoaded', () => {{
                loadFiles();
                startTimer();
                setupUpload();
            }});

            async function startTimer() {{
                setInterval(updateTimer, 1000);
                updateTimer();
            }}

            async function updateTimer() {{
                try {{
                    const res = await fetch(`${{BASE_URL}}/guest/session?token=${{TOKEN}}`);
                    const data = await res.json();
                    if (!data.success) window.location.reload();

                    const seconds = data.time_remaining_seconds;
                    const mins = Math.floor(seconds / 60);
                    const secs = seconds % 60;
                    const timeStr = `${{mins.toString().padStart(2, '0')}}:${{secs.toString().padStart(2, '0')}}`;

                    const timer = document.getElementById('timerDisplay');
                    timer.textContent = timeStr;
                    timer.className = 'timer' + (seconds < 60 ? ' critical' : (seconds < 300 ? ' warning' : ''));
                }} catch (e) {{}}
            }}

            async function loadFiles() {{
                try {{
                    const res = await fetch(`${{BASE_URL}}/guest/files?token=${{TOKEN}}&path=${{encodeURIComponent(currentPath)}}`);
                    const data = await res.json();
                    if (!data.success) return showAlert(data.error, 'error');
                    renderFiles(data.files);
                }} catch (e) {{ showAlert(e.message, 'error'); }}
            }}

            function renderFiles(files) {{
                const list = document.getElementById('fileList');
                if (!files || files.length === 0) {{
                    list.innerHTML = '<div class="empty-state"><i>📂</i><p>This folder is empty</p></div>';
                    return;
                }}

                list.innerHTML = files.map(file => {{
                    const isDir = file.type === 'folder';
                    return `
                        <div class="file-item" onclick="handleFileClick('${{file.path.replace(/\\\\/g, '/')}}', ${{isDir}})">
                            <div class="file-icon">${{isDir ? '📁' : getIcon(file.extension)}}</div>
                            <div class="file-info">
                                <div class="file-name">${{file.name}}</div>
                                <div class="file-meta">${{isDir ? (file.item_count + ' items') : formatSize(file.size)}} • ${{file.modified}}</div>
                            </div>
                            ${{isDir ? '' : `<button class="download-btn" onclick="downloadFile(event, '${{file.path.replace(/\\\\/g, '/')}}')">↓</button>`}}
                        </div>
                    `;
                }}).join('');
            }}

            function handleFileClick(path, isDir) {{
                if (isDir) {{
                    currentPath = path;
                    loadFiles();
                    updateBreadcrumb();
                }}
            }}

            async function downloadFile(e, path) {{
                e.stopPropagation();
                const btn = e.target;
                btn.innerHTML = '...';
                try {{
                    const res = await fetch(`${{BASE_URL}}/guest/files/download?token=${{TOKEN}}&path=${{encodeURIComponent(path)}}`);
                    const blob = await res.blob();
                    const url = window.URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = path.split('/').pop();
                    a.click();
                    showAlert('Downloaded', 'success');
                }} catch (e) {{ showAlert('Failed', 'error'); }}
                btn.innerHTML = '↓';
            }}

            function updateBreadcrumb() {{
                const bc = document.getElementById('breadcrumb');
                const parts = currentPath.split('/').filter(p => p);
                let html = '<span onclick="navigateTo(\\'\\')">Home</span>';
                let runningPath = '';
                for (const p of parts) {{
                    runningPath += (runningPath ? '/' : '') + p;
                    html += `<span onclick="navigateTo(\\'${{runningPath.replace(/\\\\/g, '/')}}\\' )">${{p}}</span>`;
                }}
                bc.innerHTML = html;
            }}

            function navigateTo(path) {{
                currentPath = path;
                loadFiles();
                updateBreadcrumb();
            }}

            function setupUpload() {{
                const area = document.getElementById('uploadArea');
                const input = document.getElementById('uploadInput');
                area.onclick = () => input.click();
                input.onchange = (e) => handleUpload(e.target.files);
                area.ondragover = (e) => {{ e.preventDefault(); area.classList.add('dragover'); }};
                area.ondragleave = () => area.classList.remove('dragover');
                area.ondrop = (e) => {{ e.preventDefault(); area.classList.remove('dragover'); handleUpload(e.dataTransfer.files); }};
            }}

            async function handleUpload(files) {{
                if (!files.length) return;
                const fd = new FormData();
                for (const f of files) fd.append('file', f);
                fd.append('destination', currentPath);
                try {{
                    const res = await fetch(`${{BASE_URL}}/guest/files/upload?token=${{TOKEN}}`, {{ method: 'POST', body: fd }});
                    const data = await res.json();
                    if (data.success) {{
                        showAlert('Uploaded successfully', 'success');
                        loadFiles();
                    }} else showAlert(data.error, 'error');
                }} catch (e) {{ showAlert(e.message, 'error'); }}
            }}

            function showAlert(msg, type) {{
                const box = document.getElementById('alertBox');
                const div = document.createElement('div');
                div.className = 'alert ' + type;
                div.textContent = msg;
                box.appendChild(div);
                setTimeout(() => div.remove(), 3000);
            }}

            function getIcon(ext) {{
                const m = {{'.pdf':'📄','.jpg':'🖼️','.png':'🖼️','.mp4':'🎬','.zip':'📦','.mp3':'🎵','.txt':'📝'}};
                return m[ext.toLowerCase()] || '📄';
            }}

            function formatSize(b) {{
                if (!b) return '0 B';
                const i = Math.floor(Math.log(b)/Math.log(1024));
                return (b/Math.pow(1024,i)).toFixed(1) + ' ' + ['B','KB','MB','GB'][i];
            }}
        </script>
    </body>
    </html>
    """
    return html_content, 200, {'Content-Type': 'text/html; charset=utf-8'}

@app.route('/guest/files', methods=['GET'])
def guest_get_files():
    """TIER 1: List files in allowed folders for guest."""
    token = request.args.get('token')
    path = request.args.get('path', '')

    session = guest_manager.validate_token(token)
    if not session:
        return jsonify({"success": False, "error": "Invalid or expired token"}), 401

    try:
        if not path:
            # Return allowed folders
            files = []
            for folder in session.allowed_folders:
                if Path(folder).exists():
                    files.append({
                        "name": Path(folder).name,
                        "path": str(Path(folder)),
                        "type": "folder",
                        "size": 0,
                        "item_count": len(list(Path(folder).iterdir())),
                        "modified": datetime.fromtimestamp(Path(folder).stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
                        "extension": ""
                    })
            return jsonify({"success": True, "files": files})

        # Validate path is in allowed folders
        if not is_path_in_folders(path, session.allowed_folders):
            return jsonify({"success": False, "error": "Access denied"}), 403

        p = Path(path)
        if not p.exists():
            return jsonify({"success": False, "error": "Path not found"}), 404

        items = []
        for item in sorted(p.iterdir()):
            try:
                stats = item.stat()
                item_count = len(list(item.iterdir())) if item.is_dir() else 0
                items.append({
                    "name": item.name,
                    "path": str(item.absolute()),
                    "type": "folder" if item.is_dir() else "file",
                    "size": stats.st_size if item.is_file() else 0,
                    "item_count": item_count,
                    "modified": datetime.fromtimestamp(stats.st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
                    "extension": item.suffix if item.is_file() else ""
                })
                guest_manager.log_guest_access(token, str(item), "browse")
            except:
                continue

        return jsonify({"success": True, "files": items})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/guest/files/search', methods=['GET'])
def guest_search_files():
    """TIER 2: Search files in allowed folders."""
    token = request.args.get('token')
    query = request.args.get('q', '').lower()

    session = guest_manager.validate_token(token)
    if not session or not query:
        return jsonify({"success": False, "error": "Invalid request"}), 400

    try:
        results = []
        for folder in session.allowed_folders:
            folder_path = Path(folder)
            if not folder_path.exists():
                continue

            for item in folder_path.rglob('*'):
                if query in item.name.lower() and len(results) < 50:
                    try:
                        stats = item.stat()
                        results.append({
                            "name": item.name,
                            "path": str(item.absolute()),
                            "type": "folder" if item.is_dir() else "file",
                            "size": stats.st_size if item.is_file() else 0,
                            "modified": datetime.fromtimestamp(stats.st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
                            "extension": item.suffix if item.is_file() else ""
                        })
                        guest_manager.log_guest_access(token, str(item), "search")
                    except:
                        continue

        return jsonify({"success": True, "results": results})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/guest/files/download', methods=['GET'])
def guest_download_file():
    """TIER 1: Download a file as guest."""
    token = request.args.get('token')
    path = request.args.get('path')

    session = guest_manager.validate_token(token)
    if not session:
        return jsonify({"success": False, "error": "Invalid or expired token"}), 401

    if not path or not is_path_in_folders(path, session.allowed_folders):
        return jsonify({"success": False, "error": "Access denied"}), 403

    if not os.path.isfile(path):
        return jsonify({"success": False, "error": "File not found"}), 404

    try:
        guest_manager.log_guest_access(token, path, "download")
        return send_file(path, as_attachment=True)
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/guest/files/download/zip', methods=['POST'])
def guest_download_zip():
    """TIER 1: Download multiple files as ZIP."""
    token = request.args.get('token')
    data = request.json or {}
    paths = data.get('paths', [])

    session = guest_manager.validate_token(token)
    if not session:
        return jsonify({"success": False, "error": "Invalid or expired token"}), 401

    if not paths:
        return jsonify({"success": False, "error": "No files selected"}), 400

    # Validate all paths
    for path in paths:
        if not is_path_in_folders(path, session.allowed_folders):
            return jsonify({"success": False, "error": "Access denied"}), 403

    try:
        zip_buffer = io.BytesIO()
        with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zf:
            for path in paths:
                if os.path.isfile(path):
                    zf.write(path, arcname=os.path.basename(path))
                    guest_manager.log_guest_access(token, path, "zip-download")

        zip_buffer.seek(0)
        return send_file(zip_buffer, mimetype='application/zip', as_attachment=True, download_name='files.zip')
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/guest/files/upload', methods=['POST'])
def guest_upload_files():
    """TIER 1: Upload files as guest."""
    token = request.args.get('token')
    session = guest_manager.validate_token(token)

    if not session:
        return jsonify({"success": False, "error": "Invalid or expired token"}), 401

    if 'file' not in request.files:
        return jsonify({"success": False, "error": "No file part"}), 400

    files = request.files.getlist('file')
    dest = request.form.get('destination', session.allowed_folders[0] if session.allowed_folders else str(Path.home() / "Downloads"))

    if not is_path_in_folders(dest, session.allowed_folders):
        return jsonify({"success": False, "error": "Access denied"}), 403

    results = []
    for file in files:
        try:
            target_path = get_unique_path(os.path.join(dest, file.filename))
            file.save(target_path)
            guest_manager.log_guest_access(token, target_path, "upload")
            results.append({"name": file.filename, "status": "success"})
        except Exception as e:
            results.append({"name": file.filename, "status": "error", "message": str(e)})

    return jsonify({"success": True, "files": results}), 200

@app.route('/guest/files/preview', methods=['GET'])
def guest_preview_file():
    """TIER 2: Preview file without downloading."""
    token = request.args.get('token')
    path = request.args.get('path')

    session = guest_manager.validate_token(token)
    if not session:
        return jsonify({"success": False, "error": "Invalid or expired token"}), 401

    if not path or not is_path_in_folders(path, session.allowed_folders):
        return jsonify({"success": False, "error": "Access denied"}), 403

    if not os.path.exists(path):
        return jsonify({"success": False, "error": "File not found"}), 404

    try:
        guest_manager.log_guest_access(token, path, "preview")
        return send_file(path, as_attachment=False)
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/guest/session', methods=['GET'])
def guest_get_session():
    """TIER 2: Get session info including timer."""
    token = request.args.get('token')
    session = guest_manager.validate_token(token)

    if not session:
        return jsonify({"success": False, "error": "Invalid or expired token"}), 401

    return jsonify({
        "success": True,
        "token": token,
        "created_at": session.created_at.strftime("%Y-%m-%d %H:%M:%S"),
        "expires_at": session.expires_at.strftime("%Y-%m-%d %H:%M:%S"),
        "time_remaining_seconds": max(0, int((session.expires_at - datetime.now()).total_seconds())),
        "access_count": session.access_count,
        "allowed_folders": session.allowed_folders,
        "is_active": session.is_active
    }), 200

@app.route('/guest/extend', methods=['POST'])
def guest_extend_session():
    """TIER 3: Extend guest session from host."""
    token = request.headers.get("X-Auth-Token")
    if not token or token not in valid_tokens:
        return jsonify({"success": False, "error": "Unauthorized"}), 401

    data = request.json
    guest_token = data.get("guest_token")
    additional_minutes = data.get("additional_minutes", 30)

    if guest_manager.extend_session(guest_token, additional_minutes):
        return jsonify({"success": True, "action": "extended"}), 200

    return jsonify({"success": False, "error": "Session not found"}), 404

@app.route('/guest/end', methods=['POST'])
def guest_end_session():
    """TIER 3: End guest session immediately."""
    token = request.headers.get("X-Auth-Token")
    if not token or token not in valid_tokens:
        return jsonify({"success": False, "error": "Unauthorized"}), 401

    data = request.json
    guest_token = data.get("guest_token")

    if guest_manager.end_session(guest_token):
        return jsonify({"success": True, "action": "ended"}), 200

    return jsonify({"success": False, "error": "Session not found"}), 404

@app.route('/guest/sessions', methods=['GET'])
def guest_list_sessions():
    """TIER 3: List all active guest sessions for authenticated device."""
    token = request.headers.get("X-Auth-Token")
    if not token or token not in valid_tokens:
        return jsonify({"success": False, "error": "Unauthorized"}), 401

    sessions = guest_manager.get_all_active_sessions(host_device_id=token)
    return jsonify({"success": True, "sessions": sessions}), 200

# --- SCREEN RECORDING ---

@app.route('/recording/start', methods=['POST'])
def start_recording():
    global recording_state
    if recording_state["is_recording"]:
        return jsonify({"success": False, "error": "Recording already in progress"}), 400
    data = request.json
    source = data.get("source", "fullscreen")
    record_dir = Path.home() / "Videos" / "CYPHER"
    record_dir.mkdir(parents=True, exist_ok=True)
    filename = f"Recording_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp4"
    filepath = record_dir / filename
    recording_state.update({
        "is_recording": True, "is_paused": False, "start_time": time.time(),
        "filename": filename, "filepath": str(filepath), "source": source
    })
    log_to_ui(f"Recording Started: {source}")
    overlay_manager.start()
    return jsonify({"success": True, "filename": filename})

@app.route('/recording/status', methods=['GET'])
def get_recording_status():
    return jsonify({
        "is_recording": recording_state["is_recording"],
        "is_paused": recording_state["is_paused"],
        "duration": int(time.time() - recording_state["start_time"]) if recording_state["is_recording"] else 0,
        "filename": recording_state["filename"]
    })

@app.route('/recording/pause', methods=['POST'])
def pause_recording():
    global recording_state
    if not recording_state["is_recording"]:
        return jsonify({"success": False, "error": "No recording in progress"}), 400
    recording_state["is_paused"] = not recording_state["is_paused"]
    action = "Paused" if recording_state["is_paused"] else "Resumed"
    log_to_ui(f"Recording {action}")
    return jsonify({"success": True, "is_paused": recording_state["is_paused"]})

@app.route('/recording/stop', methods=['POST'])
def stop_recording():
    global recording_state
    if not recording_state["is_recording"]:
        return jsonify({"success": False, "error": "No recording in progress"}), 400
    filepath = recording_state["filepath"]
    recording_state.update({"is_recording": False, "is_paused": False, "start_time": None})
    log_to_ui("Recording Stopped & Saved")
    overlay_manager.stop()
    return jsonify({"success": True, "path": filepath})

# --- PERIPHERALS & MEDIA ---

@app.route('/screenshot', methods=['GET'])
def get_screenshot():
    if not WINDOWS or not pyautogui:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    try:
        log_to_ui("Screenshot Captured")
        screenshot = pyautogui.screenshot()
        buffered = io.BytesIO()
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
    text = request.json.get("text", "")
    if len(text) > 1024 * 1024:
        return jsonify({"success": False, "error": "Clipboard content too large"}), 413
    log_to_ui("Clipboard Updated")
    pyperclip.copy(text)
    return jsonify({"success": True, "action": "clipboard_set"})

@app.route('/open-link', methods=['POST'])
def open_remote_link():
    """Support for 'Open Link' feature from mobile clipboard."""
    url = request.json.get("url", "")
    if not url:
        return jsonify({"success": False, "error": "No URL provided"}), 400
    try:
        import webbrowser
        webbrowser.open(url)
        log_to_ui(f"Opened: {url[:30]}...")
        return jsonify({"success": True, "action": "link_opened"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/type', methods=['POST'])
def remote_type():
    if not WINDOWS or not pyautogui:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    text = request.json.get("text", "")
    log_to_ui(f"Typed: {text[:15]}...")
    pyautogui.write(text)
    return jsonify({"success": True, "text": text})

@app.route('/keyboard/hotkey', methods=['POST'])
def remote_hotkey():
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
        ctypes.windll.ole32.CoInitialize(None)
        devices = AudioUtilities.GetSpeakers()
        interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
        volume = ctypes.cast(interface, ctypes.POINTER(IAudioEndpointVolume))
        volume.SetMasterVolumeLevelScalar(level / 100.0, None)
        return jsonify({"success": True, "level": level})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        ctypes.windll.ole32.CoUninitialize()

@app.route('/media/<action>', methods=['POST'])
def media_generic_control(action):
    if not WINDOWS or not pyautogui:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    map = {"playpause": "playpause", "next": "nexttrack", "prev": "prevtrack", "stop": "stop", "mute": "volumemute"}
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

@app.route('/battery/status', methods=['GET'])
def get_battery_status():
    batt = psutil.sensors_battery()
    percent = batt.percent if batt else 0
    return jsonify({
        "percent": percent, "plugged": batt.power_plugged if batt else False,
        "alert_threshold": battery_threshold, "is_critical": percent <= battery_threshold
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
    try:
        with open(MACROS_FILE, 'r') as f: return jsonify(json.load(f))
    except:
        return jsonify([])

@app.route('/macros/create', methods=['POST'])
def create_macro():
    data = request.json
    try:
        with open(MACROS_FILE, 'r+') as f:
            macros = json.load(f)
            macros.append({"name": data.get("name"), "actions": data.get("actions", [])})
            f.seek(0)
            json.dump(macros, f, indent=4); f.truncate()
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/macros/run', methods=['POST'])
def run_macro():
    if not WINDOWS:
        return jsonify({"success": False, "error": "Not available on this platform"}), 400
    macro_name = request.json.get("name")
    try:
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
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/macros/delete', methods=['DELETE'])
def delete_macro():
    macro_name = request.json.get("name")
    try:
        with open(MACROS_FILE, 'r+') as f:
            macros = json.load(f)
            macros = [m for m in macros if m["name"] != macro_name]
            f.seek(0); json.dump(macros, f, indent=4); f.truncate()
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    local_ip = get_local_ip()
    print("-" * 50)
    print("CYPHER PC SERVER")
    print(f"IP: {local_ip}")
    print(f"PAIRING KEY: {PAIRING_CODE}")
    print(f"INTERNAL BYPASS TOKEN: {INTERNAL_TOKEN}")
    print("-" * 50)
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
