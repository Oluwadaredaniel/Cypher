import customtkinter as ctk
import requests
import threading
import time
import socket
import json
import qrcode
import webbrowser
from PIL import Image
from pathlib import Path
from core.server import ui_queue, INTERNAL_TOKEN
from core.utils import get_config_path, get_app_data_dir, get_metadata
from core.guest_panel import GuestPanel

# PRO DESIGN SYSTEM - Glassmorphism Edition
COLORS = {
    "bg": "#08080A",
    "sidebar": "#0C0C0E",
    "card": "#121216",
    "accent": "#6C63FF",
    "accent_dim": "#3A3485",
    "hover": "#1A1A22",
    "secondary": "#8E8E93",
    "white": "#FFFFFF",
    "success": "#30D158",
    "danger": "#FF453A",
    "warning": "#FF9F0A"
}

class DashboardScreen(ctk.CTkFrame):
    def __init__(self, parent):
        super().__init__(parent, fg_color=COLORS["bg"], corner_radius=0)
        
        self.parent = parent
        self.connected_device = None
        self.connect_code = "------"
        self.local_ip = self.get_local_ip()
        self.active_panel_name = "Home"
        self.toasts = []
        self.stop_polling = False

        # UI Elements initialization (avoiding AttributeError in threads)
        self.code_display = None
        self.transfer_indicator = None
        self.transfers_container = None
        self.activity_container = None
        self.quick_history = None
        self.stat_cards = {}
        self.qr_label = None
        self.qr_img_ref = None # Keep reference to prevent GC

        # Sidebar navigation items
        self.nav_items = [
            {"name": "Home", "icon": "🏠"},
            {"name": "Transfers", "icon": "⚡"},
            {"name": "Trends", "icon": "📊"},
            {"name": "Shared Files", "icon": "📁"},
            {"name": "Security", "icon": "🛡️"},
            {"name": "Activity", "icon": "📜"},
            {"name": "Settings", "icon": "⚙️"},
        ]

        self.setup_layout()
        self.start_data_sync()
        self.process_ui_queue()

        # [NEW] Automatic Update Check on Startup
        self.after(5000, self.trigger_update_check)

    def process_ui_queue(self):
        """Checks for events from the server and shows toast notifications."""
        try:
            while True:
                msg = ui_queue.get_nowait()
                self.show_toast(msg["action"], msg["device"])
        except: pass
        self.after(500, self.process_ui_queue)

    def show_toast(self, title, device):
        toast = ctk.CTkFrame(self, fg_color=COLORS["accent"], corner_radius=16, height=60, width=300)
        toast.place(relx=0.98, rely=0.95, anchor="se")

        ctk.CTkLabel(toast, text=f"📱 {device}: {title}", font=("Segoe UI", 13, "bold"), text_color="#FFF").pack(padx=20, pady=15)

        # Auto-hide after 3 seconds
        self.after(3000, toast.destroy)

    def get_local_ip(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except: return "127.0.0.1"

    def setup_layout(self):
        # Apply modern Window attributes
        self.parent.protocol("WM_DELETE_WINDOW", self.minimize_to_tray)

        # LEFT SIDEBAR
        self.sidebar = ctk.CTkFrame(self, fg_color=COLORS["sidebar"], width=240, corner_radius=0)
        self.sidebar.pack(side="left", fill="y")
        self.sidebar.pack_propagate(False)

        # Brand Header (Premium)
        brand = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        brand.pack(pady=(50, 40), padx=25, fill="x")
        
        meta = get_metadata()
        app_name = meta.get("app_name", "CYPHER")

        # Dynamic Logo Rendering with better styling
        for i, char in enumerate(app_name):
            color = COLORS["accent"] if i == 0 else "#FFF"
            ctk.CTkLabel(brand, text=char, font=("Segoe UI", 32, "bold"), text_color=color).pack(side="left", padx=1)

        # Connection Status Pill (Glass style)
        self.status_pill = ctk.CTkLabel(self.sidebar, text="●  WAITING",
                                        font=("Segoe UI", 11, "bold"),
                                        text_color=COLORS["secondary"],
                                        fg_color="#18181B",
                                        corner_radius=10,
                                        height=32)
        self.status_pill.pack(pady=(0, 40), padx=35, fill="x")

        # Navigation
        self.nav_btns = {}
        for item in self.nav_items:
            btn = ctk.CTkButton(self.sidebar,
                                text=f"   {item['icon']}   {item['name']}",
                                font=("Segoe UI", 13, "bold"),
                                anchor="w",
                                height=54,
                                corner_radius=14,
                                fg_color="transparent",
                                text_color=COLORS["secondary"],
                                hover_color=COLORS["hover"],
                                command=lambda n=item['name']: self.switch_panel(n))
            btn.pack(fill="x", padx=18, pady=5)
            self.nav_btns[item['name']] = btn

        footer = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        footer.pack(side="bottom", fill="x", pady=20, padx=20)

        meta = get_metadata()
        version_text = f"v{meta.get('app_version', '1.0.0')} (Production)"
        self.version_lbl = ctk.CTkLabel(footer, text=version_text, font=("Segoe UI", 10), text_color="#333")
        self.version_lbl.pack(anchor="w")

        self.update_btn = ctk.CTkButton(footer, text="Check for Updates",
                                        font=("Segoe UI", 10, "bold"),
                                        fg_color="transparent",
                                        text_color=COLORS["accent"],
                                        height=24,
                                        anchor="w",
                                        hover_color=COLORS["hover"],
                                        command=self.trigger_update_check)
        self.update_btn.pack(anchor="w", pady=(2, 0))

        self.recording_alert = ctk.CTkLabel(footer, text="● RECORDING LIVE",
                                            font=("Segoe UI", 10, "bold"),
                                            text_color=COLORS["danger"])
        # Hidden by default

        self.device_info = ctk.CTkLabel(footer, text="System standby",
                                        font=("Segoe UI", 11),
                                        text_color="#444")
        self.device_info.pack(anchor="w")

        self.cancel_btn = ctk.CTkButton(footer, text="Terminate Transfers",
                                        font=("Segoe UI", 11, "bold"),
                                        fg_color="#1A1A1A",
                                        text_color=COLORS["danger"],
                                        height=28,
                                        corner_radius=8,
                                        command=self.cancel_transfers)
        self.cancel_btn.pack(anchor="w", pady=(10, 0), fill="x")

        credit = ctk.CTkLabel(footer, text="Designed by Emerald",
                              font=("Segoe UI", 11, "bold"),
                              text_color=COLORS["accent"], cursor="hand2")
        credit.pack(anchor="w", pady=(5, 0))
        credit.bind("<Button-1>", lambda e: webbrowser.open("https://linktr.ee/Emerald_dev"))

        year_label = ctk.CTkLabel(footer, text="© 2026 Emerald Dev Team",
                                  font=("Segoe UI", 10),
                                  text_color="#333")
        year_label.pack(anchor="w", pady=(2, 0))

        # MAIN CONTENT AREA
        self.main_content = ctk.CTkFrame(self, fg_color="transparent")
        self.main_content.pack(side="right", fill="both", expand=True, padx=40, pady=40)

        self.switch_panel("Home")

    def cancel_transfers(self):
        def do_cancel():
            try:
                requests.post("http://localhost:5000/files/download/cancel", timeout=1)
                self.after(0, lambda: self.show_toast("Transfers Cancelled", "System"))
            except: pass
        threading.Thread(target=do_cancel, daemon=True).start()

    def minimize_to_tray(self):
        self.parent.withdraw()
        # tray.py is already running in background
        self.show_toast("Running in background", "System")

    def trigger_update_check(self):
        from core.utils import check_for_updates
        self.update_btn.configure(text="Checking...", state="disabled")

        def do_check():
            result = check_for_updates()
            def update_ui():
                if result.get("update_available"):
                    # High Visibility Broadcast on PC
                    self.show_toast(f"Critical Update: v{result['version']}", "System")
                    self.update_btn.configure(text=f"🎁 Update to v{result['version']}",
                                               fg_color=COLORS["accent"],
                                               text_color="#FFF",
                                               state="normal",
                                               command=lambda: self.start_auto_update(result["url"]))

                    # Also show a banner if on Home screen
                    if self.active_panel_name == "Home":
                        self.render_update_banner(result['version'], result['url'])
                else:
                    self.show_toast("App is up to date", "System")
                    self.update_btn.configure(text="✨ Check for Updates", state="normal")
            self.after(0, update_ui)

        threading.Thread(target=do_check, daemon=True).start()

    def render_update_banner(self, version, url):
        banner = ctk.CTkFrame(self.main_content, fg_color=COLORS["accent"], corner_radius=16, height=50)
        banner.pack(fill="x", pady=(0, 20), before=self.main_content.winfo_children()[0])

        ctk.CTkLabel(banner, text=f"🚀 A new version (v{version}) is available! Upgrade now for the latest features.",
                     font=("Segoe UI", 12, "bold"), text_color="#FFF").pack(side="left", padx=20)

        ctk.CTkButton(banner, text="Install Now", width=100, height=30, corner_radius=8,
                      fg_color="#FFF", text_color=COLORS["accent"], font=("Segoe UI", 11, "bold"),
                      command=lambda: self.start_auto_update(url)).pack(side="right", padx=10)

    def start_auto_update(self, url):
        """Downloads the new installer and runs it."""
        import os
        import subprocess
        self.show_toast("Preparing Update...", "System")

        def download():
            try:
                import requests
                from core.utils import get_app_data_dir

                installer_path = get_app_data_dir() / "cypher_upgrade.exe"

                # Use a session for better timeout handling
                with requests.Session() as s:
                    self.after(0, lambda: self.show_toast("Downloading v1.0.1...", "System"))
                    r = s.get(url, stream=True, timeout=30)
                    r.raise_for_status() # Check for HTTP errors

                    with open(installer_path, 'wb') as f:
                        for chunk in r.iter_content(chunk_size=16384):
                            if chunk:
                                f.write(chunk)

                # Launch the installer and exit
                self.after(0, lambda: self.show_toast("Applying Update... App will restart.", "System"))
                time.sleep(2)

                # Launch the new installer.
                # Note: Inno Setup's CloseApplications=yes will handle closing the old app.
                subprocess.Popen([str(installer_path), "/SILENT", "/SP-", "/SUPPRESSMSGBOXES", "/NOCANCEL"])
                os._exit(0)
            except Exception as e:
                self.after(0, lambda: self.show_toast("Download Failed. Check Internet.", "System"))
                print(f"Update error: {e}")

        threading.Thread(target=download, daemon=True).start()

    def switch_panel(self, name):
        # Update Nav UI
        if self.active_panel_name in self.nav_btns:
            self.nav_btns[self.active_panel_name].configure(fg_color="transparent", text_color=COLORS["secondary"])
        
        self.active_panel_name = name
        self.nav_btns[name].configure(fg_color=COLORS["accent"], text_color="#FFF")

        # Clear Content
        for widget in self.main_content.winfo_children():
            widget.destroy()

        # Reset UI references
        self.code_display = None
        self.transfer_indicator = None
        self.transfers_container = None
        self.activity_container = None
        self.quick_history = None
        self.stat_cards = {}
        self.qr_label = None

        # Route to Panel
        if name == "Home": self.render_home()
        elif name == "Transfers": self.render_transfers()
        elif name == "Trends": self.render_trends()
        elif name == "Shared Files": self.render_files()
        elif name == "Security": self.render_security()
        elif name == "Activity": self.render_activity()
        elif name == "Settings": self.render_settings()

    # --- PANEL RENDERING ---

    def render_home(self):
        settings = {}
        try:
            with open(get_config_path("settings.json"), 'r') as f:
                settings = json.load(f)
        except: pass

        pc_display_name = settings.get("device_name", "My PC")

        header = ctk.CTkLabel(self.main_content, text=pc_display_name, font=("Segoe UI", 32, "bold"), text_color="#FFF")
        header.pack(anchor="w", pady=(0, 30))

        if not self.connected_device:
            self.render_waiting_state()
        else:
            self.render_connected_state()

    def render_waiting_state(self):
        container = ctk.CTkFrame(self.main_content, fg_color="transparent")
        container.pack(fill="both", expand=True)

        # Radar Visualization
        radar_box = ctk.CTkFrame(container, fg_color="transparent")
        radar_box.pack(pady=40)

        self.radar_circle = ctk.CTkFrame(radar_box, width=120, height=120, corner_radius=60,
                                         border_width=2, border_color=COLORS["accent"], fg_color="transparent")
        self.radar_circle.pack()
        ctk.CTkLabel(self.radar_circle, text="📡", font=("Segoe UI", 40)).place(relx=0.5, rely=0.5, anchor="center")
        self.animate_radar()

        ctk.CTkLabel(container, text="Ready to Link", font=("Segoe UI", 24, "bold")).pack()
        ctk.CTkLabel(container, text="Open CYPHER on your phone to begin", font=("Segoe UI", 14), text_color=COLORS["secondary"]).pack(pady=5)

        # Large Connect Code Card (Premium)
        code_card = ctk.CTkFrame(container, fg_color=COLORS["card"], corner_radius=32, border_width=1, border_color="#1D1D26")
        code_card.pack(pady=40, padx=80, fill="x")

        ctk.CTkLabel(code_card, text="YOUR CONNECT CODE", font=("Segoe UI", 12, "bold"), text_color=COLORS["secondary"]).pack(pady=(50, 10))

        self.code_display = ctk.CTkLabel(code_card, text=" ".join(self.connect_code), font=("Courier New", 72, "bold"), text_color=COLORS["accent"])
        self.code_display.pack(pady=(0, 50))

        ip_row = ctk.CTkFrame(code_card, fg_color="transparent")
        ip_row.pack(pady=(0, 50))
        ctk.CTkLabel(ip_row, text=f"PC Address: {self.local_ip}", font=("Segoe UI", 14), text_color="#3F3F46").pack(side="left", padx=20)

    def render_connected_state(self):
        container = ctk.CTkFrame(self.main_content, fg_color="transparent")
        container.pack(fill="both", expand=True)

        # Hero Banner (Glass Design)
        banner = ctk.CTkFrame(container, fg_color="#12121A", corner_radius=24, border_width=1, border_color="#1D1D26")
        banner.pack(fill="x", pady=(0, 30))
        banner.pack_propagate(False)

        txt_col = ctk.CTkFrame(banner, fg_color="transparent")
        txt_col.pack(side="left", padx=35, pady=30)
        ctk.CTkLabel(txt_col, text=f"Linked to {self.connected_device}", font=("Segoe UI", 24, "bold"), text_color=COLORS["success"]).pack(anchor="w")
        ctk.CTkLabel(txt_col, text="Warp-speed synchronization active.", font=("Segoe UI", 14), text_color="#6B7280").pack(anchor="w")

        # Compact Code & Mini-Stats Row
        info_row = ctk.CTkFrame(container, fg_color="transparent")
        info_row.pack(fill="x", pady=10)

        # Persistent Mini-Code Card (So you can still see it while connected!)
        code_card = ctk.CTkFrame(info_row, fg_color=COLORS["card"], corner_radius=20, border_width=1, border_color="#1D1D26")
        code_card.pack(side="left", fill="x", expand=True, padx=8)
        ctk.CTkLabel(code_card, text="CONNECT CODE", font=("Segoe UI", 10, "bold"), text_color=COLORS["secondary"]).pack(pady=(15, 0))
        self.code_display = ctk.CTkLabel(code_card, text=" ".join(self.connect_code), font=("Courier New", 28, "bold"), text_color=COLORS["accent"])
        self.code_display.pack(pady=(0, 15))

        # Mini Stats (More useful/compact)
        self.stat_cards = {}
        for label in ["CPU", "RAM"]:
            card = ctk.CTkFrame(info_row, fg_color=COLORS["card"], corner_radius=20, border_width=1, border_color="#1D1D26")
            card.pack(side="left", fill="x", expand=True, padx=8)
            ctk.CTkLabel(card, text=label, font=("Segoe UI", 10, "bold"), text_color=COLORS["secondary"]).pack(pady=(15, 0))
            val = ctk.CTkLabel(card, text="0%", font=("Segoe UI", 28, "bold"), text_color="#FFF")
            val.pack(pady=(0, 15))
            self.stat_cards[label + " Usage" if label != "Disk Space" else label] = val

        # Recent Quick Activity
        ctk.CTkLabel(container, text="Recent Stream", font=("Segoe UI", 18, "bold")).pack(anchor="w", pady=(40, 15))
        self.quick_history = ctk.CTkFrame(container, fg_color="transparent")
        self.quick_history.pack(fill="both", expand=True)
        self.update_history_list()

    def render_files(self):
        header = ctk.CTkLabel(self.main_content, text="Shared Folders", font=("Segoe UI", 32, "bold"), text_color="#FFF")
        header.pack(anchor="w", pady=(0, 10))
        ctk.CTkLabel(self.main_content, text="Manage which parts of your PC the phone can see.", font=("Segoe UI", 14), text_color=COLORS["secondary"]).pack(anchor="w", pady=(0, 30))

        scroll = ctk.CTkScrollableFrame(self.main_content, fg_color="transparent")
        scroll.pack(fill="both", expand=True)

        loading_lbl = ctk.CTkLabel(scroll, text="Loading file system...", text_color=COLORS["secondary"])
        loading_lbl.pack(pady=40)

        def load():
            try:
                # [FIX] Always request from /settings to get the true persistent list
                r = requests.get(f"http://localhost:5000/settings", headers={"X-Auth-Token": INTERNAL_TOKEN}, timeout=2)
                if r.status_code == 200:
                    data = r.json()
                    folders = data.get("shared_folders", [])

                    def update_ui():
                        if not scroll.winfo_exists(): return
                        loading_lbl.destroy()
                        if not folders:
                            ctk.CTkLabel(scroll, text="No shared folders found.", text_color=COLORS["secondary"]).pack(pady=40)
                            return
                        for f_path in folders:
                            # Standardize format for UI
                            f_obj = {'name': os.path.basename(f_path) or f_path, 'path': f_path}

                            card = ctk.CTkFrame(scroll, fg_color=COLORS["card"], corner_radius=16, height=70)
                            card.pack(fill="x", pady=6)
                            card.pack_propagate(False)
                            ctk.CTkLabel(card, text="📁", font=("Segoe UI", 20)).pack(side="left", padx=20)
                            ctk.CTkLabel(card, text=f_obj['name'], font=("Segoe UI", 15, "bold")).pack(side="left")
                            ctk.CTkLabel(card, text=f_obj['path'], font=("Segoe UI", 12), text_color="#444").pack(side="left", padx=20)

                            # Add functioning Remove button
                            btn = ctk.CTkButton(card, text="Remove", width=80, height=32, corner_radius=10,
                                          fg_color="#222", hover_color=COLORS["danger"],
                                          command=lambda p=f_path: self.remove_shared_folder(p))
                            btn.pack(side="right", padx=20)
                    self.after(0, update_ui)
                else:
                    self.after(0, lambda: loading_lbl.configure(text=f"Server error: {r.status_code}", text_color=COLORS["danger"]))
            except Exception as e:
                self.after(0, lambda: loading_lbl.configure(text=f"Connection failed: {str(e)}", text_color=COLORS["danger"]))

        threading.Thread(target=load, daemon=True).start()

    def remove_shared_folder(self, path):
        """API call to remove a folder from persistence."""
        def _do_remove():
            try:
                # 1. Get current list
                r = requests.get("http://localhost:5000/settings", headers={"X-Auth-Token": INTERNAL_TOKEN}, timeout=2)
                if r.status_code == 200:
                    current = r.json().get("shared_folders", [])
                    if path in current:
                        current.remove(path)
                        # 2. Save new list
                        requests.post("http://localhost:5000/settings",
                                     headers={"X-Auth-Token": INTERNAL_TOKEN},
                                     json={"shared_folders": current}, timeout=2)
                        # 3. Refresh UI
                        self.after(0, self.render_files)
            except: pass
        threading.Thread(target=_do_remove, daemon=True).start()

    def render_security(self):
        header = ctk.CTkLabel(self.main_content, text="Security & Guest Access", font=("Segoe UI", 32, "bold"), text_color="#FFF")
        header.pack(anchor="w", pady=(0, 20))

        # We now use the dedicated GuestPanel class for a better experience
        guest_frame = GuestPanel(self.main_content)
        guest_frame.pack(fill="both", expand=True)

    def render_transfers(self):
        ctk.CTkLabel(self.main_content, text="Active Transfers", font=("Segoe UI", 32, "bold"), text_color="#FFF").pack(anchor="w", pady=(0, 10))
        ctk.CTkLabel(self.main_content, text="Real-time monitoring of incoming and outgoing files.", font=("Segoe UI", 14), text_color=COLORS["secondary"]).pack(anchor="w", pady=(0, 30))

        self.transfers_container = ctk.CTkScrollableFrame(self.main_content, fg_color="transparent")
        self.transfers_container.pack(fill="both", expand=True)
        self.update_transfers_list()

    def update_transfers_list(self):
        if self.active_panel_name != "Transfers" or self.transfers_container is None: return

        def load():
            try:
                r = requests.get("http://localhost:5000/files/transfers", headers={"X-Auth-Token": INTERNAL_TOKEN}, timeout=1)
                if r.status_code == 200:
                    transfers = r.json()
                    def update_ui():
                        if self.transfers_container is None or not self.transfers_container.winfo_exists(): return
                        for widget in self.transfers_container.winfo_children():
                            widget.destroy()

                        if not transfers:
                            ctk.CTkLabel(self.transfers_container, text="No active or recent transfers.", font=("Segoe UI", 14), text_color="#444").pack(pady=100)
                        else:
                            for tid, t in sorted(transfers.items(), key=lambda x: x[1].get('start_time', 0), reverse=True):
                                card = ctk.CTkFrame(self.transfers_container, fg_color=COLORS["card"], corner_radius=16)
                                card.pack(fill="x", pady=6)

                                # Inner Padding
                                c = ctk.CTkFrame(card, fg_color="transparent")
                                c.pack(fill="x", padx=25, pady=25)

                                header = ctk.CTkFrame(c, fg_color="transparent")
                                header.pack(fill="x")
                                ctk.CTkLabel(header, text=t['name'], font=("Segoe UI", 15, "bold")).pack(side="left")
                                status_text = t['status'].upper()
                                if t['status'] == "receiving":
                                    status_text = f"RECEIVING • {t.get('speed', '0 KB/s')}"
                                ctk.CTkLabel(header, text=status_text, font=("Segoe UI", 11, "bold"), text_color=COLORS["accent"]).pack(side="right")
                                prog = t.get('progress', 0) / 100.0
                                bar = ctk.CTkProgressBar(c, progress_color=COLORS["accent"], height=8)
                                bar.set(prog)
                                bar.pack(fill="x", pady=(15, 5))
                                ctk.CTkLabel(c, text=f"{t.get('progress', 0)}% Completed", font=("Segoe UI", 10), text_color=COLORS["secondary"]).pack(anchor="e")
                    self.after(0, update_ui)
            except: pass
            self.after(2000, self.update_transfers_list)

        threading.Thread(target=load, daemon=True).start()

    def render_trends(self):
        if self.active_panel_name != "Trends": return

        ctk.CTkLabel(self.main_content, text="System Health Trends", font=("Segoe UI", 32, "bold"), text_color="#FFF").pack(anchor="w", pady=(0, 10))
        ctk.CTkLabel(self.main_content, text="Real-time resource allocation and performance monitoring.", font=("Segoe UI", 14), text_color=COLORS["secondary"]).pack(anchor="w", pady=(0, 30))

        container = ctk.CTkFrame(self.main_content, fg_color="transparent")
        container.pack(fill="both", expand=True)

        def load():
            # [FIX] Immediate check to stop thread if tab was switched
            if self.active_panel_name != "Trends": return

            try:
                r = requests.get("http://localhost:5000/system/resource-trends", headers={"X-Auth-Token": INTERNAL_TOKEN}, timeout=1)
                if r.status_code == 200:
                    data = r.json()
                    def update_ui():
                        # [FIX] Final check before updating the UI
                        if self.active_panel_name != "Trends" or not container.winfo_exists(): return
                        for widget in container.winfo_children(): widget.destroy()

                        for metric in ["cpu", "ram"]:
                            card = ctk.CTkFrame(container, fg_color=COLORS["card"], corner_radius=24)
                            card.pack(fill="x", pady=10)

                            inner = ctk.CTkFrame(card, fg_color="transparent")
                            inner.pack(fill="x", padx=30, pady=25)

                            label_text = "PROCESSOR LOAD (CPU)" if metric == "cpu" else "MEMORY USAGE (RAM)"
                            ctk.CTkLabel(inner, text=label_text, font=("Segoe UI", 11, "bold"), text_color=COLORS["accent"]).pack(anchor="w")

                            current_val = data[metric][-1] if data[metric] else 0
                            ctk.CTkLabel(inner, text=f"{int(current_val)}%", font=("Segoe UI", 32, "bold")).pack(anchor="w")

                            # Visual "Sparkline" using small bars
                            spark_box = ctk.CTkFrame(inner, fg_color="transparent", height=40)
                            spark_box.pack(fill="x", pady=(15, 0))

                            recent_points = data[metric][-20:]
                            for p in recent_points:
                                bar_height = max(4, int(p * 0.4))
                                f = ctk.CTkFrame(spark_box, width=6, height=bar_height, corner_radius=3, fg_color=COLORS["accent"])
                                f.pack(side="left", padx=1, anchor="s")

                    self.after(0, update_ui)
            except: pass
            self.after(2000, self.render_trends)

        threading.Thread(target=load, daemon=True).start()

    def render_activity(self):
        header_row = ctk.CTkFrame(self.main_content, fg_color="transparent")
        header_row.pack(fill="x", pady=(0, 20))

        ctk.CTkLabel(header_row, text="Activity & Transfers", font=("Segoe UI", 32, "bold"), text_color="#FFF").pack(side="left")

        self.transfer_indicator = ctk.CTkLabel(header_row, text="No active transfers", font=("Segoe UI", 12), text_color=COLORS["secondary"])
        self.transfer_indicator.pack(side="right", padx=20)

        self.activity_container = ctk.CTkScrollableFrame(self.main_content, fg_color="transparent")
        self.activity_container.pack(fill="both", expand=True)
        self.update_full_history()

    def render_settings(self):
        ctk.CTkLabel(self.main_content, text="Settings", font=("Segoe UI", 32, "bold"), text_color="#FFF").pack(anchor="w", pady=(0, 30))

        # [FIX] Use a Scrollable Frame for settings to ensure the button is always visible
        self.settings_scroll = ctk.CTkScrollableFrame(self.main_content, fg_color="transparent")
        self.settings_scroll.pack(fill="both", expand=True)

        # Update Section (Prominent)
        update_card = ctk.CTkFrame(self.settings_scroll, fg_color="#1A1A2E", corner_radius=24, border_width=1, border_color=COLORS["accent"])
        update_card.pack(fill="x", pady=(0, 20))

        up_inner = ctk.CTkFrame(update_card, fg_color="transparent")
        up_inner.pack(fill="x", padx=30, pady=25)

        ctk.CTkLabel(up_inner, text="SOFTWARE UPDATE", font=("Segoe UI", 11, "bold"), text_color=COLORS["accent"]).pack(anchor="w")
        ctk.CTkLabel(up_inner, text="Keep CYPHER Unbreakable", font=("Segoe UI", 18, "bold")).pack(anchor="w", pady=(5, 10))

        self.settings_update_btn = ctk.CTkButton(up_inner, text="Check for Updates Now",
                                                 fg_color=COLORS["accent"],
                                                 height=40, corner_radius=20,
                                                 font=("Segoe UI", 13, "bold"),
                                                 command=self.trigger_update_check)
        self.settings_update_btn.pack(side="right")

        ctk.CTkLabel(up_inner, text="Current Version: v1.0.0", font=("Segoe UI", 13), text_color=COLORS["secondary"]).pack(side="left")

        card = ctk.CTkFrame(self.settings_scroll, fg_color=COLORS["card"], corner_radius=24)
        card.pack(fill="x")

        # Inner padding for settings
        inner = ctk.CTkFrame(card, fg_color="transparent")
        inner.pack(fill="x", padx=30, pady=30)

        # Options
        self.create_setting_row(inner, "Device Visibility", "Broadcast your PC name to the network", True)
        self.pc_name_entry = self.create_setting_row(inner, "PC Display Name", "Rename how your PC appears on phones", False, is_name=True)
        self.create_setting_row(inner, "Auto-Clipboard", "Sync clipboard without confirmation", False)
        self.create_setting_row(inner, "Launch on Startup", "Start CYPHER when Windows boots", True)

        # [FIX] Better button styling: Fixed width and centered
        ctk.CTkButton(self.settings_scroll, text="Save All Changes",
                      fg_color=COLORS["accent"], height=50, width=200,
                      corner_radius=25, font=("Helvetica Neue", 15, "bold"),
                      command=self.save_pc_settings).pack(pady=40)

    def save_pc_settings(self):
        """Captures settings from UI and saves to the config file."""
        new_name = self.pc_name_entry.get().strip()
        if not new_name:
             # Use current if empty
             try:
                 with open(get_config_path("settings.json"), 'r') as f:
                     new_name = json.load(f).get("device_name", "My PC")
             except: new_name = "My PC"

        payload = {
            "device_name": new_name
            # Switches would go here in a full implementation
        }

        try:
            r = requests.post("http://localhost:5000/settings",
                              headers={"X-Auth-Token": INTERNAL_TOKEN},
                              json=payload, timeout=2)
            if r.status_code == 200:
                self.show_toast("Settings Applied", "System")
            else:
                self.show_toast("Save Failed", "System")
        except:
            self.show_toast("Server Unreachable", "System")

    def create_setting_row(self, parent, title, desc, default, is_name=False):
        row = ctk.CTkFrame(parent, fg_color="transparent", height=70)
        row.pack(fill="x", pady=5)
        row.pack_propagate(False)

        info = ctk.CTkFrame(row, fg_color="transparent")
        info.pack(side="left")
        ctk.CTkLabel(info, text=title, font=("Segoe UI", 15, "bold")).pack(anchor="w")
        ctk.CTkLabel(info, text=desc, font=("Segoe UI", 12), text_color=COLORS["secondary"]).pack(anchor="w")

        if is_name:
            try:
                with open(get_config_path("settings.json"), 'r') as f:
                    curr_name = json.load(f).get("device_name", "My PC")
            except: curr_name = "My PC"

            # [FIX] Better styling for Name input
            entry = ctk.CTkEntry(row, placeholder_text=curr_name, width=220,
                                 fg_color="#050505", border_color="#333", corner_radius=8)
            entry.pack(side="right", padx=10)
            return entry
        else:
            sw = ctk.CTkSwitch(row, text="", progress_color=COLORS["accent"])
            if default: sw.select()
            sw.pack(side="right")
            return sw

    # --- LOGIC & UPDATES ---

    def animate_radar(self):
        if self.active_panel_name == "Home" and not self.connected_device:
            if hasattr(self, "radar_circle") and self.radar_circle.winfo_exists():
                curr = self.radar_circle.cget("border_width")
                new = 6 if curr == 2 else 2
                self.radar_circle.configure(border_width=new)
                self.after(800, self.animate_radar)

    def start_data_sync(self):
        headers = {"X-Auth-Token": INTERNAL_TOKEN}
        def sync():
            while not self.stop_polling:
                try:
                    # Sync Connection Code
                    r_code = requests.get("http://localhost:5000/connect-code", timeout=1)
                    if r_code.status_code == 200:
                        code = r_code.json().get("code", "------")
                        self.connect_code = code
                        def update_code():
                            if self.code_display and self.code_display.winfo_exists():
                                self.code_display.configure(text=" ".join(code))
                        self.after(0, update_code)

                    # Sync Connection State
                    r_dev = requests.get("http://localhost:5000/paired-devices", headers=headers, timeout=1)
                    if r_dev.status_code == 200:
                        devices = r_dev.json()
                        new_dev = devices[0]["device_name"] if devices else None
                        if new_dev != self.connected_device:
                            self.after(0, lambda d=new_dev: self.handle_connection_change(d))

                    # Sync Stats if connected
                    if self.connected_device:
                        # Sync Transfers Indicator
                        r_trans = requests.get("http://localhost:5000/files/transfers", headers=headers, timeout=1)
                        if r_trans.status_code == 200:
                            transfers = r_trans.json()
                            active = [t for t in transfers.values() if t["status"] == "receiving"]
                            def update_indicator():
                                if self.transfer_indicator and self.transfer_indicator.winfo_exists():
                                    if active:
                                        msg = f"Receiving: {active[0]['name']}..."
                                        self.transfer_indicator.configure(text=msg, text_color=COLORS["accent"])
                                    else:
                                        self.transfer_indicator.configure(text="Idle", text_color=COLORS["secondary"])
                            self.after(0, update_indicator)

                        # Sync Resource Stats
                        r_stats = requests.get("http://localhost:5000/system-stats", headers=headers, timeout=1)
                        if r_stats.status_code == 200:
                            s = r_stats.json()
                            self.after(0, lambda: self.update_stat_displays(s))

                        # Sync Recording Status Visuals
                        r_rec = requests.get("http://localhost:5000/recording/status", headers=headers, timeout=1)
                        if r_rec.status_code == 200:
                            rec = r_rec.json()
                            self.after(0, lambda: self.update_recording_visuals(rec))

                except: pass
                time.sleep(2)
        threading.Thread(target=sync, daemon=True).start()

    def handle_connection_change(self, name):
        self.connected_device = name
        if name:
            self.status_pill.configure(text="● CONNECTED", text_color="#FFF", fg_color="#1A2E1A")
            self.device_info.configure(text=f"Linked to {name}")
        else:
            self.status_pill.configure(text="● WAITING", text_color=COLORS["secondary"], fg_color="#121212")
            self.device_info.configure(text="No device linked")

        if self.active_panel_name == "Home":
            self.switch_panel("Home")

    def update_stat_displays(self, s):
        if not self.stat_cards: return
        try:
            if "CPU Usage" in self.stat_cards: self.stat_cards["CPU Usage"].configure(text=f"{int(s['cpu_percent'])}%")
            if "RAM Usage" in self.stat_cards: self.stat_cards["RAM Usage"].configure(text=f"{int(s['ram_percent'])}%")
            if "Disk Space" in self.stat_cards: self.stat_cards["Disk Space"].configure(text=f"{int(s['disk_percent'])}%")
        except: pass

    def update_recording_visuals(self, rec):
        """Shows or hides the recording alert on the PC UI."""
        if not hasattr(self, 'recording_alert'): return

        if rec.get("is_recording"):
            if not self.recording_alert.winfo_ismapped():
                self.recording_alert.pack(anchor="w", pady=(2, 0))

            # Blinking effect
            current_color = self.recording_alert.cget("text_color")
            new_color = COLORS["danger"] if current_color != COLORS["danger"] else "#333"
            self.recording_alert.configure(text_color=new_color)
        else:
            if self.recording_alert.winfo_ismapped():
                self.recording_alert.pack_forget()

    def update_history_list(self):
        if self.active_panel_name != "Home" or self.quick_history is None: return

        def load():
            try:
                r = requests.get("http://localhost:5000/history", headers={"X-Auth-Token": INTERNAL_TOKEN}, timeout=1)
                if r.status_code == 200:
                    history = r.json()[::-1][:5]
                    def update_ui():
                        if self.quick_history is None or not self.quick_history.winfo_exists(): return
                        for widget in self.quick_history.winfo_children(): widget.destroy()
                        for item in history:
                            row = ctk.CTkFrame(self.quick_history, fg_color=COLORS["card"], corner_radius=12, height=50)
                            row.pack(fill="x", pady=4)
                            row.pack_propagate(False)
                            ctk.CTkLabel(row, text="⚡", font=("Segoe UI", 14)).pack(side="left", padx=15)
                            ctk.CTkLabel(row, text=item['endpoint'].split('/')[-1].capitalize(), font=("Segoe UI", 13, "bold")).pack(side="left")
                            ctk.CTkLabel(row, text=item['timestamp'], font=("Segoe UI", 11), text_color="#444").pack(side="right", padx=15)
                    self.after(0, update_ui)
            except: pass
        threading.Thread(target=load, daemon=True).start()

    def update_full_history(self):
        if self.active_panel_name != "Activity" or self.activity_container is None: return

        def load():
            try:
                r = requests.get("http://localhost:5000/history", headers={"X-Auth-Token": INTERNAL_TOKEN}, timeout=1)
                if r.status_code == 200:
                    history = r.json()[::-1]
                    def update_ui():
                        if self.activity_container is None or not self.activity_container.winfo_exists(): return
                        for widget in self.activity_container.winfo_children(): widget.destroy()
                        for item in history:
                            row = ctk.CTkFrame(self.activity_container, fg_color=COLORS["card"], corner_radius=15, height=65)
                            row.pack(fill="x", pady=5)
                            row.pack_propagate(False)
                            icon = "📁" if "file" in item['endpoint'] else "🎮"
                            ctk.CTkLabel(row, text=icon, font=("Segoe UI", 18)).pack(side="left", padx=20)
                            info = ctk.CTkFrame(row, fg_color="transparent")
                            info.pack(side="left", pady=10)
                            ctk.CTkLabel(info, text=item['endpoint'].split('/')[-1].upper(), font=("Segoe UI", 13, "bold")).pack(anchor="w")
                            ctk.CTkLabel(info, text=item['timestamp'], font=("Segoe UI", 11), text_color=COLORS["secondary"]).pack(anchor="w")
                            status = "DONE" if item['success'] else "FAILED"
                            color = COLORS["success"] if item['success'] else COLORS["danger"]
                            # [FIX] Use standard hex colors. Tkinter doesn't support #RRGGBBAA alpha hex
                            status_bg = "#1A2E1A" if item['success'] else "#2E1A1A"
                            ctk.CTkLabel(row, text=status, font=("Segoe UI", 10, "bold"),
                                         text_color=color, fg_color=status_bg,
                                         corner_radius=8, width=70, height=24).pack(side="right", padx=20)
                    self.after(0, update_ui)
            except: pass
        threading.Thread(target=load, daemon=True).start()
