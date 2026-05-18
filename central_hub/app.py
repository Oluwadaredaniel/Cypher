from flask import Flask, jsonify, request, render_template_string
import json
import os
from datetime import datetime

app = Flask(__name__)

# --- CONFIGURATION ---
MASTER_KEY = os.environ.get("MASTER_KEY", "emerald-admin")
DATA_FILE = "hub_data.json"

# --- HUB STATE ---
hub_state = {
    "installs": [],
    "unique_devices": {}, # [NEW] Track unique IPs and their last seen time
    "site_visits": 0,
    "broadcast": {
        "active": True,
        "title": "Welcome to CYPHER!",
        "message": "Join our official community group for updates.",
        "link": "https://tiktok.com/@emerald_dev1",
        "link_text": "Join Hub"
    },
    "metadata": {
        "app_name": "CYPHER",
        "app_version": "1.0.0",
        "app_publisher": "Emerald Dev",
        "app_publisher_url": "https://tiktok.com/@emerald_dev1",
        "app_id": "{D3A5F6E8-4B2C-4E1D-9A7F-E8D9C0B1A2D3}",
        "master_password": "emerald-admin"
    }
}

# --- PERSISTENCE HELPERS ---
def load_data():
    global hub_state
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r') as f:
                loaded = json.load(f)
                # Safely update hub_state with loaded values
                for key in loaded:
                    if key in hub_state:
                        hub_state[key] = loaded[key]
        except Exception as e:
            print(f"Error loading data: {e}")

def save_data():
    try:
        with open(DATA_FILE, 'w') as f:
            json.dump(hub_state, f, indent=4)
    except Exception as e:
        print(f"Error saving data: {e}")

# Load data at startup
load_data()

@app.route('/')
def home():
    hub_state['site_visits'] += 1
    save_data()
    return "CYPHER Central Hub is Active."

@app.route('/favicon.ico')
def favicon():
    return '', 204

@app.route('/api/track/visit', methods=['GET'])
def track_visit():
    hub_state['site_visits'] += 1
    save_data()
    return jsonify({"success": True}), 200

# --- CLIENT API ---

@app.route('/api/analytics/install', methods=['POST'])
def report_install():
    install_info = request.json
    install_info['ip'] = request.remote_addr
    install_info['at'] = datetime.now().strftime("%Y-%m-%d %H:%M")
    hub_state['installs'].append(install_info)
    save_data()
    return jsonify({"status": "ok"}), 200

@app.route('/api/broadcast', methods=['GET'])
def get_broadcast():
    # Track unique device activity and platform
    ip = request.remote_addr
    ua = request.headers.get('User-Agent', '').lower()
    platform = 'windows' if 'windows' in ua else 'android'

    hub_state['unique_devices'][ip] = {
        "at": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "platform": platform
    }
    save_data()
    return jsonify(hub_state['broadcast']), 200

@app.route('/api/metadata', methods=['GET'])
def get_metadata():
    # Track unique device activity and platform
    ip = request.remote_addr
    ua = request.headers.get('User-Agent', '').lower()
    platform = 'windows' if 'windows' in ua else 'android'

    hub_state['unique_devices'][ip] = {
        "at": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "platform": platform
    }
    save_data()
    return jsonify(hub_state['metadata']), 200

# --- MASTER ADMIN API ---

@app.route('/master/broadcast', methods=['POST'])
def update_broadcast():
    key = request.form.get("key") or request.json.get("key")
    if key != MASTER_KEY:
        return jsonify({"error": "Unauthorized"}), 401

    if request.form:
        hub_state['broadcast'] = {
            "active": 'active' in request.form,
            "title": request.form['title'],
            "message": request.form['message'],
            "link": request.form['link'],
            "link_text": request.form['link_text']
        }
        save_data()
        return "<script>alert('Broadcast Deployed!'); window.location='/master';</script>"
    else:
        hub_state['broadcast'] = request.json['broadcast']
        save_data()
        return jsonify({"success": True})

@app.route('/master/metadata', methods=['POST'])
def update_metadata():
    key = request.form.get("key") or request.json.get("key")
    if key != MASTER_KEY:
        return jsonify({"error": "Unauthorized"}), 401

    if request.form:
        hub_state['metadata'] = {
            "app_name": request.form['app_name'],
            "app_version": request.form['app_version'],
            "app_publisher": request.form['app_publisher'],
            "app_publisher_url": request.form['app_publisher_url'],
            "app_id": request.form['app_id'],
            "master_password": request.form['master_password']
        }
        save_data()
        return "<script>alert('Ecosystem Metadata Updated!'); window.location='/master';</script>"
    else:
        hub_state['metadata'] = request.json['metadata']
        save_data()
        return jsonify({"success": True})

# --- MASTER ADMIN INTERFACE ---

