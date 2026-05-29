import requests
import json
import os
from pathlib import Path

HUB_URL = "https://cypher-3ctq.onrender.com"

def sync():
    print(f"🔄 Fetching latest metadata from {HUB_URL}...")
    try:
        # [PRO FIX] Increased timeout to 30s to allow Render instance to wake up
        response = requests.get(f"{HUB_URL}/api/metadata", timeout=30)
        if response.status_code == 200:
            metadata = response.json()

            # 1. Update metadata.json
            with open("metadata.json", "w") as f:
                json.dump(metadata, f, indent=4)
            print("✅ metadata.json updated.")

            # 2. Update Inno Setup script (cypher_installer.iss)
            iss_path = "cypher_installer.iss"
            if os.path.exists(iss_path):
                with open(iss_path, "r") as f:
                    lines = f.readlines()

                new_lines = []
                for line in lines:
                    if line.startswith("AppId="):
                        new_lines.append(f"AppId={{{metadata['app_id']}}}\n")
                    elif line.startswith("AppName="):
                        new_lines.append(f"AppName={metadata['app_name']}\n")
                    elif line.startswith("AppVersion="):
                        new_lines.append(f"AppVersion={metadata['app_version']}\n")
                    elif line.startswith("AppPublisher="):
                        new_lines.append(f"AppPublisher={metadata['app_publisher']}\n")
                    elif line.startswith("AppPublisherURL="):
                        new_lines.append(f"AppPublisherURL={metadata['app_publisher_url']}\n")
                    else:
                        new_lines.append(line)

                with open(iss_path, "w") as f:
                    f.writelines(new_lines)
                print("✅ cypher_installer.iss updated for build.")

            print("\n🚀 SYNC COMPLETE. You can now run PyInstaller and Inno Setup.")
        else:
            print(f"❌ Failed to fetch: {response.status_code}")
    except Exception as e:
        print(f"❌ Error during sync: {e}")

if __name__ == "__main__":
    sync()
