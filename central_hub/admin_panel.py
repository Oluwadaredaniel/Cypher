from flask import Flask, jsonify, request, render_template_string
import json
from datetime import datetime
from pathlib import Path

app = Flask(__name__)

# --- STORAGE ---
DATA_FILE = Path("hub_data.json")
if not DATA_FILE.exists():
    with open(DATA_FILE, "w") as f:
        json.dump({"installs": [], "broadcast": {"active": True, "title": "Join our Community!", "message": "Connect with other Cypher users on WhatsApp.", "link": "https://chat.whatsapp.com/example", "link_text": "Join Group"}}, f)

def load_data():
    with open(DATA_FILE, "r") as f: return json.load(f)

def save_data(data):
    with open(DATA_FILE, "w") as f: json.dump(data, f, indent=4)

# --- API ENDPOINTS ---

@app.route('/api/analytics/install', methods=['POST'])
def report_install():
    data = load_data()
    install_info = request.json
    install_info['ip'] = request.remote_addr
    data['installs'].append(install_info)
    save_data(data)
    return jsonify({"status": "success"}), 200

@app.route('/api/broadcast', methods=['GET'])
def get_broadcast():
    data = load_data()
    return jsonify(data['broadcast']), 200

# --- ADMIN WEB UI ---

ADMIN_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>CYPHER Admin Hub</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #0D0D0D; color: white; padding: 40px; }
        .card { background: #1A1A1A; padding: 25px; border-radius: 20px; margin-bottom: 20px; border: 1px solid #333; }
        h1 { color: #6C63FF; }
        .stat { font-size: 48px; font-weight: bold; }
        input, textarea { width: 100%; padding: 12px; margin: 10px 0; border-radius: 10px; border: 1px solid #444; background: #000; color: white; }
        button { background: #6C63FF; color: white; border: none; padding: 12px 30px; border-radius: 100px; cursor: pointer; font-weight: bold; }
        button:hover { background: #5B52E5; }
        .label { color: #86868B; font-size: 12px; font-weight: bold; }
    </style>
</head>
<body>
    <h1>Emerald's Cypher Hub</h1>

    <div class="card">
        <div class="label">TOTAL INSTALLS</div>
        <div class="stat">{{ install_count }}</div>
    </div>

    <div class="card">
        <div class="label">BROADCAST SETTINGS</div>
        <form method="POST" action="/admin/update_broadcast">
            <input type="text" name="title" placeholder="Title" value="{{ b.title }}">
            <textarea name="message" placeholder="Message">{{ b.message }}</textarea>
            <input type="text" name="link" placeholder="Link (WhatsApp/Social)" value="{{ b.link }}">
            <input type="text" name="link_text" placeholder="Button Text" value="{{ b.link_text }}">
            <label><input type="checkbox" name="active" {% if b.active %}checked{% endif %}> Active</label><br><br>
            <button type="submit">Update All Users</button>
        </form>
    </div>

    <div class="card">
        <div class="label">RECENT ACTIVITY</div>
        <ul style="color: #86868B; font-size: 14px;">
            {% for install in installs[-10:] %}
                <li>New Install on {{ install.platform }} ({{ install.timestamp }})</li>
            {% endfor %}
        </ul>
    </div>
</body>
</html>
"""

@app.route('/admin')
def admin_panel():
    data = load_data()
    return render_template_string(ADMIN_HTML, install_count=len(data['installs']), b=data['broadcast'], installs=data['installs'])

@app.route('/admin/update_broadcast', methods=['POST'])
def update_broadcast():
    data = load_data()
    data['broadcast'] = {
        "active": 'active' in request.form,
        "title": request.form['title'],
        "message": request.form['message'],
        "link": request.form['link'],
        "link_text": request.form['link_text']
    }
    save_data(data)
    return "Broadcast Updated! Restart your mobile app to see changes.", 200

if __name__ == '__main__':
    app.run(port=8080, debug=True)