ADMIN_HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>CYPHER MASTER CONTROL</title>
    <style>
        body { font-family: 'Inter', sans-serif; background: #000; color: #fff; padding: 50px; }
        .container { max-width: 900px; margin: auto; }
        .card { background: #111; border: 1px solid #222; padding: 30px; border-radius: 24px; margin-bottom: 20px; }
        .accent { color: #6C63FF; }
        .stat { font-size: 64px; font-weight: 900; margin: 10px 0; }
        input, textarea { width: 100%; padding: 15px; margin: 10px 0; border-radius: 12px; border: 1px solid #333; background: #050505; color: white; box-sizing: border-box;}
        button { background: #6C63FF; color: white; border: none; padding: 15px 40px; border-radius: 100px; cursor: pointer; font-weight: bold; width: 100%; font-size: 16px;}
        .label { color: #555; font-size: 12px; font-weight: 800; letter-spacing: 1px; margin-bottom: 15px; display: block;}
        .tag { background: #6C63FF22; color: #6C63FF; padding: 4px 10px; border-radius: 6px; font-size: 12px; margin-right: 10px;}
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="accent">Emerald Master Hub</h1>

        <div class="grid">
            <div class="card">
                <div class="label">LIVE INSTALLATIONS</div>
                <div class="stat">{{ count }}</div>
                <div style="font-size: 14px; color: #444;">Tracking Android & Windows Ecosystem</div>
                <div style="margin-top: 15px; font-size: 12px; color: #6C63FF;">
                    Windows: {{ win_count }} | Android: {{ android_count }}
                </div>
                <div style="margin-top: 10px; font-size: 11px; color: #00FF88; font-weight: bold;">
                    Unique Active Devices (Estimated): {{ active_count }}
                </div>
            </div>

            <div class="card">
                <div class="label">TOTAL SITE VISITS</div>
                <div class="stat" style="color: #00FF88;">{{ visits }}</div>
                <div style="font-size: 14px; color: #444;">Landing Page Traffic</div>
            </div>
        </div>

        <div class="grid">
            <div class="card">
                <div class="label">GLOBAL BROADCAST COMMAND</div>
                <form method="POST" action="/master/broadcast">
                    <input type="hidden" name="key" value="emerald-admin">
                    <input type="text" name="title" placeholder="Banner Title" value="{{ b.title }}">
                    <textarea name="message" rows="3" placeholder="Banner Description">{{ b.message }}</textarea>
                    <input type="text" name="link" placeholder="Redirect URL" value="{{ b.link }}">
                    <input type="text" name="link_text" placeholder="Button Label" value="{{ b.link_text }}">
                    <div style="margin: 20px 0;">
                        <input type="checkbox" name="active" id="active" style="width: auto;" {% if b.active %}checked{% endif %}>
                        <label for="active">Enable visible banner</label>
                    </div>
                    <button type="submit">Deploy Broadcast</button>
                </form>
            </div>

            <div class="card">
                <div class="label">ECOSYSTEM METADATA</div>
                <form method="POST" action="/master/metadata">
                    <input type="hidden" name="key" value="emerald-admin">
                    <input type="text" name="app_name" placeholder="App Name" value="{{ m.app_name }}">
                    <input type="text" name="app_version" placeholder="Version" value="{{ m.app_version }}">
                    <input type="text" name="app_publisher" placeholder="Publisher" value="{{ m.app_publisher }}">
                    <input type="text" name="app_publisher_url" placeholder="Publisher URL" value="{{ m.app_publisher_url }}">
                    <input type="text" name="app_id" placeholder="Inno AppID" value="{{ m.app_id }}">
                    <input type="text" name="master_password" placeholder="Master Login Password" value="{{ m.master_password }}">
                    <button type="submit" style="background: #222; margin-top: 15px;">Update Identity & Security</button>
                </form>
            </div>
        </div>

        <div class="card">
            <div class="label">RECENT ACTIVITY</div>
            <div style="margin-top: 20px;">
                {% for i in logs[-10:] %}
                    <div style="padding: 10px 0; border-bottom: 1px solid #222; font-size: 13px;">
                        <span class="tag">{{ i.platform }}</span> {{ i.at }} from IP: {{ i.ip }}
                    </div>
                {% endfor %}
            </div>
        </div>
    </div>
</body>
</html>
"""

@app.route('/master')
def master_panel():
    # Statistics calculation
    # 1. Total reported installs (only happens once per device)
    win_installs = len([i for i in hub_state['installs'] if i.get('platform') == 'windows'])
    android_installs = len([i for i in hub_state['installs'] if i.get('platform') == 'android'])

    # 2. Unique devices active (happens every app launch)
    unique_devices = hub_state.get('unique_devices', {})
    win_active = len([d for d in unique_devices.values() if isinstance(d, dict) and d.get('platform') == 'windows'])
    android_active = len([d for d in unique_devices.values() if isinstance(d, dict) and d.get('platform') == 'android'])

    # Combined total for the card
    total_win = max(win_installs, win_active)
    total_android = max(android_installs, android_active)

    return render_template_string(
        ADMIN_HTML,
        count=total_win + total_android,
        win_count=total_win,
        android_count=total_android,
        active_count=len(unique_devices),
        visits=hub_state['site_visits'],
        b=hub_state['broadcast'],
        m=hub_state['metadata'],
        logs=hub_state['installs']
    )

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 8080))
    app.run(host='0.0.0.0', port=port)
