import os
import re
import json
from pathlib import Path

# --- CONFIGURATION ---
VERSION = "1.0.0"  # Set the target version here
GITHUB_URL = "https://github.com/Oluwadaredaniel/Cypher"

FILES_TO_SYNC = {
    "pc_metadata": Path("pc_app/metadata.json"),
    "mobile_pubspec": Path("mobile_app/pubspec.yaml"),
    "mobile_service": Path("mobile_app/lib/services/central_service.dart"),
    "pc_installer": Path("pc_app/cypher_installer.iss"),
    "landing_page": Path("index.html")
}

def sync_pc_metadata():
    path = FILES_TO_SYNC["pc_metadata"]
    if not path.exists(): return
    print(f"Updating {path}...")
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    data["app_version"] = VERSION
    data["app_updates_url"] = f"{GITHUB_URL}/releases/latest"
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4)

def sync_mobile_pubspec():
    path = FILES_TO_SYNC["mobile_pubspec"]
    if not path.exists(): return
    print(f"Updating {path}...")
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = re.sub(r'^version: .+', f'version: {VERSION}+1', content, flags=re.MULTILINE)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def sync_mobile_service():
    path = FILES_TO_SYNC["mobile_service"]
    if not path.exists(): return
    print(f"Updating {path}...")
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = re.sub(r'static const String _currentVersion = ".+";', f'static const String _currentVersion = "{VERSION}";', content)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def sync_pc_installer():
    path = FILES_TO_SYNC["pc_installer"]
    if not path.exists(): return
    print(f"Updating {path}...")
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = re.sub(r'^#define MyAppVersion ".+"', f'#define MyAppVersion "{VERSION}"', content, flags=re.MULTILINE)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def sync_landing_page():
    path = FILES_TO_SYNC["landing_page"]
    if not path.exists(): return
    print(f"Updating {path}...")
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Update download links to point to the latest
    content = re.sub(r'href="https://github.com/.+/releases/.+/download/Cypher_Setup.exe"',
                     f'href="{GITHUB_URL}/releases/latest/download/Cypher_Setup.exe"', content)
    content = re.sub(r'href="https://github.com/.+/releases/.+/download/cypher.apk"',
                     f'href="{GITHUB_URL}/releases/latest/download/cypher.apk"', content)

    # Update Hero CTA to point to latest releases
    content = re.sub(r'href="https://github.com/.+/releases"',
                     f'href="{GITHUB_URL}/releases/latest"', content)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == "__main__":
    print(f"🚀 Starting Sync for Version {VERSION}...")
    sync_pc_metadata()
    sync_mobile_pubspec()
    sync_mobile_service()
    sync_pc_installer()
    sync_landing_page()
    print("✅ All files synchronized successfully.")
