from flask import Flask, jsonify, request, render_template_string
import json
import os
from datetime import datetime

app = Flask(__name__)

# --- CONFIGURATION ---
MASTER_KEY = os.environ.get("MASTER_KEY", "emerald-admin")

# --- HUB STATE ---
hub_state = {
    "installs": [],
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

@app.route('/')
def home():
    return "CYPHER Central Hub is Active."

# --- CLIENT API ---

@app.route('/api/analytics/install', methods=['POST'])
def report_install():
    install_info = request.json
    install_info['ip'] = request.remote_addr
    install_info['at'] = datetime.now().strftime("%Y-%m-%d %H:%M")
    hub_state['installs'].append(install_info)
    return jsonify({"status": "ok"}), 200

@app.route('/api/broadcast', methods=['GET'])
def get_broadcast():
    return jsonify(hub_state['broadcast']), 200

@app.route('/api/metadata', methods=['GET'])
def get_metadata():
    return jsonify(hub_state['metadata']), 200

# --- MASTER ADMIN API ---

@app.route('/master/broadcast', methods=['POST'])
def update_broadcast():
    key = request.form.get("key") or request.json.get("key")
    if key != MASTER_KEY:
        return jsonify({"error": "Unauthorized"}), 401

    # Handle form or JSON
    if request.form:
        hub_state['broadcast'] = {
            "active": 'active' in request.form,
            "title": request.form['title'],
            "message": request.form['message'],
            "link": request.form['link'],
            "link_text": request.form['link_text']
        }
        return "<script>alert('Broadcast Deployed!'); window.location='/master';</script>"
    else:
        hub_state['broadcast'] = request.json['broadcast']
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
        return "<script>alert('Ecosystem Metadata Updated!'); window.location='/master';</script>"
    else:
        hub_state['metadata'] = request.json['metadata']
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

        <div class="card">
            <div class="label">LIVE INSTALLATIONS</div>
            <div class="stat">{{ count }}</div>
            <div style="font-size: 14px; color: #444;">Tracking Android & Windows Ecosystem</div>
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
    # In a real deployment, you'd add a password check here
    return render_template_string(ADMIN_HTML, count=len(hub_state['installs']), b=hub_state['broadcast'], m=hub_state['metadata'], logs=hub_state['installs'])

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 8080))
    app.run(host='0.0.0.0', port=port)
