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

# PRO DESIGN SYSTEM
COLORS = {
    "bg": "#0D0D0D",
    "sidebar": "#121212",
    "card": "#1A1A1A",
    "accent": "#6C63FF",
    "hover": "#222222",
    "secondary": "#86868B",
    "white": "#FFFFFF",
    "success": "#4CAF50",
    "danger": "#FF5252"
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
            {"name": "Shared Files", "icon": "📁"},
            {"name": "Security", "icon": "🛡️"},
            {"name": "Activity", "icon": "📜"},
            {"name": "Settings", "icon": "⚙️"},
        ]

        self.setup_layout()
        self.start_data_sync()
        self.process_ui_queue()

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

        ctk.CTkLabel(toast, text=f"📱 {device}: {title}", font=("Helvetica Neue", 13, "bold"), text_color="#FFF").pack(padx=20, pady=15)

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

        # Brand Header (Dynamic)
        brand = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        brand.pack(pady=40, padx=20, fill="x")
        
        meta = get_metadata()
        app_name = meta.get("app_name", "CYPHER")

        # Dynamic Logo Rendering
        for i, char in enumerate(app_name):
            color = COLORS["accent"] if i == 1 else "#FFF"
            ctk.CTkLabel(brand, text=char, font=("Helvetica Neue", 28, "bold"), text_color=color).pack(side="left")

        # Connection Status Pill
        self.status_pill = ctk.CTkLabel(self.sidebar, text="● WAITING",
                                        font=("Helvetica Neue", 11, "bold"),
                                        text_color=COLORS["secondary"],
                                        fg_color="#121212",
                                        corner_radius=12,
                                        height=28)
        self.status_pill.pack(pady=(0, 40), padx=30, fill="x")

        # Navigation
        self.nav_btns = {}
        for item in self.nav_items:
            btn = ctk.CTkButton(self.sidebar,
                                text=f"  {item['icon']}  {item['name']}",
                                font=("Helvetica Neue", 14),
                                anchor="w",
                                height=48,
                                corner_radius=12,
                                fg_color="transparent",
                                text_color=COLORS["secondary"],
                                hover_color=COLORS["hover"],
                                command=lambda n=item['name']: self.switch_panel(n))
            btn.pack(fill="x", padx=15, pady=4)
            self.nav_btns[item['name']] = btn

        # Sidebar Footer
        footer = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        footer.pack(side="bottom", fill="x", pady=20, padx=20)

        meta = get_metadata()
        version_text = f"v{meta.get('app_version', '1.0.0')}"
        ctk.CTkLabel(footer, text=version_text, font=("Helvetica Neue", 10), text_color="#333").pack(anchor="w")

        self.device_info = ctk.CTkLabel(footer, text="No device linked",
                                        font=("Helvetica Neue", 11),
                                        text_color="#444")
        self.device_info.pack(anchor="w")

        self.cancel_btn = ctk.CTkButton(footer, text="⛔ Stop Transfers",
                                        font=("Helvetica Neue", 11, "bold"),
                                        fg_color="#1A1A1A",
                                        text_color=COLORS["danger"],
                                        height=28,
                                        corner_radius=8,
                                        command=self.cancel_transfers)
        self.cancel_btn.pack(anchor="w", pady=(10, 0), fill="x")

        credit = ctk.CTkLabel(footer, text="Designed by Emerald",
                              font=("Helvetica Neue", 11, "bold"),
                              text_color=COLORS["accent"], cursor="hand2")
        credit.pack(anchor="w", pady=(5, 0))
        credit.bind("<Button-1>", lambda e: webbrowser.open("https://tiktok.com/@emerald_dev1"))

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
        elif name == "Shared Files": self.render_files()
        elif name == "Security": self.render_security()
        elif name == "Activity": self.render_activity()
        elif name == "Settings": self.render_settings()

    # --- PANEL RENDERING ---

    def render_home(self):
        header = ctk.CTkLabel(self.main_content, text="Dashboard", font=("Helvetica Neue", 32, "bold"), text_color="#FFF")
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
        ctk.CTkLabel(self.radar_circle, text="📡", font=("Helvetica Neue", 40)).place(relx=0.5, rely=0.5, anchor="center")
        self.animate_radar()

        ctk.CTkLabel(container, text="Ready to Link", font=("Helvetica Neue", 24, "bold")).pack()
        ctk.CTkLabel(container, text="Open CYPHER on your phone to begin", font=("Helvetica Neue", 14), text_color=COLORS["secondary"]).pack(pady=5)

        # Large Connect Code Card
        code_card = ctk.CTkFrame(container, fg_color=COLORS["card"], corner_radius=24)
        code_card.pack(pady=50, padx=100, fill="x")

        ctk.CTkLabel(code_card, text="YOUR CONNECT CODE", font=("Helvetica Neue", 11, "bold"), text_color=COLORS["secondary"]).pack(pady=(40, 10))

        self.code_display = ctk.CTkLabel(code_card, text=" ".join(self.connect_code), font=("Courier New", 64, "bold"), text_color=COLORS["accent"])
        self.code_display.pack(pady=(0, 40))

        ip_row = ctk.CTkFrame(code_card, fg_color="transparent")
        ip_row.pack(pady=(0, 40))
        ctk.CTkLabel(ip_row, text=f"PC Address: {self.local_ip}", font=("Helvetica Neue", 13), text_color="#555").pack(side="left", padx=20)

    def render_connected_state(self):
        container = ctk.CTkFrame(self.main_content, fg_color="transparent")
        container.pack(fill="both", expand=True)

        # Hero Banner
        banner = ctk.CTkFrame(container, fg_color="#121A12", corner_radius=20, height=120)
        banner.pack(fill="x", pady=(0, 30))
        banner.pack_propagate(False)

        txt_col = ctk.CTkFrame(banner, fg_color="transparent")
        txt_col.pack(side="left", padx=30, pady=25)
        ctk.CTkLabel(txt_col, text=f"Linked to {self.connected_device}", font=("Helvetica Neue", 22, "bold"), text_color=COLORS["success"]).pack(anchor="w")
        ctk.CTkLabel(txt_col, text="Everything is synchronized and secure.", font=("Helvetica Neue", 13), text_color="#4B664B").pack(anchor="w")

        # Stats Row
        stats_row = ctk.CTkFrame(container, fg_color="transparent")
        stats_row.pack(fill="x", pady=10)

        self.stat_cards = {}
        for label in ["CPU Usage", "RAM Usage", "Disk Space"]:
            card = ctk.CTkFrame(stats_row, fg_color=COLORS["card"], corner_radius=20, height=140)
            card.pack(side="left", fill="x", expand=True, padx=10)
            card.pack_propagate(False)
            ctk.CTkLabel(card, text=label.upper(), font=("Helvetica Neue", 10, "bold"), text_color=COLORS["secondary"]).pack(pady=(25, 0))
            val = ctk.CTkLabel(card, text="0%", font=("Helvetica Neue", 32, "bold"), text_color="#FFF")
            val.pack()
            self.stat_cards[label] = val

        # Recent Quick Activity
        ctk.CTkLabel(container, text="Recent Stream", font=("Helvetica Neue", 18, "bold")).pack(anchor="w", pady=(40, 15))
        self.quick_history = ctk.CTkFrame(container, fg_color="transparent")
        self.quick_history.pack(fill="both", expand=True)
        self.update_history_list()

    def render_files(self):
        header = ctk.CTkLabel(self.main_content, text="Shared Folders", font=("Helvetica Neue", 32, "bold"), text_color="#FFF")
        header.pack(anchor="w", pady=(0, 10))
        ctk.CTkLabel(self.main_content, text="Manage which parts of your PC the phone can see.", font=("Helvetica Neue", 14), text_color=COLORS["secondary"]).pack(anchor="w", pady=(0, 30))

        scroll = ctk.CTkScrollableFrame(self.main_content, fg_color="transparent")
        scroll.pack(fill="both", expand=True)

        loading_lbl = ctk.CTkLabel(scroll, text="Loading file system...", text_color=COLORS["secondary"])
        loading_lbl.pack(pady=40)

        def load():
            try:
                r = requests.get("http://localhost:5000/files", headers={"X-Auth-Token": INTERNAL_TOKEN}, timeout=2)
                if r.status_code == 200:
                    folders = r.json()
                    def update_ui():
                        loading_lbl.destroy()
                        if not folders:
                            ctk.CTkLabel(scroll, text="No shared folders found.", text_color=COLORS["secondary"]).pack(pady=40)
                            return
                        for f in folders:
                            card = ctk.CTkFrame(scroll, fg_color=COLORS["card"], corner_radius=16, height=70)
                            card.pack(fill="x", pady=6)
                            card.pack_propagate(False)
                            ctk.CTkLabel(card, text="📁", font=("Helvetica Neue", 20)).pack(side="left", padx=20)
                            ctk.CTkLabel(card, text=f['name'], font=("Helvetica Neue", 15, "bold")).pack(side="left")
                            ctk.CTkLabel(card, text=f['path'], font=("Helvetica Neue", 12), text_color="#444").pack(side="left", padx=20)
                            ctk.CTkButton(card, text="Remove", width=80, height=32, corner_radius=10, fg_color="#222", hover_color=COLORS["danger"]).pack(side="right", padx=20)
                    self.after(0, update_ui)
                else:
                    self.after(0, lambda: loading_lbl.configure(text="Failed to load file system.", text_color=COLORS["danger"]))
            except:
                self.after(0, lambda: loading_lbl.configure(text="Unable to load file system engine.", text_color=COLORS["danger"]))

        threading.Thread(target=load, daemon=True).start()

    def render_security(self):
        header = ctk.CTkLabel(self.main_content, text="Security & Guest Access", font=("Helvetica Neue", 32, "bold"), text_color="#FFF")
        header.pack(anchor="w", pady=(0, 30))

        # QR Section
        card = ctk.CTkFrame(self.main_content, fg_color=COLORS["card"], corner_radius=24)
        card.pack(fill="x")

        inner = ctk.CTkFrame(card, fg_color="transparent")
        inner.pack(fill="both", padx=40, pady=40)

        left_col = ctk.CTkFrame(inner, fg_color="transparent")
        left_col.pack(side="left", fill="both", expand=True)

        ctk.CTkLabel(left_col, text="GUEST PASS", font=("Helvetica Neue", 11, "bold"), text_color=COLORS["accent"]).pack(anchor="w")
        ctk.CTkLabel(left_col, text="Temporary Link", font=("Helvetica Neue", 24, "bold")).pack(anchor="w", pady=(10, 20))
        ctk.CTkLabel(left_col, text="Scan this code with a visitor's phone to give them 15 minutes of access to your shared files.",
                     font=("Helvetica Neue", 15), text_color=COLORS["secondary"], wraplength=340, justify="left").pack(anchor="w")

        ctk.CTkLabel(left_col, text="NOTE: If your phone isn't connecting, please re-scan the QR code to pair with this session.",
                     font=("Helvetica Neue", 12, "italic"), text_color=COLORS["danger"], wraplength=340, justify="left").pack(anchor="w", pady=(20, 0))

        # QR Generation
        self.qr_label = ctk.CTkLabel(inner, text="Generating QR...", corner_radius=16)
        self.qr_label.pack(side="right", padx=(20, 0))
        self.generate_qr()

    def generate_qr(self):
        try:
            qr_data = f"cypher://{self.local_ip}:5000/{self.connect_code}"
            qr = qrcode.QRCode(version=1, box_size=10, border=4)
            qr.add_data(qr_data)
            qr.make(fit=True)

            # Use standard colors and ensure conversion to RGB for CTk compatibility
            img = qr.make_image(fill_color="white", back_color="#1A1A1A").convert("RGB")

            # Use thumbnail for smoother scaling on high-DPI
            img.thumbnail((400, 400), Image.Resampling.LANCZOS)

            self.qr_img_ref = ctk.CTkImage(light_image=img, dark_image=img, size=(200, 200))
            if self.qr_label and self.qr_label.winfo_exists():
                self.qr_label.configure(image=self.qr_img_ref, text="")
        except Exception as e:
            if self.qr_label and self.qr_label.winfo_exists():
                self.qr_label.configure(text="QR Error")
            print(f"QR Generation Error: {e}")

    def render_transfers(self):
        ctk.CTkLabel(self.main_content, text="Active Transfers", font=("Helvetica Neue", 32, "bold"), text_color="#FFF").pack(anchor="w", pady=(0, 10))
        ctk.CTkLabel(self.main_content, text="Real-time monitoring of incoming and outgoing files.", font=("Helvetica Neue", 14), text_color=COLORS["secondary"]).pack(anchor="w", pady=(0, 30))

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
                            ctk.CTkLabel(self.transfers_container, text="No active or recent transfers.", font=("Helvetica Neue", 14), text_color="#444").pack(pady=100)
                        else:
                            for tid, t in sorted(transfers.items(), key=lambda x: x[1].get('start_time', 0), reverse=True):
                                card = ctk.CTkFrame(self.transfers_container, fg_color=COLORS["card"], corner_radius=16)
                                card.pack(fill="x", pady=6)

                                # Inner Padding
                                c = ctk.CTkFrame(card, fg_color="transparent")
                                c.pack(fill="x", padx=25, pady=25)

                                header = ctk.CTkFrame(c, fg_color="transparent")
                                header.pack(fill="x")
                                ctk.CTkLabel(header, text=t['name'], font=("Helvetica Neue", 15, "bold")).pack(side="left")
                                status_text = t['status'].upper()
                                if t['status'] == "receiving":
                                    status_text = f"RECEIVING • {t.get('speed', '0 KB/s')}"
                                ctk.CTkLabel(header, text=status_text, font=("Helvetica Neue", 11, "bold"), text_color=COLORS["accent"]).pack(side="right")
                                prog = t.get('progress', 0) / 100.0
                                bar = ctk.CTkProgressBar(c, progress_color=COLORS["accent"], height=8)
                                bar.set(prog)
                                bar.pack(fill="x", pady=(15, 5))
                                ctk.CTkLabel(c, text=f"{t.get('progress', 0)}% Completed", font=("Helvetica Neue", 10), text_color=COLORS["secondary"]).pack(anchor="e")
                    self.after(0, update_ui)
            except: pass
            self.after(2000, self.update_transfers_list)

        threading.Thread(target=load, daemon=True).start()

    def render_activity(self):
        header_row = ctk.CTkFrame(self.main_content, fg_color="transparent")
        header_row.pack(fill="x", pady=(0, 20))

        ctk.CTkLabel(header_row, text="Activity & Transfers", font=("Helvetica Neue", 32, "bold"), text_color="#FFF").pack(side="left")

        self.transfer_indicator = ctk.CTkLabel(header_row, text="No active transfers", font=("Helvetica Neue", 12), text_color=COLORS["secondary"])
        self.transfer_indicator.pack(side="right", padx=20)

        self.activity_container = ctk.CTkScrollableFrame(self.main_content, fg_color="transparent")
        self.activity_container.pack(fill="both", expand=True)
        self.update_full_history()

    def render_settings(self):
        ctk.CTkLabel(self.main_content, text="Settings", font=("Helvetica Neue", 32, "bold"), text_color="#FFF").pack(anchor="w", pady=(0, 30))

        card = ctk.CTkFrame(self.main_content, fg_color=COLORS["card"], corner_radius=24)
        card.pack(fill="x")

        # Inner padding for settings
        inner = ctk.CTkFrame(card, fg_color="transparent")
        inner.pack(fill="x", padx=30, pady=30)

        # Options
        self.create_setting_row(inner, "Device Visibility", "Broadcast your PC name to the network", True)
        self.create_setting_row(inner, "Auto-Clipboard", "Sync clipboard without confirmation", False)
        self.create_setting_row(inner, "Launch on Startup", "Start CYPHER when Windows boots", True)

        ctk.CTkButton(self.main_content, text="Save All Changes", fg_color=COLORS["accent"], height=50, corner_radius=25, font=("Helvetica Neue", 15, "bold")).pack(pady=40, fill="x")

    def create_setting_row(self, parent, title, desc, default):
        row = ctk.CTkFrame(parent, fg_color="transparent", height=70)
        row.pack(fill="x", pady=5)
        row.pack_propagate(False)

        info = ctk.CTkFrame(row, fg_color="transparent")
        info.pack(side="left")
        ctk.CTkLabel(info, text=title, font=("Helvetica Neue", 15, "bold")).pack(anchor="w")
        ctk.CTkLabel(info, text=desc, font=("Helvetica Neue", 12), text_color=COLORS["secondary"]).pack(anchor="w")

        sw = ctk.CTkSwitch(row, text="", progress_color=COLORS["accent"])
        if default: sw.select()
        sw.pack(side="right")

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
                            ctk.CTkLabel(row, text="⚡", font=("Helvetica Neue", 14)).pack(side="left", padx=15)
                            ctk.CTkLabel(row, text=item['endpoint'].split('/')[-1].capitalize(), font=("Helvetica Neue", 13, "bold")).pack(side="left")
                            ctk.CTkLabel(row, text=item['timestamp'], font=("Helvetica Neue", 11), text_color="#444").pack(side="right", padx=15)
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
                            ctk.CTkLabel(row, text=icon, font=("Helvetica Neue", 18)).pack(side="left", padx=20)
                            info = ctk.CTkFrame(row, fg_color="transparent")
                            info.pack(side="left", pady=10)
                            ctk.CTkLabel(info, text=item['endpoint'].split('/')[-1].upper(), font=("Helvetica Neue", 13, "bold")).pack(anchor="w")
                            ctk.CTkLabel(info, text=item['timestamp'], font=("Helvetica Neue", 11), text_color=COLORS["secondary"]).pack(anchor="w")
                            status = "DONE" if item['success'] else "FAILED"
                            color = COLORS["success"] if item['success'] else COLORS["danger"]
                            ctk.CTkLabel(row, text=status, font=("Helvetica Neue", 10, "bold"), text_color=color, fg_color=color+"11", corner_radius=8, width=70, height=24).pack(side="right", padx=20)
                    self.after(0, update_ui)
            except: pass
        threading.Thread(target=load, daemon=True).start()
