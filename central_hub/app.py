from flask import Flask, jsonify, request, render_template_string
import json
import os
from datetime import datetime, timedelta
from pymongo import MongoClient

app = Flask(__name__)

# --- CONFIGURATION ---
MASTER_KEY = os.environ.get("MASTER_KEY", "emerald-admin")
MONGO_URI = os.environ.get("MONGO_URI")
DATA_FILE = "hub_data.json"

# --- HUB STATE (DEFAULT) ---
hub_state = {
    "installs": [],
    "unique_devices": {},
    "feature_usage": {
        "screen_record": 0,
        "file_transfer": 0,
        "image_sync": 0,
        "app_launch": 0,
        "pc_lock": 0
    },
    "pc_uptime_total": 0,
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

# --- MONGODB SETUP ---
db = None
collection = None

def get_db():
    global db, collection, hub_state
    if collection is not None:
        return collection

    if MONGO_URI:
        try:
            client = MongoClient(MONGO_URI)
            db = client['cypher_hub']
            collection = db['state']
            # Try to load existing state from DB
            existing = collection.find_one({"_id": "global_state"})
            if existing:
                for key in existing:
                    if key != "_id":
                        hub_state[key] = existing[key]
            else:
                # First time setup: check for local file migration
                if os.path.exists(DATA_FILE):
                    try:
                        with open(DATA_FILE, 'r') as f:
                            local_data = json.load(f)
                            for key in local_data:
                                if key in hub_state:
                                    hub_state[key] = local_data[key]
                        print("✅ Migrated local hub_data.json to MongoDB")
                    except: pass

                # Save initial state to DB
                collection.replace_one({"_id": "global_state"}, hub_state, upsert=True)
            return collection
        except Exception as e:
            print(f"MongoDB Connection Error: {e}")
            return None
    return None

def load_data():
    global hub_state
    coll = get_db()
    if coll is not None:
        try:
            existing = coll.find_one({"_id": "global_state"})
            if existing:
                for key in existing:
                    if key != "_id":
                        hub_state[key] = existing[key]
        except Exception as e:
            print(f"Error loading from MongoDB: {e}")

def save_data():
    coll = get_db()
    if coll is not None:
        try:
            # We use replace_one to keep a single document as our 'database'
            coll.replace_one({"_id": "global_state"}, hub_state, upsert=True)
        except Exception as e:
            print(f"Error saving to MongoDB: {e}")
    else:
        # Fallback to local file if DB is down
        try:
            with open(DATA_FILE, 'w') as f:
                json.dump(hub_state, f, indent=4)
        except: pass

# Initial load
load_data()

@app.route('/')
def home():
    load_data()
    hub_state['site_visits'] += 1
    save_data()
    return "CYPHER Central Hub is Active (Persistent Mode)."

@app.route('/favicon.ico')
def favicon():
    return '', 204

@app.route('/api/track/visit', methods=['GET'])
def track_visit():
    load_data()
    hub_state['site_visits'] += 1
    save_data()
    return jsonify({"success": True}), 200

# --- CLIENT API ---

@app.route('/api/analytics/install', methods=['POST'])
def report_install():
    load_data()
    install_info = request.json
    install_info['ip'] = request.remote_addr
    install_info['at'] = datetime.now().strftime("%Y-%m-%d %H:%M")
    hub_state['installs'].append(install_info)
    save_data()
    return jsonify({"status": "ok"}), 200

@app.route('/api/broadcast', methods=['GET'])
def get_broadcast():
    load_data()
    ip = request.remote_addr
    ua = request.headers.get('User-Agent', '').lower()
    platform = 'windows' if ('windows' in ua or 'python' in ua) else 'android'

    hub_state['unique_devices'][ip.replace('.', '_')] = {
        "at": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "platform": platform
    }
    save_data()
    return jsonify(hub_state['broadcast']), 200

@app.route('/api/metadata', methods=['GET'])
def get_metadata():
    load_data()
    ip = request.remote_addr
    ua = request.headers.get('User-Agent', '').lower()
    platform = 'windows' if ('windows' in ua or 'python' in ua) else 'android'

    hub_state['unique_devices'][ip.replace('.', '_')] = {
        "at": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "platform": platform
    }
    save_data()
    return jsonify(hub_state['metadata']), 200

@app.route('/api/stats', methods=['GET'])
def get_public_stats():
    """Provides a summarized version of all analytics for the mobile app."""
    load_data()
    win_installs = len([i for i in hub_state['installs'] if i.get('platform') == 'windows'])
    android_installs = len([i for i in hub_state['installs'] if i.get('platform') == 'android'])

    unique_devices = hub_state.get('unique_devices', {})
    now = datetime.now()
    day_ago = now - timedelta(hours=24)
    active_today = len([d for d in unique_devices.values() if isinstance(d, dict) and datetime.strptime(d.get('at', ''), "%Y-%m-%d %H:%M") > day_ago])

    return jsonify({
        "total_installs": win_installs + android_installs,
        "windows": win_installs,
        "android": android_installs,
        "active_today": active_today,
        "total_unique": len(unique_devices),
        "site_visits": hub_state['site_visits'],
        "feature_usage": hub_state.get('feature_usage', {})
    }), 200

# --- MASTER ADMIN API ---

@app.route('/master/broadcast', methods=['POST'])
def update_broadcast():
    load_data()
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
    load_data()
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
                    Active Today: {{ active_today }} | This Week: {{ active_week }}
                </div>
                <div style="margin-top: 5px; font-size: 10px; color: #444;">
                    Total Unique IDs: {{ active_count }}
                </div>
            </div>

            <div class="card">
                <div class="label">FEATURE ENGAGEMENT</div>
                <div style="margin-top: 10px;">
                    <div style="font-size: 13px; color: #888; margin-bottom: 8px;">
                        Screen Record: <span style="color: #00FF88;">{{ usage.screen_record }}</span>
                    </div>
                    <div style="font-size: 13px; color: #888; margin-bottom: 8px;">
                        File Transfers: <span style="color: #00FF88;">{{ usage.file_transfer }}</span>
                    </div>
                    <div style="font-size: 13px; color: #888; margin-bottom: 8px;">
                        Image Sync: <span style="color: #00FF88;">{{ usage.image_sync }}</span>
                    </div>
                    <div style="font-size: 13px; color: #888; margin-bottom: 8px;">
                        App Launches: <span style="color: #00FF88;">{{ usage.app_launch }}</span>
                    </div>
                </div>
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

@app.route('/api/track/feature', methods=['POST'])
def track_feature():
    load_data()
    feature = request.json.get("feature")
    if feature in hub_state['feature_usage']:
        hub_state['feature_usage'][feature] += 1
        save_data()
    return jsonify({"success": True}), 200

@app.route('/master')
def master_panel():
    load_data()

    # 1. Total reported installs
    win_installs = len([i for i in hub_state['installs'] if i.get('platform') == 'windows'])
    android_installs = len([i for i in hub_state['installs'] if i.get('platform') == 'android'])

    # 2. Advanced Retention Calculation
    unique_devices = hub_state.get('unique_devices', {})
    now = datetime.now()
    day_ago = now - timedelta(hours=24)
    week_ago = now - timedelta(days=7)

    active_today = 0
    active_this_week = 0

    for dev_ip, data in unique_devices.items():
        if not isinstance(data, dict): continue
        try:
            last_seen = datetime.strptime(data.get('at', ''), "%Y-%m-%d %H:%M")
            if last_seen > day_ago: active_today += 1
            if last_seen > week_ago: active_this_week += 1
        except: continue

    win_active = len([d for d in unique_devices.values() if isinstance(d, dict) and d.get('platform') == 'windows'])
    android_active = len([d for d in unique_devices.values() if isinstance(d, dict) and d.get('platform') == 'android'])

    total_win = max(win_installs, win_active)
    total_android = max(android_installs, android_active)

    # Feature engagement
    usage = hub_state.get('feature_usage', {})

    return render_template_string(
        ADMIN_HTML,
        count=total_win + total_android,
        win_count=total_win,
        android_count=total_android,
        active_count=len(unique_devices),
        active_today=active_today,
        active_week=active_this_week,
        usage=usage,
        visits=hub_state['site_visits'],
        b=hub_state['broadcast'],
        m=hub_state['metadata'],
        logs=hub_state['installs']
    )

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 8080))
    app.run(host='0.0.0.0', port=port)
